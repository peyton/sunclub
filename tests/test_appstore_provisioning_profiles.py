from __future__ import annotations

import base64
from collections.abc import Mapping, Sequence
from datetime import UTC, datetime, timedelta
import plistlib
from pathlib import Path
from typing import Any

import scripts.appstore.provisioning_profiles as provisioning_profiles
from scripts.appstore.connect_api import AppStoreConnectError
from scripts.appstore.provisioning_profiles import (
    APP_STORE_PROFILE_TYPE,
    ArchivedBundle,
    collect_archived_bundles,
    ensure_profiles,
    find_bundle_id,
    find_reusable_certificate_ids,
    missing_profile_entitlements,
)


class FakeProfilesClient:
    def __init__(self) -> None:
        self.posts: list[dict[str, Any]] = []

    def get(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> dict[str, Any]:
        if path == "/profiles/profile-existing":
            return {"data": existing_profile("profile-existing")}
        if path == "/profiles/profile-existing/relationships/certificates":
            return {
                "data": [
                    {
                        "type": "certificates",
                        "id": "cert-profile-existing",
                    }
                ]
            }
        raise AssertionError(f"Unexpected GET: {path} {query}")

    def get_collection(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[dict[str, Any]]:
        query = query or {}
        if path == "/bundleIds":
            identifier = query["filter[identifier]"]
            return [bundle_id(f"bundle-{identifier}", str(identifier))]
        if path == "/bundleIds/bundle-app.peyton.sunclub/profiles":
            assert "filter[profileType]" not in query
            return [existing_profile("profile-existing")]
        if path.startswith("/bundleIds/") and path.endswith("/profiles"):
            assert "filter[profileType]" not in query
            return []
        if path == "/certificates":
            certificate_type = query["filter[certificateType]"]
            if certificate_type == "DISTRIBUTION":
                return [certificate("cert-distribution")]
            return []
        raise AssertionError(f"Unexpected collection: {path} {query}")

    def post(self, path: str, body: Mapping[str, Any]) -> dict[str, Any]:
        assert path == "/profiles"
        self.posts.append(dict(body))
        attributes = body["data"]["attributes"]  # type: ignore[index]
        relationships = body["data"]["relationships"]  # type: ignore[index]
        bundle_id = relationships["bundleId"]["data"]["id"]
        return {
            "data": {
                "type": "profiles",
                "id": f"profile-{bundle_id}",
                "attributes": {
                    "name": attributes["name"],
                    "profileType": attributes["profileType"],
                    "profileState": "ACTIVE",
                    "expirationDate": future_date(),
                    "uuid": f"uuid-{bundle_id}",
                    "profileContent": profile_content(),
                },
            }
        }


def test_collect_archived_bundles_reads_app_and_nested_extensions(
    tmp_path: Path,
) -> None:
    archive_path = tmp_path / "Sunclub.xcarchive"
    app_path = archive_path / "Products" / "Applications" / "Sunclub.app"
    widget_path = app_path / "PlugIns" / "SunclubWidgetsExtension.appex"
    watch_path = app_path / "Watch" / "SunclubWatch.app"
    watch_extension_path = watch_path / "PlugIns" / "SunclubWatchExtension.appex"

    write_info_plist(app_path, "app.peyton.sunclub", "APPL")
    write_info_plist(widget_path, "app.peyton.sunclub.widgets", "XPC!")
    write_info_plist(watch_path, "app.peyton.sunclub.watch", "APPL")
    write_info_plist(
        watch_extension_path,
        "app.peyton.sunclub.watch.extension",
        "XPC!",
    )

    bundles = collect_archived_bundles(archive_path, "Sunclub")

    assert [bundle.bundle_identifier for bundle in bundles] == [
        "app.peyton.sunclub",
        "app.peyton.sunclub.watch",
        "app.peyton.sunclub.widgets",
        "app.peyton.sunclub.watch.extension",
    ]
    assert {bundle.profile_type for bundle in bundles} == {APP_STORE_PROFILE_TYPE}


def test_ensure_profiles_reuses_existing_profiles_and_creates_missing_ones(
    tmp_path: Path,
) -> None:
    client = FakeProfilesClient()
    bundles = [
        ArchivedBundle(
            path=tmp_path / "Sunclub.app",
            relative_path="Sunclub.app",
            bundle_identifier="app.peyton.sunclub",
            package_type="APPL",
        ),
        ArchivedBundle(
            path=tmp_path / "SunclubWatchExtension.appex",
            relative_path="SunclubWatch.app/PlugIns/SunclubWatchExtension.appex",
            bundle_identifier="app.peyton.sunclub.watch.extension",
            package_type="XPC!",
        ),
    ]

    prepared = ensure_profiles(
        client,
        bundles,
        create_missing=True,
        install_directory=tmp_path / "profiles",
    )

    assert [profile.created for profile in prepared] == [False, True]
    assert len(client.posts) == 1
    posted_data = client.posts[0]["data"]
    assert posted_data["attributes"]["name"].startswith(
        "Sunclub App Store app.peyton.sunclub.watch.extension "
    )
    assert posted_data["attributes"]["profileType"] == APP_STORE_PROFILE_TYPE
    assert posted_data["relationships"]["bundleId"]["data"] == {
        "type": "bundleIds",
        "id": "bundle-app.peyton.sunclub.watch.extension",
    }
    assert posted_data["relationships"]["certificates"]["data"] == [
        {"type": "certificates", "id": "cert-distribution"}
    ]
    assert (
        tmp_path / "profiles" / "uuid-profile-existing.mobileprovision"
    ).read_bytes()
    assert (
        tmp_path
        / "profiles"
        / "uuid-bundle-app.peyton.sunclub.watch.extension.mobileprovision"
    ).read_bytes()


def test_ensure_profiles_skips_stale_profile_missing_required_entitlements(
    tmp_path: Path, monkeypatch: Any
) -> None:
    client = FakeProfilesClient()
    bundle = ArchivedBundle(
        path=tmp_path / "Sunclub.app",
        relative_path="Sunclub.app",
        bundle_identifier="app.peyton.sunclub",
        package_type="APPL",
    )
    required = {"com.apple.security.application-groups": ["group.app.peyton.sunclub"]}

    def read_bundle_profile_entitlements(_path: Path) -> dict[str, Any]:
        return required

    def profile_entitlements_from_content(
        _client: FakeProfilesClient, profile: dict[str, Any]
    ) -> dict[str, Any]:
        if profile["id"] == "profile-existing":
            return {"com.apple.security.application-groups": ["group.app.peyton.other"]}
        return required

    monkeypatch.setattr(
        provisioning_profiles,
        "read_bundle_profile_entitlements",
        read_bundle_profile_entitlements,
    )
    monkeypatch.setattr(
        provisioning_profiles,
        "profile_entitlements_from_content",
        profile_entitlements_from_content,
    )

    prepared = ensure_profiles(
        client,
        [bundle],
        create_missing=True,
        install_directory=None,
    )

    assert [profile.created for profile in prepared] == [True]
    assert len(client.posts) == 1
    posted_data = client.posts[0]["data"]
    assert posted_data["relationships"]["bundleId"]["data"] == {
        "type": "bundleIds",
        "id": "bundle-app.peyton.sunclub",
    }
    assert posted_data["relationships"]["certificates"]["data"] == [
        {"type": "certificates", "id": "cert-profile-existing"}
    ]


def test_find_reusable_certificate_ids_skips_deleted_profile_candidates() -> None:
    client = FakeProfilesClient()

    def get(
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> dict[str, Any]:
        if path == "/profiles/profile-deleted/relationships/certificates":
            raise AppStoreConnectError(
                "App Store Connect request failed with HTTP 404: "
                "The specified resource does not exist - There is no resource "
                "of type 'profiles' with id 'profile-deleted'"
            )
        if path == "/profiles/profile-existing/relationships/certificates":
            return {
                "data": [
                    {
                        "type": "certificates",
                        "id": "cert-profile-existing",
                    }
                ]
            }
        raise AssertionError(f"Unexpected GET: {path} {query}")

    def get_collection(
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[dict[str, Any]]:
        if path == "/bundleIds/bundle-app.peyton.sunclub/profiles":
            return [
                existing_profile("profile-deleted", days=60),
                existing_profile("profile-existing", days=30),
            ]
        raise AssertionError(f"Unexpected collection: {path} {query}")

    client.get = get  # type: ignore[method-assign]
    client.get_collection = get_collection  # type: ignore[method-assign]

    certificate_ids = find_reusable_certificate_ids(
        client, "bundle-app.peyton.sunclub", APP_STORE_PROFILE_TYPE
    )

    assert certificate_ids == ["cert-profile-existing"]


def test_find_bundle_id_uses_exact_identifier_match() -> None:
    client = FakeProfilesClient()

    def get_collection(
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[dict[str, Any]]:
        assert path == "/bundleIds"
        return [
            bundle_id("bundle-app", "app.peyton.sunclub"),
            bundle_id("bundle-widget", "app.peyton.sunclub.widgets"),
            bundle_id("bundle-watch", "app.peyton.sunclub.watch"),
        ]

    client.get_collection = get_collection  # type: ignore[method-assign]

    found = find_bundle_id(client, "app.peyton.sunclub")

    assert found["id"] == "bundle-app"


def test_missing_profile_entitlements_reports_missing_app_group() -> None:
    missing = missing_profile_entitlements(
        {"com.apple.security.application-groups": ["group.app.peyton.other"]},
        {"com.apple.security.application-groups": ["group.app.peyton.sunclub"]},
    )

    assert missing == [
        "com.apple.security.application-groups=['group.app.peyton.sunclub']"
    ]


def test_missing_profile_entitlements_accepts_superset_arrays() -> None:
    missing = missing_profile_entitlements(
        {
            "com.apple.security.application-groups": [
                "group.app.peyton.sunclub",
                "group.app.peyton.other",
            ]
        },
        {"com.apple.security.application-groups": ["group.app.peyton.sunclub"]},
    )

    assert missing == []


def write_info_plist(path: Path, bundle_identifier: str, package_type: str) -> None:
    path.mkdir(parents=True)
    with (path / "Info.plist").open("wb") as file:
        plistlib.dump(
            {
                "CFBundleIdentifier": bundle_identifier,
                "CFBundlePackageType": package_type,
            },
            file,
        )


def bundle_id(bundle_id: str, identifier: str) -> dict[str, Any]:
    return {
        "type": "bundleIds",
        "id": bundle_id,
        "attributes": {
            "identifier": identifier,
        },
    }


def existing_profile(profile_id: str, *, days: int = 30) -> dict[str, Any]:
    return {
        "type": "profiles",
        "id": profile_id,
        "attributes": {
            "name": "Existing Sunclub Profile",
            "profileType": APP_STORE_PROFILE_TYPE,
            "profileState": "ACTIVE",
            "expirationDate": future_date(days=days),
            "uuid": f"uuid-{profile_id}",
            "profileContent": profile_content(),
        },
    }


def certificate(certificate_id: str) -> dict[str, Any]:
    return {
        "type": "certificates",
        "id": certificate_id,
        "attributes": {
            "activated": True,
            "certificateType": "DISTRIBUTION",
            "expirationDate": future_date(),
        },
    }


def future_date(*, days: int = 30) -> str:
    return (datetime.now(UTC) + timedelta(days=days)).isoformat().replace("+00:00", "Z")


def profile_content() -> str:
    return base64.b64encode(b"mobileprovision").decode("ascii")
