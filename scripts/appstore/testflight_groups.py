"""Assign a processed TestFlight build to a beta tester group."""

from __future__ import annotations

import argparse
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
import json
import os
from pathlib import Path
import time
from typing import Any

from scripts.appstore.connect_api import (
    AppStoreConnectClient,
    AppStoreConnectError,
)
from scripts.tooling.resolve_versions import resolve_versions


REPO_ROOT = Path(__file__).resolve().parents[2]
METADATA_PATH = REPO_ROOT / "scripts" / "appstore" / "metadata.json"
BUILD_COMPLETE_STATE = "VALID"
BUILD_FAILED_STATES = {"FAILED", "INVALID"}

JsonObject = dict[str, Any]
SleepCallable = Callable[[float], None]


@dataclass(frozen=True)
class TestFlightGroupContext:
    bundle_id: str
    marketing_version: str
    build_number: str
    group_name: str = "Internal"
    timeout_seconds: int = 3600
    poll_interval_seconds: int = 60
    uses_non_exempt_encryption: bool = False


@dataclass(frozen=True)
class TestFlightGroupResult:
    app_id: str
    build_id: str
    group_id: str


class TestFlightGroupAssigner:
    def __init__(
        self,
        client: AppStoreConnectClient,
        context: TestFlightGroupContext,
        *,
        sleep: SleepCallable = time.sleep,
    ) -> None:
        self.client = client
        self.context = context
        self.sleep = sleep

    def assign(self) -> TestFlightGroupResult:
        app_id = self.lookup_app_id()
        group_id = self.lookup_beta_group_id(app_id)
        build_id = self.wait_for_valid_build(app_id)
        self.mark_encryption_compliance(build_id)
        self.add_group_access(build_id, group_id)
        return TestFlightGroupResult(
            app_id=app_id,
            build_id=build_id,
            group_id=group_id,
        )

    def lookup_app_id(self) -> str:
        apps = self.client.get_collection(
            "/apps",
            query={"filter[bundleId]": self.context.bundle_id, "limit": 1},
        )
        if not apps:
            raise AppStoreConnectError(
                "No App Store Connect app exists for bundle ID "
                f"{self.context.bundle_id}."
            )
        return resource_id(apps[0])

    def lookup_beta_group_id(self, app_id: str) -> str:
        groups = self.client.get_collection(
            f"/apps/{app_id}/betaGroups",
            query={"fields[betaGroups]": "name,isInternalGroup", "limit": 200},
        )
        names: list[str] = []
        for group in groups:
            attributes = resource_attributes(group)
            name = str(attributes.get("name", ""))
            names.append(name)
            if name != self.context.group_name:
                continue
            if attributes.get("isInternalGroup") is not True:
                raise AppStoreConnectError(
                    f"TestFlight group {self.context.group_name!r} exists "
                    "but is not an internal tester group."
                )
            return resource_id(group)

        available = ", ".join(sorted(name for name in names if name)) or "none"
        raise AppStoreConnectError(
            f"Could not find internal TestFlight group "
            f"{self.context.group_name!r} for app {app_id}. "
            f"Available groups: {available}."
        )

    def wait_for_valid_build(self, app_id: str) -> str:
        deadline = time.monotonic() + self.context.timeout_seconds
        while True:
            builds = self.client.get_collection(
                "/builds",
                query={
                    "filter[app]": app_id,
                    "filter[version]": self.context.build_number,
                    "filter[preReleaseVersion.version]": (
                        self.context.marketing_version
                    ),
                    "fields[builds]": (
                        "version,processingState,uploadedDate,usesNonExemptEncryption"
                    ),
                    "sort": "-uploadedDate",
                    "limit": 10,
                },
            )
            if builds:
                build = builds[0]
                build_id = resource_id(build)
                state = str(resource_attributes(build).get("processingState", ""))
                if state == BUILD_COMPLETE_STATE:
                    return build_id
                if state in BUILD_FAILED_STATES:
                    raise AppStoreConnectError(
                        f"Build {build_id} processing failed: {state}."
                    )
                print(
                    f"Build {build_id} is {state or 'not ready'}; waiting "
                    f"{self.context.poll_interval_seconds}s."
                )
            else:
                print(
                    "Waiting for TestFlight build "
                    f"{self.context.marketing_version} "
                    f"({self.context.build_number}) to appear."
                )

            if time.monotonic() >= deadline:
                raise AppStoreConnectError(
                    "Timed out waiting for App Store Connect build "
                    f"{self.context.marketing_version} "
                    f"({self.context.build_number}) to become VALID."
                )
            self.sleep(self.context.poll_interval_seconds)

    def mark_encryption_compliance(self, build_id: str) -> None:
        try:
            self.client.patch(
                f"/builds/{build_id}",
                {
                    "data": {
                        "type": "builds",
                        "id": build_id,
                        "attributes": {
                            "usesNonExemptEncryption": (
                                self.context.uses_non_exempt_encryption
                            )
                        },
                    }
                },
            )
        except AppStoreConnectError as error_:
            if is_already_set_error(error_):
                print(
                    "Build encryption compliance is already set; "
                    "continuing to TestFlight group assignment."
                )
                return
            raise

    def add_group_access(self, build_id: str, group_id: str) -> None:
        existing_builds = self.client.get_collection(
            f"/betaGroups/{group_id}/relationships/builds",
            query={"limit": 200},
        )
        if any(resource_id(build) == build_id for build in existing_builds):
            print(f"Build {build_id} already has access to group {group_id}.")
            return

        self.client.post(
            f"/builds/{build_id}/relationships/betaGroups",
            {"data": [{"type": "betaGroups", "id": group_id}]},
        )


