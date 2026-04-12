#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

from scripts.tooling.config import CONFIG

REPO_ROOT = Path(__file__).resolve().parents[2]
METADATA_PATH = REPO_ROOT / "scripts/appstore/metadata.json"
DERIVED_DATA = REPO_ROOT / CONFIG.screenshot_derived_data
APP_PATH = DERIVED_DATA / CONFIG.run_app_path_for_flavor("prod")


def run(
    command: list[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        check=check,
        text=True,
        capture_output=True,
        env=env,
    )


def run_logged(
    command: list[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    env: dict[str, str] | None = None,
) -> None:
    result = subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        check=check,
        text=True,
        env=env,
    )
    if result.returncode != 0 and check:
        raise subprocess.CalledProcessError(result.returncode, command)


def screenshot_build_environment() -> dict[str, str]:
    env = {**os.environ, "SUNCLUB_FLAVOR": "prod", "SUNCLUB_TUIST_SHARE": "0"}
    for key in ("APP_SCHEME", "APP_IDENTIFIER", "RUN_APP_PATH"):
        env.pop(key, None)
    return env


def main() -> int:
    with METADATA_PATH.open() as handle:
        manifest = json.load(handle)

    subprocess.run(
        [
            sys.executable,
            "-m",
            "scripts.appstore.validate_metadata",
            "--allow-draft",
            str(METADATA_PATH),
        ],
        check=True,
    )

    screenshots = manifest["assets"]["screenshots"]
    device = screenshots["capture_device"]
    output_dir = REPO_ROOT / screenshots["output_directory"]
    screens = screenshots["screens"]
    bundle_id = CONFIG.release_app_identifier

    output_dir.mkdir(parents=True, exist_ok=True)

    simulator_udid = run(
        [
            sys.executable,
            "-m",
            "scripts.resolve_simulator",
            "--name",
            f"{CONFIG.screenshot_simulator_prefix} {device}",
            "--device-type-name",
            device,
        ]
    ).stdout.strip()

    run_logged(
        [
            "bash",
            "scripts/tooling/build.sh",
            "--configuration",
            "Debug",
            "--destination",
            f"id={simulator_udid}",
            "--derived-data-path",
            str(DERIVED_DATA),
            "--skip-share",
        ],
        cwd=REPO_ROOT,
        env=screenshot_build_environment(),
    )

    if not APP_PATH.is_dir():
        print(f"Built app not found: {APP_PATH}", file=sys.stderr)
        return 1

    run(["xcrun", "simctl", "shutdown", simulator_udid], check=False)
    run(["xcrun", "simctl", "erase", simulator_udid], check=False)
    run(["xcrun", "simctl", "boot", simulator_udid], check=False)
    run_logged(["xcrun", "simctl", "bootstatus", simulator_udid, "-b"])
    run(["xcrun", "simctl", "terminate", simulator_udid, bundle_id], check=False)
    run(["xcrun", "simctl", "uninstall", simulator_udid, bundle_id], check=False)
    run_logged(["xcrun", "simctl", "install", simulator_udid, str(APP_PATH)])
    run_logged(
        [
            "xcrun",
            "simctl",
            "status_bar",
            simulator_udid,
            "override",
            "--time",
            "9:41",
            "--dataNetwork",
            "wifi",
            "--wifiBars",
            "3",
            "--cellularMode",
            "active",
            "--cellularBars",
            "4",
            "--batteryState",
            "charged",
            "--batteryLevel",
            "100",
        ]
    )

    try:
        for screen in screens:
            screen_id = screen["id"]
            route = screen["route"]
            complete_onboarding = bool(screen["complete_onboarding"])
            launch_arguments = list(screen.get("launch_arguments", []))

            arguments = ["UITEST_MODE", f"UITEST_ROUTE={route}"]
            if complete_onboarding:
                arguments.append("UITEST_COMPLETE_ONBOARDING")
            arguments.extend(launch_arguments)

            run(
                ["xcrun", "simctl", "terminate", simulator_udid, bundle_id], check=False
            )
            run_logged(
                ["xcrun", "simctl", "launch", simulator_udid, bundle_id, *arguments]
            )
            time.sleep(1.5)

            output_path = output_dir / f"{screen_id}.png"
            if output_path.exists():
                output_path.unlink()
            run_logged(
                [
                    "xcrun",
                    "simctl",
                    "io",
                    simulator_udid,
                    "screenshot",
                    str(output_path),
                ]
            )
            print(f"Saved {output_path}")
    finally:
        run(["xcrun", "simctl", "status_bar", simulator_udid, "clear"], check=False)

    print(f"\nSaved {len(screens)} screenshots to {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
