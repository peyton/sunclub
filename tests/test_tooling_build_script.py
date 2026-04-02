from __future__ import annotations

import os
import shlex
import shutil
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


def _write_executable(path: Path, contents: str) -> None:
    path.write_text(contents)
    path.chmod(0o755)


def _copy_tooling_script(repo_root: Path, name: str) -> None:
    tooling_dir = repo_root / "scripts" / "tooling"
    tooling_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(REPO_ROOT / "scripts" / "tooling" / name, tooling_dir / name)


def test_build_script_forwards_derived_data_path_to_tuist_share(
    tmp_path: Path,
) -> None:
    repo_root = tmp_path / "repo"
    (repo_root / "app").mkdir(parents=True)

    for script_name in ("build.sh", "common.sh", "sunclub.env"):
        _copy_tooling_script(repo_root, script_name)

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()

    xcodebuild_log = tmp_path / "xcodebuild.log"
    mise_log = tmp_path / "mise.log"

    _write_executable(
        bin_dir / "xcodebuild",
        f"""#!/bin/sh
printf '%s\n' "$@" > {shlex.quote(str(xcodebuild_log))}
""",
    )
    _write_executable(
        bin_dir / "mise",
        f"""#!/bin/sh
printf '%s\n' "$@" > {shlex.quote(str(mise_log))}
""",
    )

    derived_data_path = tmp_path / "DerivedData" / "ci-build"
    result_bundle_path = tmp_path / "build.xcresult"

    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["SUNCLUB_SKIP_VERSION_RESOLUTION"] = "1"

    subprocess.run(
        [
            "bash",
            str(repo_root / "scripts" / "tooling" / "build.sh"),
            "--skip-generate",
            "--derived-data-path",
            str(derived_data_path),
            "--result-bundle-path",
            str(result_bundle_path),
        ],
        check=True,
        cwd=repo_root,
        env=env,
    )

    xcodebuild_args = xcodebuild_log.read_text().splitlines()
    mise_args = mise_log.read_text().splitlines()

    build_derived_data = xcodebuild_args[xcodebuild_args.index("-derivedDataPath") + 1]
    shared_derived_data = mise_args[mise_args.index("--derived-data-path") + 1]
    shared_configuration = mise_args[mise_args.index("--configuration") + 1]

    assert mise_args[:4] == ["exec", "--", "tuist", "share"]
    assert mise_args[4] == "SunclubDev"
    assert build_derived_data == str(derived_data_path)
    assert shared_derived_data == build_derived_data
    assert shared_configuration == "Release"


def test_build_script_disables_swift_compile_cache_under_act(tmp_path: Path) -> None:
    repo_root = tmp_path / "repo"
    (repo_root / "app").mkdir(parents=True)

    for script_name in ("build.sh", "common.sh", "sunclub.env"):
        _copy_tooling_script(repo_root, script_name)

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()

    xcodebuild_log = tmp_path / "xcodebuild.log"
    mise_log = tmp_path / "mise.log"

    _write_executable(
        bin_dir / "xcodebuild",
        f"""#!/bin/sh
printf '%s\n' "$@" > {shlex.quote(str(xcodebuild_log))}
""",
    )
    _write_executable(
        bin_dir / "mise",
        f"""#!/bin/sh
printf '%s\n' "$@" > {shlex.quote(str(mise_log))}
""",
    )

    env = os.environ.copy()
    env["ACT"] = "true"
    env["SUNCLUB_TUIST_SHARE"] = "0"
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["SUNCLUB_SKIP_VERSION_RESOLUTION"] = "1"

    subprocess.run(
        [
            "bash",
            str(repo_root / "scripts" / "tooling" / "build.sh"),
            "--skip-generate",
        ],
        check=True,
        cwd=repo_root,
        env=env,
    )

    xcodebuild_args = xcodebuild_log.read_text().splitlines()
    assert "SWIFT_ENABLE_COMPILE_CACHE=NO" in xcodebuild_args
    assert "COMPILATION_CACHE_ENABLE_CACHING=NO" in xcodebuild_args
    assert "COMPILATION_CACHE_ENABLE_PLUGIN=NO" in xcodebuild_args
    assert "COMPILATION_CACHE_REMOTE_SERVICE_PATH=" in xcodebuild_args
    assert not mise_log.exists()


def test_build_script_disables_swift_compile_cache_on_beta_xcode(tmp_path: Path) -> None:
    repo_root = tmp_path / "repo"
    (repo_root / "app").mkdir(parents=True)

    for script_name in ("build.sh", "common.sh", "sunclub.env"):
        _copy_tooling_script(repo_root, script_name)

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()

    xcodebuild_log = tmp_path / "xcodebuild.log"
    mise_log = tmp_path / "mise.log"

    _write_executable(
        bin_dir / "xcodebuild",
        f"""#!/bin/sh
if [ "$1" = "-version" ]; then
  printf 'Xcode 26.5 Beta\\nBuild version 17F5012f\\n'
  exit 0
fi
printf '%s\n' "$@" > {shlex.quote(str(xcodebuild_log))}
""",
    )
    _write_executable(
        bin_dir / "mise",
        f"""#!/bin/sh
printf '%s\n' "$@" > {shlex.quote(str(mise_log))}
""",
    )

    env = os.environ.copy()
    env["SUNCLUB_TUIST_SHARE"] = "0"
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["SUNCLUB_SKIP_VERSION_RESOLUTION"] = "1"

    subprocess.run(
        [
            "bash",
            str(repo_root / "scripts" / "tooling" / "build.sh"),
            "--skip-generate",
        ],
        check=True,
        cwd=repo_root,
        env=env,
    )

    xcodebuild_args = xcodebuild_log.read_text().splitlines()
    assert "SWIFT_ENABLE_COMPILE_CACHE=NO" in xcodebuild_args
    assert "COMPILATION_CACHE_ENABLE_CACHING=NO" in xcodebuild_args
    assert "COMPILATION_CACHE_ENABLE_PLUGIN=NO" in xcodebuild_args
    assert "COMPILATION_CACHE_REMOTE_SERVICE_PATH=" in xcodebuild_args
    assert not mise_log.exists()


