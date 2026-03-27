from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import shlex


CONFIG_PATH = Path(__file__).with_name("sunclub.env")


def _parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        key, value = line.split("=", 1)
        parsed = shlex.split(value, posix=True)
        values[key] = parsed[0] if parsed else ""
    return values


@dataclass(frozen=True)
class ToolingConfig:
    app_workspace: str
    app_scheme: str
    app_identifier: str
    default_simulator_device: str
    run_simulator_name: str
    test_simulator_name: str
    screenshot_simulator_prefix: str
    run_app_path: str
    test_xcodebuild_args: str
    build_derived_data: str
    run_derived_data: str
    test_derived_data: str
    screenshot_derived_data: str
    archive_derived_data: str
    archive_path: str
    export_path: str
    export_options_path: str
    team_id: str


_raw_config = _parse_env_file(CONFIG_PATH)
CONFIG = ToolingConfig(
    app_workspace=_raw_config["APP_WORKSPACE"],
    app_scheme=_raw_config["APP_SCHEME"],
    app_identifier=_raw_config["APP_IDENTIFIER"],
    default_simulator_device=_raw_config["DEFAULT_SIMULATOR_DEVICE"],
    run_simulator_name=_raw_config["RUN_SIMULATOR_NAME"],
    test_simulator_name=_raw_config["TEST_SIMULATOR_NAME"],
    screenshot_simulator_prefix=_raw_config["SCREENSHOT_SIMULATOR_PREFIX"],
    run_app_path=_raw_config["RUN_APP_PATH"],
    test_xcodebuild_args=_raw_config["TEST_XCODEBUILD_ARGS"],
    build_derived_data=_raw_config["BUILD_DERIVED_DATA"],
    run_derived_data=_raw_config["RUN_DERIVED_DATA"],
    test_derived_data=_raw_config["TEST_DERIVED_DATA"],
    screenshot_derived_data=_raw_config["SCREENSHOT_DERIVED_DATA"],
    archive_derived_data=_raw_config["ARCHIVE_DERIVED_DATA"],
    archive_path=_raw_config["ARCHIVE_PATH"],
    export_path=_raw_config["EXPORT_PATH"],
    export_options_path=_raw_config["EXPORT_OPTIONS_PATH"],
    team_id=_raw_config["TEAM_ID"],
)
