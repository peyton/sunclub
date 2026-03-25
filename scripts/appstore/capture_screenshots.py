#!/usr/bin/env python3

from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
METADATA_PATH = REPO_ROOT / "scripts/appstore/metadata.json"
VALIDATOR_PATH = REPO_ROOT / "scripts/appstore/validate_metadata.py"
SIMULATOR_RESOLVER = REPO_ROOT / "scripts/resolve_simulator.py"
DERIVED_DATA = REPO_ROOT / ".DerivedData/screenshots"
APP_PATH = DERIVED_DATA / "Build/Products/Debug-iphonesimulator/Sunclub.app"


def run(
    command: list[str], *, cwd: Path | None = None, check: bool = True
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        check=check,
        text=True,
        capture_output=True,
    )


def run_logged(
    command: list[str], *, cwd: Path | None = None, check: bool = True
) -> None:
    result = subprocess.run(
        command, cwd=str(cwd) if cwd else None, check=check, text=True
    )
    if result.returncode != 0 and check:
        raise subprocess.CalledProcessError(result.returncode, command)


def main() -> int:
    if not VALIDATOR_PATH.is_file():
        print(f"Missing validator: {VALIDATOR_PATH}", file=sys.stderr)
        return 2

    with METADATA_PATH.open() as handle:
        manifest = json.load(handle)

    subprocess.run(
        [sys.executable, str(VALIDATOR_PATH), "--allow-draft", str(METADATA_PATH)],
        check=True,
    )

    screenshots = manifest["assets"]["screenshots"]
    device = screenshots["capture_device"]
    output_dir = REPO_ROOT / screenshots["output_directory"]
    screens = screenshots["screens"]
    bundle_id = manifest["app"]["bundle_id"]

    output_dir.mkdir(parents=True, exist_ok=True)

    simulator_udid = run(
        [
            sys.executable,
            str(SIMULATOR_RESOLVER),
            "--name",
            f"Sunclub Screenshots {device}",
            "--device-type-name",
            device,
        ]
    ).stdout.strip()

    run_logged(["tuist", "install"], cwd=REPO_ROOT / "app")
    run_logged(["tuist", "generate", "--no-open"], cwd=REPO_ROOT / "app")

    build_command = [
        "xcodebuild",
        "build",
        "-workspace",
        "app/Sunclub.xcworkspace",
        "-scheme",
        "Sunclub",
        "-configuration",
        "Debug",
        "-sdk",
        "iphonesimulator",
        "-destination",
        f"id={simulator_udid}",
        "-derivedDataPath",
        str(DERIVED_DATA),
    ]
    run_logged(build_command, cwd=REPO_ROOT)

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