def test_build_script_detects_beta_xcode_from_developer_dir(tmp_path: Path) -> None:
    repo_root = tmp_path / "repo"
    (repo_root / "app").mkdir(parents=True)

    for script_name in ("build.sh", "common.sh", "sunclub.env"):
        _copy_tooling_script(repo_root, script_name)

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()

    xcodebuild_log = tmp_path / "xcodebuild.log"
    mise_log = tmp_path / "mise.log"

    _write_executable(
        bin_dir / "xcodebuild",
        f"""#!/bin/sh
if [ "$1" = "-version" ]; then
  printf 'Xcode 26.5\\nBuild version 17F5012f\\n'
  exit 0
fi
printf '%s\\n' "$@" > {shlex.quote(str(xcodebuild_log))}
""",
    )
    _write_executable(
        bin_dir / "xcode-select",
        """#!/bin/sh
printf '/Applications/Xcode-26.5.0-Beta.app/Contents/Developer\\n'
""",
    )
    _write_executable(
        bin_dir / "mise",
        f"""#!/bin/sh
printf '%s\\n' "$@" > {shlex.quote(str(mise_log))}
""",
    )

    env = os.environ.copy()
    env["SUNCLUB_TUIST_SHARE"] = "0"
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["SUNCLUB_SKIP_VERSION_RESOLUTION"] = "1"

    subprocess.run(
        [
            "bash",
            str(repo_root / "scripts" / "tooling" / "build.sh"),
            "--skip-generate",
        ],
        check=True,
        cwd=repo_root,
        env=env,
    )

    xcodebuild_args = xcodebuild_log.read_text().splitlines()
    assert "COMPILATION_CACHE_ENABLE_CACHING=NO" in xcodebuild_args
    assert "COMPILATION_CACHE_ENABLE_PLUGIN=NO" in xcodebuild_args
    assert "COMPILATION_CACHE_REMOTE_SERVICE_PATH=" in xcodebuild_args
    assert not mise_log.exists()


def test_setup_local_tooling_env_exports_tuist_manifest_variables(tmp_path: Path) -> None:
    repo_root = tmp_path / "repo"
    (repo_root / "scripts" / "tooling").mkdir(parents=True)

    for script_name in ("common.sh", "sunclub.env"):
        _copy_tooling_script(repo_root, script_name)

    result = subprocess.run(
        [
            "bash",
            "-lc",
            """
source scripts/tooling/common.sh
export SUNCLUB_SKIP_VERSION_RESOLUTION=1
export SUNCLUB_MARKETING_VERSION=2.3.4
export SUNCLUB_BUILD_NUMBER=20260402.201417.0
export TEAM_ID=TEAM123
setup_local_tooling_env
printf 'flavor=%s\\n' "$TUIST_SUNCLUB_FLAVOR"
printf 'marketing=%s\\n' "$TUIST_SUNCLUB_MARKETING_VERSION"
printf 'build=%s\\n' "$TUIST_SUNCLUB_BUILD_NUMBER"
printf 'team=%s\\n' "$TUIST_TEAM_ID"
""",
        ],
        check=True,
        cwd=repo_root,
        text=True,
        capture_output=True,
    )

    assert "flavor=dev" in result.stdout
    assert "marketing=2.3.4" in result.stdout
    assert "build=20260402.201417.0" in result.stdout
    assert "team=TEAM123" in result.stdout


def test_build_script_ignores_tuist_share_failures(tmp_path: Path) -> None:
    repo_root = tmp_path / "repo"
    (repo_root / "app").mkdir(parents=True)

    for script_name in ("build.sh", "common.sh", "sunclub.env"):
        _copy_tooling_script(repo_root, script_name)

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()

    xcodebuild_log = tmp_path / "xcodebuild.log"

    _write_executable(
        bin_dir / "xcodebuild",
        f"""#!/bin/sh
printf '%s\\n' "$@" > {shlex.quote(str(xcodebuild_log))}
""",
    )
    _write_executable(
        bin_dir / "mise",
        """#!/bin/sh
if [ "$1" = "trust" ]; then
  exit 0
fi
if [ "$1" = "exec" ] && [ "$3" = "tuist" ] && [ "$4" = "share" ]; then
  exit 1
fi
exit 0
""",
    )

    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    env["SUNCLUB_SKIP_VERSION_RESOLUTION"] = "1"

    subprocess.run(
        [
            "bash",
            str(repo_root / "scripts" / "tooling" / "build.sh"),
            "--skip-generate",
        ],
        check=True,
        cwd=repo_root,
        env=env,
    )

    xcodebuild_args = xcodebuild_log.read_text().splitlines()
    assert xcodebuild_args[0] == "-workspace"