def resource_id(resource: Mapping[str, Any]) -> str:
    value = resource.get("id")
    if not isinstance(value, str) or not value:
        raise AppStoreConnectError(
            "App Store Connect response is missing a resource id."
        )
    return value


def resource_attributes(resource: Mapping[str, Any]) -> JsonObject:
    attributes = resource.get("attributes", {})
    if not isinstance(attributes, dict):
        return {}
    return attributes


def is_already_set_error(error_: AppStoreConnectError) -> bool:
    message = str(error_)
    return "HTTP 409" in message and "value is already set" in message


def default_bundle_id() -> str:
    with METADATA_PATH.open("r", encoding="utf-8") as metadata_file:
        metadata = json.load(metadata_file)
    return str(metadata["app"]["bundle_id"])


def bool_argument(value: str) -> bool:
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes"}:
        return True
    if normalized in {"0", "false", "no"}:
        return False
    raise argparse.ArgumentTypeError("expected one of: true, false, 1, 0, yes, no")


def build_context(
    args: argparse.Namespace,
    environment: Mapping[str, str] | None = None,
) -> TestFlightGroupContext:
    values = environment or os.environ
    versions = resolve_versions(values)
    return TestFlightGroupContext(
        bundle_id=args.bundle_id,
        marketing_version=args.marketing_version or versions.marketing_version,
        build_number=args.build_number or versions.build_number,
        group_name=args.group,
        timeout_seconds=args.timeout_seconds,
        poll_interval_seconds=args.poll_interval_seconds,
        uses_non_exempt_encryption=args.uses_non_exempt_encryption,
    )


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Assign a processed TestFlight build to a beta tester group.",
    )
    parser.add_argument("--bundle-id", default=default_bundle_id())
    parser.add_argument("--marketing-version")
    parser.add_argument("--build-number")
    parser.add_argument("--group", default="Internal")
    parser.add_argument("--timeout-seconds", type=int, default=3600)
    parser.add_argument("--poll-interval-seconds", type=int, default=60)
    parser.add_argument(
        "--uses-non-exempt-encryption",
        type=bool_argument,
        default=False,
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    context = build_context(args)
    client = AppStoreConnectClient.from_env()
    result = TestFlightGroupAssigner(client, context).assign()
    print(
        "Assigned TestFlight build "
        f"{context.marketing_version} ({context.build_number}) "
        f"to {context.group_name} "
        f"(app={result.app_id}, build={result.build_id}, group={result.group_id})."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
