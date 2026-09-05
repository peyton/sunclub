"""Release proof must precede archive signing and export, including local use."""

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture
def archive(tmp_path):
    repo = tmp_path / "repo"
    for directory in ("scripts/tooling", "scripts/appstore"):
        shutil.copytree(ROOT / directory, repo / directory)
    (repo / "app/Sunclub").mkdir(parents=True)
    for entitlements in (ROOT / "app/Sunclub").glob("*.entitlements"):
        shutil.copy(entitlements, repo / "app/Sunclub")
    shutil.copy(ROOT / ".gitignore", repo / ".gitignore")
    source = repo / "app/Sunclub/Sources/Feature.swift"
    source.parent.mkdir()
    source.write_text("struct Feature {}\n")
    for args in (
        ["init", "--quiet", "--template="],
        ["add", "--all"],
        [
            "-c",
            "user.name=Archive Test",
            "-c",
            "user.email=archive@example.test",
            "-c",
            "commit.gpgsign=false",
            "-c",
            "core.hooksPath=/dev/null",
            "commit",
            "--quiet",
            "-m",
            "Fixture source",
        ],
    ):
        subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True)
    sha = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=repo, text=True
    ).strip()
    binary = tmp_path / "bin"
    binary.mkdir()
    log = tmp_path / "commands"
    log.touch()
    commands = {
        "mise": """case "$*" in
  'exec -- uv run python -m scripts.appstore.validate_metadata'*) exit 0 ;;
  'exec -- uv run python '* ) shift 5; exec "$TEST_PYTHON" "$@" ;;
  'exec -- tuist xcodebuild '* )
    mkdir -p "$ARCHIVE_PATH/Products/Applications/Sunclub.app" ;;
  *) exit 98 ;;
esac
""",
        "gh": """if [ "${TEST_FULL_CI:-0}" != 1 ]; then
  printf '[{"workflow_runs":[]}]\\n'
elif [[ "$*" = *'/jobs?'* ]]; then
  printf '[{"jobs":[{"name":"CI","conclusion":"success"},{"name":"iOS UI Tests","conclusion":"success","steps":[{"name":"Run full UI tests","conclusion":"success"}]}]}]\\n'
else
  printf '[{"workflow_runs":[{"id":123,"head_sha":"%s","conclusion":"success","event":"workflow_dispatch","html_url":"https://example.test/123"}]}]\\n' "$TEST_SOURCE_SHA"
fi
""",
        "codesign": "exit 99\n",
        "xcodebuild": "exit 99\n",
        "xcrun": "exit 99\n",
    }
    for name, body in commands.items():
        path = binary / name
        path.write_text(
            '#!/usr/bin/env bash\nset -eu\nprintf "%s %s\\n" "$(basename "$0")" "$*" >> "$MOCK_LOG"\n'
            + body
        )
        path.chmod(0o755)
    environment = {
        "PATH": f"{binary}:{os.environ['PATH']}",
        "MOCK_LOG": str(log),
        "TEST_PYTHON": sys.executable,
        "TEST_SOURCE_SHA": sha,
        "DEVELOPER_DIR": "/mock/Xcode",
        "GITHUB_REPOSITORY": "example/sunclub",
        "SUNCLUB_MARKETING_VERSION": "1.2.3",
        "ARCHIVE_PATH": str(repo / ".build/Sunclub.xcarchive"),
    }

    def run(*args, **env):
        result = subprocess.run(
            [
                "/bin/bash",
                str(repo / "scripts/appstore/archive-and-upload.sh"),
                "--skip-generate",
                *args,
            ],
            cwd=repo,
            env={**environment, **env},
            capture_output=True,
            text=True,
            check=False,
        )
        return result, log.read_text()

    return run, repo, sha


@pytest.mark.parametrize(
    "args",
    [
        (),
        ("--skip-export",),
        ("--unsigned-archive",),
        ("--skip-archive",),
        ("--unsigned-archive", "--upload-testflight"),
    ],
)
def test_signing_or_export_requires_exact_source_ci_before_any_build(archive, args):
    run, _, sha = archive
    result, calls = run(*args)
    assert result.returncode != 0
    assert f"no successful full CI for {sha}" in result.stderr
    assert f"head_sha={sha}" in calls
    assert "tuist xcodebuild" not in calls
    assert "codesign " not in calls
    assert "xcodebuild -exportArchive" not in calls


