from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CREATE_CONTAINER_HELP_URL = (
    "https://developer.apple.com/help/account/identifiers/create-an-icloud-container/"
)
IDENTIFIERS_URL = "https://developer.apple.com/account/resources/identifiers/list"


def _write_executable(path: Path, contents: str) -> None:
    path.write_text(contents)
    path.chmod(0o755)


def _copy_script(repo_root: Path, source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def _prepare_cloudkit_repo(tmp_path: Path) -> tuple[Path, Path]:
    repo_root = tmp_path / "repo"
    (repo_root / "app" / "Sunclub.xcworkspace").mkdir(parents=True)

    for script_name in (
        "common.sh",
        "doctor.sh",
        "ensure-container.sh",
    ):
        _copy_script(
            repo_root,
            REPO_ROOT / "scripts" / "cloudkit" / script_name,
            repo_root / "scripts" / "cloudkit" / script_name,
        )

    for script_name in ("common.sh", "sunclub.env"):
        _copy_script(
            repo_root,
            REPO_ROOT / "scripts" / "tooling" / script_name,
            repo_root / "scripts" / "tooling" / script_name,
        )

    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    open_log = tmp_path / "open.log"

    _write_executable(
        bin_dir / "xcrun",
        """#!/bin/sh
if [ "$1" != "cktool" ]; then
  echo "unsupported tool: $1" >&2
  exit 64
fi
shift

subcommand="$1"
shift

case "$subcommand" in
  version)
    exit 0
    ;;
  get-teams)
    printf '%s\n' "${FAKE_CKTOOL_TEAMS:-3VDQ4656LX: Peyton Randolph}"
    ;;
  export-schema)
    output_file=""
    while [ $# -gt 0 ]; do
      if [ "$1" = "--output-file" ]; then
        output_file="$2"
        shift 2
        continue
      fi
      shift
    done

    if [ "${FAKE_CKTOOL_EXPORT_MODE:-success}" = "success" ]; then
      printf '{}\n' >"$output_file"
      exit 0
    fi

    printf '❌ An error occurred while performing the command.\n' >&2
    printf 'Operation: export\n' >&2
    printf 'An unknown error occured with message: authorization-failed.\n' >&2
    exit 1
    ;;
  *)
    echo "unsupported cktool subcommand: $subcommand" >&2
    exit 64
    ;;
esac
""",
    )

    _write_executable(
        bin_dir / "xcodebuild",
        """#!/bin/sh
derived_data=""
while [ $# -gt 0 ]; do
  if [ "$1" = "-derivedDataPath" ]; then
    derived_data="$2"
    shift 2
    continue
  fi
  shift
done

if [ -z "$derived_data" ]; then
  echo "missing -derivedDataPath" >&2
  exit 64
fi

xcent_path="$derived_data/Build/Intermediates.noindex/Sunclub.build/Debug-iphoneos/Sunclub.build/Sunclub.app.xcent"
mkdir -p "$(dirname "$xcent_path")"

if [ "${FAKE_XCENT_MODE:-plain}" = "cloudkit" ]; then
  cat >"$xcent_path" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>application-identifier</key>
  <string>3VDQ4656LX.app.peyton.sunclub</string>
  <key>com.apple.developer.icloud-container-identifiers</key>
  <array>
    <string>iCloud.app.peyton.sunclub</string>
  </array>
  <key>com.apple.developer.icloud-services</key>
  <array>
    <string>CloudKit</string>
  </array>
  <key>com.apple.developer.team-identifier</key>
  <string>3VDQ4656LX</string>
</dict>
</plist>
EOF
else
  cat >"$xcent_path" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>application-identifier</key>
  <string>3VDQ4656LX.app.peyton.sunclub</string>
  <key>com.apple.developer.team-identifier</key>
  <string>3VDQ4656LX</string>
</dict>
</plist>
EOF
fi
""",
    )

    _write_executable(
        bin_dir / "open",
        f"""#!/bin/sh
printf '%s\\n' "$@" >> {open_log}
""",
    )

    return repo_root, open_log


def test_cloudkit_doctor_succeeds_with_management_access_and_schema_access(
    tmp_path: Path,
) -> None:
    repo_root, _ = _prepare_cloudkit_repo(tmp_path)

    env = os.environ.copy()
    env["PATH"] = f"{tmp_path / 'bin'}:{env['PATH']}"
    env["FAKE_CKTOOL_EXPORT_MODE"] = "success"
    env["SUNCLUB_SKIP_VERSION_RESOLUTION"] = "1"

    result = subprocess.run(
        ["bash", str(repo_root / "scripts" / "cloudkit" / "doctor.sh")],
        capture_output=True,
        text=True,
        cwd=repo_root,
        env=env,
        check=False,
    )

    assert result.returncode == 0
    assert "Validated CloudKit management token for team 3VDQ4656LX" in result.stdout
    assert (
        "CloudKit management API can export schema for iCloud.app.peyton.sunclub"
        in result.stdout
    )


def test_cloudkit_doctor_fails_when_token_cannot_access_configured_team(
    tmp_path: Path,
) -> None:
    repo_root, _ = _prepare_cloudkit_repo(tmp_path)

    env = os.environ.copy()
    env["PATH"] = f"{tmp_path / 'bin'}:{env['PATH']}"
    env["FAKE_CKTOOL_TEAMS"] = "OTHERTEAM: Someone Else"
    env["SUNCLUB_SKIP_VERSION_RESOLUTION"] = "1"

    result = subprocess.run(
        ["bash", str(repo_root / "scripts" / "cloudkit" / "doctor.sh")],
        capture_output=True,
        text=True,
        cwd=repo_root,
        env=env,
        check=False,
    )

    assert result.returncode == 1
    assert "Configured CloudKit team 3VDQ4656LX is not visible" in result.stderr


def test_cloudkit_ensure_container_opens_setup_when_cloudkit_is_missing(
    tmp_path: Path,
) -> None:
    repo_root, open_log = _prepare_cloudkit_repo(tmp_path)
    _write_executable(
        tmp_path / "bin" / "plutil",
        """#!/bin/sh
exit 127
""",
    )

    env = os.environ.copy()
    env["PATH"] = f"{tmp_path / 'bin'}:{env['PATH']}"
    env["FAKE_CKTOOL_EXPORT_MODE"] = "auth-failed"
    env["FAKE_XCENT_MODE"] = "plain"
    env["SUNCLUB_SKIP_VERSION_RESOLUTION"] = "1"

    result = subprocess.run(
        ["bash", str(repo_root / "scripts" / "cloudkit" / "ensure-container.sh")],
        capture_output=True,
        text=True,
        cwd=repo_root,
        env=env,
        check=False,
    )

    combined_output = result.stdout + result.stderr

    assert result.returncode == 2
    assert (
        "CloudKit is not configured for App ID app.peyton.sunclub on team 3VDQ4656LX."
        in combined_output
    )
    assert (
        "Apple's docs say creating an iCloud container requires the Account Holder or Admin role."
        in combined_output
    )

    opened_urls = open_log.read_text().splitlines()
    assert IDENTIFIERS_URL in opened_urls
    assert CREATE_CONTAINER_HELP_URL in opened_urls
