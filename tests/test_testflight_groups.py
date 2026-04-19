from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

import pytest

from scripts.appstore.connect_api import AppStoreConnectError
from scripts.appstore.testflight_groups import (
    TestFlightGroupAssigner as GroupAssigner,
    TestFlightGroupContext as GroupContext,
    build_context,
)


class FakeTestFlightClient:
    def __init__(
        self,
        *,
        build_states: Sequence[str] = ("PROCESSING", "VALID"),
        group_is_internal: bool = True,
        already_assigned: bool = False,
    ) -> None:
        self.build_states = list(build_states)
        self.group_is_internal = group_is_internal
        self.already_assigned = already_assigned
        self.build_calls = 0
        self.posts: list[tuple[str, Mapping[str, Any]]] = []
        self.patches: list[tuple[str, Mapping[str, Any]]] = []

    def get_collection(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[dict[str, Any]]:
        if path == "/apps":
            assert query == {"filter[bundleId]": "app.peyton.sunclub", "limit": 1}
            return [{"type": "apps", "id": "app-1", "attributes": {}}]
        if path == "/apps/app-1/betaGroups":
            return [
                {
                    "type": "betaGroups",
                    "id": "group-1",
                    "attributes": {
                        "name": "Internal",
                        "isInternalGroup": self.group_is_internal,
                    },
                }
            ]
        if path == "/builds":
            self.build_calls += 1
            state_index = min(self.build_calls - 1, len(self.build_states) - 1)
            assert query == {
                "filter[app]": "app-1",
                "filter[version]": "20260419.44.1",
                "filter[preReleaseVersion.version]": "1.0.45",
                "fields[builds]": (
                    "version,processingState,uploadedDate,usesNonExemptEncryption"
                ),
                "sort": "-uploadedDate",
                "limit": 10,
            }
            return [
                {
                    "type": "builds",
                    "id": "build-1",
                    "attributes": {"processingState": self.build_states[state_index]},
                }
            ]
        if path == "/betaGroups/group-1/relationships/builds":
            assert query == {"limit": 200}
            if self.already_assigned:
                return [{"type": "builds", "id": "build-1"}]
            return []
        raise AssertionError(f"Unexpected collection path: {path}")

    def patch(self, path: str, body: Mapping[str, Any]) -> dict[str, Any]:
        self.patches.append((path, body))
        return {}

    def post(self, path: str, body: Mapping[str, Any]) -> dict[str, Any]:
        self.posts.append((path, body))
        return {}


def test_assigner_waits_for_valid_build_and_adds_internal_group() -> None:
    client = FakeTestFlightClient()
    context = GroupContext(
        bundle_id="app.peyton.sunclub",
        marketing_version="1.0.45",
        build_number="20260419.44.1",
        poll_interval_seconds=0,
    )

    result = GroupAssigner(client, context, sleep=lambda _: None).assign()

    assert result.app_id == "app-1"
    assert result.build_id == "build-1"
    assert result.group_id == "group-1"
    assert client.patches == [
        (
            "/builds/build-1",
            {
                "data": {
                    "type": "builds",
                    "id": "build-1",
                    "attributes": {"usesNonExemptEncryption": False},
                }
            },
        )
    ]
    assert client.posts == [
        (
            "/builds/build-1/relationships/betaGroups",
            {"data": [{"type": "betaGroups", "id": "group-1"}]},
        )
    ]


def test_assigner_is_idempotent_when_build_is_already_in_group() -> None:
    client = FakeTestFlightClient(build_states=("VALID",), already_assigned=True)
    context = GroupContext(
        bundle_id="app.peyton.sunclub",
        marketing_version="1.0.45",
        build_number="20260419.44.1",
        poll_interval_seconds=0,
    )

    result = GroupAssigner(client, context, sleep=lambda _: None).assign()

    assert result.build_id == "build-1"
    assert client.posts == []


def test_assigner_rejects_external_group_named_internal() -> None:
    client = FakeTestFlightClient(group_is_internal=False)
    context = GroupContext(
        bundle_id="app.peyton.sunclub",
        marketing_version="1.0.45",
        build_number="20260419.44.1",
        poll_interval_seconds=0,
    )

    with pytest.raises(AppStoreConnectError, match="not an internal tester group"):
        GroupAssigner(client, context, sleep=lambda _: None).assign()


def test_build_context_uses_release_workflow_environment() -> None:
    args = type(
        "Args",
        (),
        {
            "bundle_id": "app.peyton.sunclub",
            "marketing_version": None,
            "build_number": None,
            "group": "Internal",
            "timeout_seconds": 120,
            "poll_interval_seconds": 5,
            "uses_non_exempt_encryption": False,
        },
    )()

    context = build_context(
        args,
        {
            "GITHUB_REF_TYPE": "tag",
            "GITHUB_REF_NAME": "v1.0.45",
            "GITHUB_RUN_NUMBER": "44",
            "GITHUB_RUN_ATTEMPT": "1",
        },
    )

    assert context.bundle_id == "app.peyton.sunclub"
    assert context.marketing_version == "1.0.45"
    assert context.build_number.endswith(".44.1")
    assert context.group_name == "Internal"
