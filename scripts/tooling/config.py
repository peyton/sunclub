from __future__ import annotations

from dataclasses import dataclass
import os
from pathlib import Path
import re
import shlex


CONFIG_PATH = Path(__file__).with_name("sunclub.env")
DEFAULT_PATTERN = re.compile(r"^\$\{(?P<name>[A-Z0-9_]+):-(?P<default>.*)\}$")


def _resolve_shell_default(value: str) -> str:
    match = DEFAULT_PATTERN.match(value)
    if match is None:
        return value

    name = match.group("name")
    return os.environ.get(name, match.group("default"))


def _parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        key, value = line.split("=", 1)
        parsed = shlex.split(value, posix=True)
        values[key] = _resolve_shell_default(parsed[0]) if parsed else ""
    return values


@dataclass(frozen=True)
class ToolingConfig:
    app_workspace: str
    sunclub_flavor: str
    dev_app_scheme: str
    dev_app_identifier: str
    dev_app_product_name: str
    release_app_scheme: str
    release_app_identifier: str
    release_app_product_name: str
    app_scheme_override: str
    app_identifier_override: str
    run_app_path_override: str
    default_simulator_device: str
    run_simulator_name: str
    test_simulator_name: str
    screenshot_simulator_prefix: str
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
    cloudkit_container_id: str
    cloudkit_team_id: str
    cloudkit_environment: str

    @property
    def app_scheme(self) -> str:
        return self.app_scheme_override or self.app_scheme_for_flavor(self.sunclub_flavor)

    @property
    def app_identifier(self) -> str:
        return self.app_identifier_override or self.app_identifier_for_flavor(self.sunclub_flavor)

    @property
    def run_app_path(self) -> str:
        return self.run_app_path_override or self.run_app_path_for_flavor(self.sunclub_flavor)

    def app_scheme_for_flavor(self, flavor: str) -> str:
        normalized = normalize_flavor(flavor)
        return self.release_app_scheme if normalized == "prod" else self.dev_app_scheme

    def app_identifier_for_flavor(self, flavor: str) -> str:
        normalized = normalize_flavor(flavor)
        return (
            self.release_app_identifier
            if normalized == "prod"
            else self.dev_app_identifier
        )

    def product_name_for_flavor(self, flavor: str) -> str:
        normalized = normalize_flavor(flavor)
        return (
            self.release_app_product_name
            if normalized == "prod"
            else self.dev_app_product_name
        )

    def run_app_path_for_flavor(self, flavor: str) -> str:
        return (
            f"Build/Products/Debug-iphonesimulator/"
            f"{self.product_name_for_flavor(flavor)}.app"
        )


def normalize_flavor(flavor: str) -> str:
    return "prod" if flavor == "prod" else "dev"


_raw_config = _parse_env_file(CONFIG_PATH)
CONFIG = ToolingConfig(
    app_workspace=_raw_config["APP_WORKSPACE"],
    sunclub_flavor=normalize_flavor(_raw_config["SUNCLUB_FLAVOR"]),
    dev_app_scheme=_raw_config["DEV_APP_SCHEME"],
    dev_app_identifier=_raw_config["DEV_APP_IDENTIFIER"],
    dev_app_product_name=_raw_config["DEV_APP_PRODUCT_NAME"],
    release_app_scheme=_raw_config["RELEASE_APP_SCHEME"],
    release_app_identifier=_raw_config["RELEASE_APP_IDENTIFIER"],
    release_app_product_name=_raw_config["RELEASE_APP_PRODUCT_NAME"],
    app_scheme_override=_raw_config["APP_SCHEME"],
    app_identifier_override=_raw_config["APP_IDENTIFIER"],
    run_app_path_override=_raw_config["RUN_APP_PATH"],
    default_simulator_device=_raw_config["DEFAULT_SIMULATOR_DEVICE"],
    run_simulator_name=_raw_config["RUN_SIMULATOR_NAME"],
    test_simulator_name=_raw_config["TEST_SIMULATOR_NAME"],
    screenshot_simulator_prefix=_raw_config["SCREENSHOT_SIMULATOR_PREFIX"],
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
    cloudkit_container_id=_raw_config["CLOUDKIT_CONTAINER_ID"],
    cloudkit_team_id=_raw_config["CLOUDKIT_TEAM_ID"],
    cloudkit_environment=_raw_config["CLOUDKIT_ENVIRONMENT"],
)
