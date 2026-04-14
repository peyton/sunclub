from __future__ import annotations

import base64
from collections.abc import Mapping, Sequence
from datetime import UTC, datetime, timedelta
import plistlib
from pathlib import Path
from typing import Any

from scripts.appstore.provisioning_profiles import (
    APP_STORE_PROFILE_TYPE,
    ArchivedBundle,
    collect_archived_bundles,
    ensure_profiles,
    find_bundle_id,
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
            assert query["filter[profileType]"] == APP_STORE_PROFILE_TYPE
            return [existing_profile("profile-existing")]
        if path.startswith("/bundleIds/") and path.endswith("/profiles"):
            assert query["filter[profileType]"] == APP_STORE_PROFILE_TYPE
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
    assert posted_data["attributes"] == {
        "name": "Sunclub App Store app.peyton.sunclub.watch.extension",
        "profileType": APP_STORE_PROFILE_TYPE,
    }
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


def existing_profile(profile_id: str) -> dict[str, Any]:
    return {
        "type": "profiles",
        "id": profile_id,
        "attributes": {
            "name": "Existing Sunclub Profile",
            "profileType": APP_STORE_PROFILE_TYPE,
            "profileState": "ACTIVE",
            "expirationDate": future_date(),
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


def future_date() -> str:
    return (datetime.now(UTC) + timedelta(days=30)).isoformat().replace("+00:00", "Z")


def profile_content() -> str:
    return base64.b64encode(b"mobileprovision").decode("ascii")