def test_unsigned_archive_without_export_never_signs_or_requires_ci(archive):
    run, _, _ = archive
    result, calls = run("--unsigned-archive", "--skip-export")
    assert result.returncode == 0, result.stderr
    assert "tuist xcodebuild " in calls
    assert " archive -workspace " in calls
    assert "CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO" in calls
    assert "ci_policy require-release" not in calls
    assert "codesign " not in calls
    assert "xcodebuild -exportArchive" not in calls
    assert re.search(r"CFBundleVersion=\d{8}\.\d{6}\.0", result.stdout)


@pytest.mark.parametrize("args", [(), ("--unsigned-archive",)])
def test_full_ci_allows_signing_only_after_source_proof(archive, args):
    run, _, sha = archive
    result, calls = run(*args, TEST_FULL_CI="1")
    assert f"Full CI verified for {sha}" in result.stdout
    # Stop at the first external signing/export command; no real Xcode runs.
    assert result.returncode == 99
    proof = calls.index("ci_policy require-release")
    assert proof < calls.index("tuist xcodebuild ")
    if args:
        assert proof < calls.index("codesign --force --sign -")
    else:
        assert proof < calls.index("xcodebuild -exportArchive")


def test_unsigned_no_export_cannot_be_used_to_upload_without_ci(archive):
    run, _, _ = archive
    result, calls = run("--unsigned-archive", "--skip-export", "--upload-testflight")
    assert result.returncode != 0
    assert "--upload-testflight requires IPA export" in result.stderr
    assert "tuist xcodebuild" not in calls
    assert "codesign " not in calls
    assert "xcrun " not in calls


@pytest.mark.parametrize("change", ["tracked", "staged", "untracked"])
@pytest.mark.parametrize("args", [(), ("--unsigned-archive",)])
def test_dirty_release_source_cannot_sign_despite_successful_head_ci(
    archive, change, args
):
    run, repo, _ = archive
    source = repo / "app/Sunclub/Sources/Feature.swift"
    if change == "untracked":
        source = source.with_name("Added.swift")
    source.write_text("struct ChangedFeature {}\n")
    if change == "staged":
        subprocess.run(["git", "add", str(source)], cwd=repo, check=True)
    result, calls = run(*args, TEST_FULL_CI="1")
    assert result.returncode != 0
    assert "release source has uncommitted changes" in result.stderr
    assert "gh api" not in calls
    assert "tuist xcodebuild" not in calls
    assert "codesign " not in calls
    assert "xcodebuild -exportArchive" not in calls


def test_ignored_outputs_do_not_block_clean_release_source(archive):
    run, repo, sha = archive
    for name in (
        ".build/Sunclub.xcarchive/Products/generated",
        ".cache/tuist/state",
        "app/Sunclub.xcworkspace/contents.xcworkspacedata",
    ):
        output = repo / name
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text("generated")
    result, calls = run(TEST_FULL_CI="1")
    assert f"Full CI verified for {sha}" in result.stdout
    assert result.returncode == 99  # Reached the external export test double.
    assert "xcodebuild -exportArchive" in calls


def test_dirty_source_still_allows_unsigned_preparation(archive):
    run, repo, _ = archive
    (repo / "app/Sunclub/Sources/Added.swift").write_text("struct Added {}\n")
    result, calls = run("--unsigned-archive", "--skip-export")
    assert result.returncode == 0, result.stderr
    assert "tuist xcodebuild " in calls
    assert "ci_policy require-release" not in calls
    assert "codesign " not in calls


def test_unreadable_git_source_state_fails_closed(archive):
    run, repo, _ = archive
    (repo / ".git").rename(repo.parent / "detached-git")
    result, calls = run(TEST_FULL_CI="1")
    assert result.returncode != 0
    assert "could not verify a clean release source tree" in result.stderr
    assert "gh api" not in calls
    assert "tuist xcodebuild" not in calls
    assert "codesign " not in calls
