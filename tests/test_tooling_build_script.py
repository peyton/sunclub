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
    assert mise_args[4] == "Sunclub"
    assert build_derived_data == str(derived_data_path)
    assert shared_derived_data == build_derived_data
    assert shared_configuration == "Release"
