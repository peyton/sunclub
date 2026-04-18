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
    profile_certificate_ids,
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
        if path == "/profiles/profile-existing/certificates":
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

    def patch(self, path: str, body: Mapping[str, Any]) -> dict[str, Any]:
        raise AssertionError(f"Unexpected PATCH: {path} {body}")


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
    tmp_path: Path, monkeypatch: Any
) -> None:
    client = FakeProfilesClient()
    original_get_collection = client.get_collection

    def get_collection_without_global_certificates(
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[dict[str, Any]]:
        if path == "/certificates":
            raise AssertionError("Global certificate lookup should not be required")
        return original_get_collection(path, query)

    client.get_collection = get_collection_without_global_certificates  # type: ignore[method-assign]
    monkeypatch.setattr(
        provisioning_profiles,
        "read_bundle_profile_entitlements",
        lambda _path: {},
    )
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
        {"type": "certificates", "id": "cert-profile-existing"}
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


def test_ensure_profiles_registers_missing_bundle_id_with_app_group_capability(
    tmp_path: Path, monkeypatch: Any
) -> None:
    client = FakeProfilesClient()
    created_posts: list[tuple[str, dict[str, Any]]] = []
    required = {"com.apple.security.application-groups": ["group.app.peyton.sunclub"]}

    def get_collection(
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[dict[str, Any]]:
        query = query or {}
        if path == "/bundleIds":
            assert query["filter[identifier]"] == "app.peyton.sunclub.watch.widgets"
            return []
        if path == "/bundleIds/bundle-watch-widgets/bundleIdCapabilities":
            return []
        if path == "/bundleIds/bundle-watch-widgets/profiles":
            return []
        if path == "/certificates":
            return [certificate("cert-distribution")]
        raise AssertionError(f"Unexpected collection: {path} {query}")

    def post(path: str, body: Mapping[str, Any]) -> dict[str, Any]:
        created_posts.append((path, dict(body)))
        if path == "/bundleIds":
            return {
                "data": bundle_id(
                    "bundle-watch-widgets",
                    "app.peyton.sunclub.watch.widgets",
                )
            }
        if path == "/bundleIdCapabilities":
            return {
                "data": {
                    "type": "bundleIdCapabilities",
                    "id": "cap-app-groups",
                    "attributes": body["data"]["attributes"],  # type: ignore[index]
                }
            }
        if path == "/profiles":
            attributes = body["data"]["attributes"]  # type: ignore[index]
            return {
                "data": {
                    "type": "profiles",
                    "id": "profile-watch-widgets",
                    "attributes": {
                        "name": attributes["name"],
                        "profileType": attributes["profileType"],
                        "profileState": "ACTIVE",
                        "expirationDate": future_date(),
                        "uuid": "uuid-watch-widgets",
                        "profileContent": profile_content(),
                    },
                }
            }
        raise AssertionError(f"Unexpected POST: {path} {body}")

    client.get_collection = get_collection  # type: ignore[method-assign]
    client.post = post  # type: ignore[method-assign]
    monkeypatch.setattr(
        provisioning_profiles,
        "read_bundle_profile_entitlements",
        lambda _path: required,
    )
    monkeypatch.setattr(
        provisioning_profiles,
        "profile_entitlements_from_content",
        lambda _client, _profile: required,
    )

    prepared = ensure_profiles(
        client,
        [
            ArchivedBundle(
                path=tmp_path / "WatchWidget.appex",
                relative_path="SunclubWatch.app/PlugIns/WatchWidget.appex",
                bundle_identifier="app.peyton.sunclub.watch.widgets",
                package_type="XPC!",
            )
        ],
        create_missing=True,
        install_directory=None,
    )

    assert [profile.created for profile in prepared] == [True]
    assert [path for path, _body in created_posts] == [
        "/bundleIds",
        "/bundleIdCapabilities",
        "/profiles",
    ]
    assert created_posts[0][1]["data"]["attributes"] == {
        "identifier": "app.peyton.sunclub.watch.widgets",
        "name": "Sunclub Watch Widgets",
        "platform": "IOS",
    }
    assert created_posts[1][1]["data"]["attributes"] == {
        "capabilityType": "APP_GROUPS",
    }
    assert created_posts[1][1]["data"]["relationships"]["bundleId"]["data"] == {
        "type": "bundleIds",
        "id": "bundle-watch-widgets",
    }
    assert created_posts[2][1]["data"]["relationships"]["bundleId"]["data"] == {
        "type": "bundleIds",
        "id": "bundle-watch-widgets",
    }


def test_ensure_profiles_creates_one_distribution_certificate_for_missing_profiles(
    tmp_path: Path, monkeypatch: Any
) -> None:
    client = FakeProfilesClient()

    def get_collection(
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[dict[str, Any]]:
        query = query or {}
        if path == "/bundleIds":
            identifier = query["filter[identifier]"]
            return [bundle_id(f"bundle-{identifier}", str(identifier))]
        if path.startswith("/bundleIds/") and path.endswith("/profiles"):
            return []
        if path == "/certificates":
            return []
        raise AssertionError(f"Unexpected collection: {path} {query}")

    created_certificates: list[str] = []

    def create_and_install_distribution_certificate(
        certificate_client: FakeProfilesClient,
    ) -> dict[str, Any]:
        assert certificate_client is client
        created_certificates.append("cert-created")
        return certificate("cert-created")

    client.get_collection = get_collection  # type: ignore[method-assign]
    monkeypatch.setattr(
        provisioning_profiles,
        "read_bundle_profile_entitlements",
        lambda _path: {},
    )
    monkeypatch.setattr(
        provisioning_profiles,
        "create_and_install_distribution_certificate",
        create_and_install_distribution_certificate,
    )
    bundles = [
        ArchivedBundle(
            path=tmp_path / "SunclubWatch.app",
            relative_path="Sunclub.app/Watch/SunclubWatch.app",
            bundle_identifier="app.peyton.sunclub.watch",
            package_type="APPL",
        ),
        ArchivedBundle(
            path=tmp_path / "SunclubWatchExtension.appex",
            relative_path="Sunclub.app/Watch/SunclubWatch.app/PlugIns/Ext.appex",
            bundle_identifier="app.peyton.sunclub.watch.extension",
            package_type="XPC!",
        ),
    ]

    prepared = ensure_profiles(
        client,
        bundles,
        create_missing=True,
        install_directory=None,
    )

    assert [profile.created for profile in prepared] == [True, True]
    assert created_certificates == ["cert-created"]
    assert len(client.posts) == 2
    for post in client.posts:
        assert post["data"]["relationships"]["certificates"]["data"] == [
            {"type": "certificates", "id": "cert-created"}
        ]


def test_create_distribution_certificate_posts_pem_csr() -> None:
    client = FakeProfilesClient()
    posts: list[dict[str, Any]] = []
    csr_content = (
        "-----BEGIN CERTIFICATE REQUEST-----\n"
        "abc123\n"
        "-----END CERTIFICATE REQUEST-----\n"
    )

    def post(path: str, body: Mapping[str, Any]) -> dict[str, Any]:
        assert path == "/certificates"
        posts.append(dict(body))
        created = certificate("cert-created")
        created["attributes"]["certificateContent"] = base64.b64encode(
            b"certificate"
        ).decode("ascii")
        return {"data": created}

    client.post = post  # type: ignore[method-assign]

    created = provisioning_profiles.create_distribution_certificate(
        client, "DISTRIBUTION", csr_content
    )

    assert created["id"] == "cert-created"
    assert posts == [
        {
            "data": {
                "type": "certificates",
                "attributes": {
                    "certificateType": "DISTRIBUTION",
                    "csrContent": csr_content,
                },
            }
        }
    ]


def test_find_reusable_certificate_ids_skips_deleted_profile_candidates() -> None:
    client = FakeProfilesClient()

    def get(
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> dict[str, Any]:
        if path == "/profiles/profile-deleted/certificates":
            raise AppStoreConnectError(
                "App Store Connect request failed with HTTP 404: "
                "The specified resource does not exist - There is no resource "
                "of type 'profiles' with id 'profile-deleted'"
            )
        if path == "/profiles/profile-deleted":
            raise AppStoreConnectError(
                "App Store Connect request failed with HTTP 404: "
                "The specified resource does not exist - There is no resource "
                "of type 'profiles' with id 'profile-deleted'"
            )
        if path == "/profiles/profile-existing":
            return {"data": existing_profile("profile-existing")}
        if path == "/profiles/profile-existing/certificates":
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


def test_profile_certificate_ids_reads_included_profile_certificates() -> None:
    client = FakeProfilesClient()

    def get(
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> dict[str, Any]:
        if path == "/profiles/profile-existing":
            assert query == {
                "include": "certificates",
                "fields[profiles]": "certificates",
                "fields[certificates]": "activated,certificateType,expirationDate",
            }
            profile = existing_profile("profile-existing")
            profile["relationships"] = {
                "certificates": {
                    "data": [
                        {
                            "type": "certificates",
                            "id": "cert-included",
                        }
                    ]
                }
            }
            return {
                "data": profile,
                "included": [certificate("cert-included")],
            }
        if path == "/profiles/profile-existing/certificates":
            raise AssertionError("Included certificates should be used first")
        raise AssertionError(f"Unexpected GET: {path} {query}")

    client.get = get  # type: ignore[method-assign]

    certificate_ids = profile_certificate_ids(
        client,
        {
            "type": "profiles",
            "id": "profile-existing",
            "attributes": {
                "profileType": APP_STORE_PROFILE_TYPE,
                "profileState": "ACTIVE",
                "expirationDate": future_date(),
            },
        },
    )

    assert certificate_ids == ["cert-included"]


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


def test_missing_profile_entitlements_accepts_wildcard_profile_value() -> None:
    missing = missing_profile_entitlements(
        {"com.apple.developer.icloud-services": "*"},
        {"com.apple.developer.icloud-services": ["CloudKit"]},
    )

    assert missing == []


def test_missing_profile_entitlements_does_not_accept_wildcard_app_groups() -> None:
    missing = missing_profile_entitlements(
        {"com.apple.security.application-groups": "*"},
        {"com.apple.security.application-groups": ["group.app.peyton.sunclub"]},
    )

    assert missing == [
        "com.apple.security.application-groups=['group.app.peyton.sunclub']"
    ]


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
