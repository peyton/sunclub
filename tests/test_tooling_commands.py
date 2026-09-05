"""Exercise the public shell entrypoints without Xcode or GUI services."""

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture
def tooling(tmp_path):
    repo = tmp_path / "repo"
    shutil.copytree(ROOT / "scripts/tooling", repo / "scripts/tooling")
    (repo / "app").mkdir()
    binary = tmp_path / "bin"
    binary.mkdir()
    log = tmp_path / "commands"
    mise = binary / "mise"
    mise.write_text("""#!/usr/bin/env bash
set -eu
printf '%s\\n' "$*" >> "$MOCK_LOG"
case "$*" in
  *scripts.tooling.resolve_versions*|*scripts.tooling.workspace_fingerprint*)
    if [ "${MOCK_REAL_VERSION_INPUTS:-0}" = 1 ]; then
      shift 5
      exec "$TEST_PYTHON" "$@"
    fi
    if [[ "$*" = *scripts.tooling.workspace_fingerprint* ]]; then
      printf '%s\\n' "$MOCK_FINGERPRINT"
    fi ;;
  *scripts.resolve_simulator*) printf 'SIMULATOR\\n' ;;
  *"tuist generate"*)
    mkdir -p Sunclub.xcworkspace Sunclub/Sunclub.xcodeproj/xcshareddata/xcschemes
    touch Sunclub/Sunclub.xcodeproj/xcshareddata/xcschemes/SunclubDev.xcscheme
    touch Sunclub/Sunclub.xcodeproj/xcshareddata/xcschemes/Sunclub.xcscheme ;;
  *"tuist xcodebuild"*) exit "${MOCK_XCODE_EXIT:-0}" ;;
esac
""")
    mise.chmod(0o755)
    xcrun = binary / "xcrun"
    xcrun.write_text("#!/bin/sh\nexit 0\n")
    xcrun.chmod(0o755)
    environment = {
        **os.environ,
        "PATH": f"{binary}:{os.environ['PATH']}",
        "MOCK_LOG": str(log),
        "MOCK_FINGERPRINT": "a" * 64,
        "SUNCLUB_SKIP_VERSION_RESOLUTION": "1",
        "DEVELOPER_DIR": "/mock/Xcode",
        "TEST_XCODEBUILD_MAX_ATTEMPTS": "1",
        "SUNCLUB_TUIST_SHARE": "0",
        "TEST_PYTHON": sys.executable,
    }
    for name in ("APP_SCHEME", "SUNCLUB_FLAVOR", "SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE"):
        environment.pop(name, None)

    def run(script, *args, **env):
        return subprocess.run(
            ["bash", str(repo / "scripts/tooling" / script), *args],
            cwd=repo,
            env={**environment, **env},
            capture_output=True,
            text=True,
            check=False,
        )

    return run, log


def test_build_reuses_real_resolved_versions_and_fingerprint(tooling):
    run, log = tooling
    environment = {
        "MOCK_REAL_VERSION_INPUTS": "1",
        "SUNCLUB_SKIP_VERSION_RESOLUTION": "0",
        "SUNCLUB_MARKETING_VERSION": "1.2.3",
        "SUNCLUB_BUILD_NUMBER": "",
        "SUNCLUB_RELEASE_TAG": "",
        "GITHUB_REF_TYPE": "branch",
        "GITHUB_REF": "refs/heads/local",
    }
    first = run("build.sh", **environment)
    assert first.returncode == 0, first.stderr
    time.sleep(1.1)  # Cross the old timestamp resolver's one-second boundary.
    second = run("build.sh", **environment)
    assert second.returncode == 0, second.stderr
    assert log.read_text().count("tuist generate") == 1
    environment["SUNCLUB_BUILD_NUMBER"] = "20260904.2.0"
    assert run("build.sh", **environment).returncode == 0
    assert log.read_text().count("tuist generate") == 2
    environment["SUNCLUB_MARKETING_VERSION"] = "1.2.4"
    assert run("build.sh", **environment).returncode == 0
    assert log.read_text().count("tuist generate") == 3


def test_build_reuses_generation_and_invalidates_changed_inputs(tooling):
    run, log = tooling
    assert run("build.sh").returncode == 0
    assert run("build.sh").returncode == 0
    calls = log.read_text()
    assert calls.count("tuist generate") == 1
    assert (
        "-scheme SunclubDev -configuration Debug -destination generic/platform=iOS Simulator"
        in calls
    )
    assert "tuist setup" not in calls
    assert run("build.sh", MOCK_FINGERPRINT="b" * 64).returncode == 0
    assert log.read_text().count("tuist generate") == 2


@pytest.mark.parametrize(
    "environment,disabled",
    [
        ({"GITHUB_ACTIONS": ""}, True),
        ({"GITHUB_ACTIONS": "true"}, False),
        (
            {"GITHUB_ACTIONS": "", "SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE": "0"},
            False,
        ),
        (
            {"GITHUB_ACTIONS": "true", "SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE": "1"},
            True,
        ),
    ],
)
def test_compile_cache_requires_local_opt_in_and_defaults_on_in_github(
    tooling, environment, disabled
):
    run, log = tooling
    result = run("build.sh", **environment)
    assert result.returncode == 0, result.stderr
    calls = log.read_text()
    for setting in ("CACHING", "PLUGIN", "DIAGNOSTIC_REMARKS"):
        assert (f"COMPILATION_CACHE_ENABLE_{setting}=NO" in calls) is disabled
    assert "tuist setup" not in calls


@pytest.mark.parametrize(
    "suite,selector",
    [
        ("unit", "SunclubTests"),
        ("ui", "SunclubUITests"),
        ("ui-smoke", "SunclubUITests/SunclubSmokeUITests"),
    ],
)
def test_suite_selects_all_and_only_its_tests(tooling, suite, selector):
    run, log = tooling
    assert run("test_ios.sh", "--suite", suite).returncode == 0
    assert f"-only-testing:{selector} " in log.read_text()


def test_filtered_unit_tests_and_failures(tooling):
    run, log = tooling
    result = run(
        "test_ios.sh",
        "--suite",
        "unit",
        "--filter",
        "ExampleTests/testSave",
        MOCK_XCODE_EXIT="65",
    )
    assert result.returncode == 65
    assert "-only-testing:SunclubTests/ExampleTests/testSave" in log.read_text()
    assert log.read_text().count("tuist xcodebuild") == 1


def test_ci_build_selects_production_device_release_without_cache_setup(tooling):
    run, log = tooling
    assert run("ci_build.sh", "prod", APP_SCHEME="SunclubDev").returncode == 0
    assert (
        "-scheme Sunclub -configuration Release -destination generic/platform=iOS "
        in log.read_text()
    )
    assert "tuist setup" not in log.read_text()
    assert run("ci_build.sh", "invalid").returncode == 2


def test_bootstrap_only_installs_locked_dependencies(tooling):
    run, log = tooling
    assert run("bootstrap.sh", SUNCLUB_SKIP_VERSION_RESOLUTION="0").returncode == 0
    assert log.read_text().splitlines() == [
        "install --locked",
        "exec -- uv sync --group dev",
    ]
