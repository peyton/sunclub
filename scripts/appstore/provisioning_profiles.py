from __future__ import annotations

import argparse
import base64
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
import json
import plistlib
from pathlib import Path
from typing import Any, Protocol

from scripts.appstore.connect_api import (
    AppStoreConnectClient,
    AppStoreConnectError,
    JsonObject,
)


APP_STORE_PROFILE_TYPE = "IOS_APP_STORE"
DISTRIBUTION_CERTIFICATE_TYPES = ("DISTRIBUTION", "IOS_DISTRIBUTION")


class ProfilesClient(Protocol):
    def get(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> JsonObject: ...

    def get_collection(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[JsonObject]: ...

    def post(self, path: str, body: Mapping[str, Any]) -> JsonObject: ...


@dataclass(frozen=True)
class ArchivedBundle:
    path: Path
    relative_path: str
    bundle_identifier: str
    package_type: str
    profile_type: str = APP_STORE_PROFILE_TYPE


@dataclass(frozen=True)
class PreparedProfile:
    bundle: ArchivedBundle
    profile: JsonObject
    created: bool
    installed_path: Path | None


def archive_app_path(archive_path: Path, app_name: str | None = None) -> Path:
    if app_name:
        return archive_path / "Products" / "Applications" / f"{app_name}.app"

    info_path = archive_path / "Info.plist"
    if not info_path.is_file():
        raise AppStoreConnectError(f"Archive Info.plist not found: {info_path}")
    info = read_plist(info_path)
    application_properties = info.get("ApplicationProperties")
    if not isinstance(application_properties, dict):
        raise AppStoreConnectError(
            f"Archive Info.plist is missing ApplicationProperties: {info_path}"
        )
    application_path = application_properties.get("ApplicationPath")
    if not isinstance(application_path, str) or not application_path:
        raise AppStoreConnectError(
            f"Archive Info.plist is missing ApplicationPath: {info_path}"
        )
    return archive_path / "Products" / application_path


def collect_archived_bundles(
    archive_path: Path, app_name: str | None = None
) -> list[ArchivedBundle]:
    app_path = archive_app_path(archive_path, app_name)
    if not app_path.is_dir():
        raise AppStoreConnectError(f"Archived app not found: {app_path}")

    candidates = [app_path]
    candidates.extend(sorted(app_path.rglob("*.app")))
    candidates.extend(sorted(app_path.rglob("*.appex")))

    bundles: list[ArchivedBundle] = []
    seen: set[Path] = set()
    for candidate in candidates:
        resolved = candidate.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        info = read_plist(candidate / "Info.plist")
        bundle_identifier = string_value(info, "CFBundleIdentifier", candidate)
        package_type = string_value(info, "CFBundlePackageType", candidate)
        bundles.append(
            ArchivedBundle(
                path=candidate,
                relative_path=str(candidate.relative_to(app_path.parent)),
                bundle_identifier=bundle_identifier,
                package_type=package_type,
            )
        )

    return bundles


def ensure_profiles(
    client: ProfilesClient,
    bundles: Sequence[ArchivedBundle],
    *,
    create_missing: bool,
    install_directory: Path | None,
) -> list[PreparedProfile]:
    prepared: list[PreparedProfile] = []
    certificate: JsonObject | None = None

    for bundle in bundles:
        bundle_id = find_bundle_id(client, bundle.bundle_identifier)
        profile = find_active_profile(client, bundle_id["id"], bundle.profile_type)
        created = False
        if profile is None:
            if not create_missing:
                raise AppStoreConnectError(
                    "No active App Store provisioning profile found for "
                    f"{bundle.bundle_identifier}"
                )
            if certificate is None:
                certificate = find_distribution_certificate(client)
            profile = create_profile(client, bundle, bundle_id["id"], certificate["id"])
            created = True

        installed_path = None
        if install_directory is not None:
            installed_path = install_profile(client, profile, install_directory)

        prepared.append(
            PreparedProfile(
                bundle=bundle,
                profile=profile,
                created=created,
                installed_path=installed_path,
            )
        )

    return prepared


def find_bundle_id(client: ProfilesClient, identifier: str) -> JsonObject:
    matches = client.get_collection(
        "/bundleIds",
        {
            "filter[identifier]": identifier,
            "limit": 200,
        },
    )
    exact_matches = [
        bundle_id
        for bundle_id in matches
        if bundle_id_identifier(bundle_id) == identifier
    ]
    if not exact_matches:
        raise AppStoreConnectError(
            "App Store Connect bundle ID is missing for "
            f"{identifier}. Open the Apple Developer portal or Xcode once to "
            "register this bundle ID before cutting the release."
        )
    if len(exact_matches) > 1:
        raise AppStoreConnectError(
            f"App Store Connect returned multiple bundle IDs for {identifier}."
        )
    return exact_matches[0]


def bundle_id_identifier(bundle_id: JsonObject) -> str | None:
    attributes = bundle_id.get("attributes")
    if not isinstance(attributes, dict):
        return None
    identifier = attributes.get("identifier")
    if not isinstance(identifier, str):
        return None
    return identifier


def find_active_profile(
    client: ProfilesClient, bundle_id: str, profile_type: str
) -> JsonObject | None:
    profiles = client.get_collection(
        f"/bundleIds/{bundle_id}/profiles",
        {
            "filter[profileType]": profile_type,
            "limit": 200,
        },
    )
    active_profiles = [profile for profile in profiles if profile_is_active(profile)]
    if not active_profiles:
        return None
    return max(active_profiles, key=profile_expiration)


def find_distribution_certificate(client: ProfilesClient) -> JsonObject:
    certificates_by_id: dict[str, JsonObject] = {}
    for certificate_type in DISTRIBUTION_CERTIFICATE_TYPES:
        for certificate in client.get_collection(
            "/certificates",
            {
                "filter[certificateType]": certificate_type,
                "limit": 200,
            },
        ):
            certificates_by_id[certificate["id"]] = certificate

    certificates = [
        certificate
        for certificate in certificates_by_id.values()
        if certificate_is_usable(certificate)
    ]
    if not certificates:
        raise AppStoreConnectError(
            "No active Apple distribution certificate is available to create "
            "App Store provisioning profiles."
        )
    return max(certificates, key=certificate_expiration)


def create_profile(
    client: ProfilesClient,
    bundle: ArchivedBundle,
    bundle_id: str,
    certificate_id: str,
) -> JsonObject:
    name = f"Sunclub App Store {bundle.bundle_identifier}"
    response = client.post(
        "/profiles",
        {
            "data": {
                "type": "profiles",
                "attributes": {
                    "name": name,
                    "profileType": bundle.profile_type,
                },
                "relationships": {
                    "bundleId": {
                        "data": {
                            "type": "bundleIds",
                            "id": bundle_id,
                        }
                    },
                    "certificates": {
                        "data": [
                            {
                                "type": "certificates",
                                "id": certificate_id,
                            }
                        ]
                    },
                },
            }
        },
    )
    data = response.get("data")
    if not isinstance(data, dict):
        raise AppStoreConnectError(
            f"App Store Connect did not return a profile for {bundle.bundle_identifier}."
        )
    return data


def install_profile(
    client: ProfilesClient, profile: JsonObject, install_directory: Path
) -> Path:
    profile = profile_with_content(client, profile)
    attributes = profile_attributes(profile)
    content = attributes.get("profileContent")
    if not isinstance(content, str) or not content:
        profile_name = attributes.get("name", profile.get("id", "unknown"))
        raise AppStoreConnectError(
            f"App Store Connect profile {profile_name} has no downloadable content."
        )

    try:
        decoded = base64.b64decode(content, validate=True)
    except ValueError as error:
        raise AppStoreConnectError(
            f"App Store Connect profile {profile.get('id')} content is not base64."
        ) from error

    uuid = attributes.get("uuid")
    filename = (
        f"{uuid if isinstance(uuid, str) and uuid else profile['id']}.mobileprovision"
    )
    install_directory = install_directory.expanduser()
    install_directory.mkdir(parents=True, exist_ok=True)
    destination = install_directory / filename
    destination.write_bytes(decoded)
    return destination


def profile_with_content(client: ProfilesClient, profile: JsonObject) -> JsonObject:
    if isinstance(profile_attributes(profile).get("profileContent"), str):
        return profile
    fetched = client.get(f"/profiles/{profile['id']}")
    data = fetched.get("data")
    if not isinstance(data, dict):
        raise AppStoreConnectError(
            f"Could not fetch profile content for {profile.get('id')}."
        )
    return data


def profile_is_active(profile: JsonObject) -> bool:
    attributes = profile_attributes(profile)
    if attributes.get("profileState") not in (None, "ACTIVE"):
        return False
    return profile_expiration(profile) > datetime.now(UTC)


def certificate_is_usable(certificate: JsonObject) -> bool:
    attributes = profile_attributes(certificate)
    if attributes.get("activated") is False:
        return False
    return certificate_expiration(certificate) > datetime.now(UTC)


def profile_expiration(profile: JsonObject) -> datetime:
    value = profile_attributes(profile).get("expirationDate")
    if not isinstance(value, str):
        return datetime.min.replace(tzinfo=UTC)
    return parse_datetime(value)


def certificate_expiration(certificate: JsonObject) -> datetime:
    value = profile_attributes(certificate).get("expirationDate")
    if not isinstance(value, str):
        return datetime.min.replace(tzinfo=UTC)
    return parse_datetime(value)


def parse_datetime(value: str) -> datetime:
    normalized = value.removesuffix("Z") + "+00:00" if value.endswith("Z") else value
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=UTC)
    return parsed.astimezone(UTC)


def profile_attributes(resource: JsonObject) -> JsonObject:
    attributes = resource.get("attributes", {})
    if not isinstance(attributes, dict):
        return {}
    return attributes


def read_plist(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise AppStoreConnectError(f"Info.plist not found: {path}")
    with path.open("rb") as file:
        payload = plistlib.load(file)
    if not isinstance(payload, dict):
        raise AppStoreConnectError(f"Info.plist is not a dictionary: {path}")
    return payload


def string_value(info: Mapping[str, Any], key: str, bundle_path: Path) -> str:
    value = info.get(key)
    if not isinstance(value, str) or not value:
        raise AppStoreConnectError(f"{bundle_path} is missing {key} in Info.plist.")
    return value


def write_diagnostics(path: Path, profiles: Sequence[PreparedProfile]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            [
                {
                    "bundleIdentifier": profile.bundle.bundle_identifier,
                    "bundlePath": profile.bundle.relative_path,
                    "packageType": profile.bundle.package_type,
                    "profileId": profile.profile.get("id"),
                    "profileName": profile_attributes(profile.profile).get("name"),
                    "profileType": profile.bundle.profile_type,
                    "profileState": profile_attributes(profile.profile).get(
                        "profileState"
                    ),
                    "profileUuid": profile_attributes(profile.profile).get("uuid"),
                    "profileExpirationDate": profile_attributes(profile.profile).get(
                        "expirationDate"
                    ),
                    "created": profile.created,
                    "installedPath": str(profile.installed_path)
                    if profile.installed_path
                    else None,
                }
                for profile in profiles
            ],
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Ensure App Store provisioning profiles exist for archived bundles."
    )
    parser.add_argument("--archive-path", type=Path, required=True)
    parser.add_argument("--app-name")
    parser.add_argument("--create-missing", action="store_true")
    parser.add_argument("--install", action="store_true")
    parser.add_argument(
        "--install-directory",
        type=Path,
        default=Path("~/Library/MobileDevice/Provisioning Profiles"),
    )
    parser.add_argument("--diagnostics", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    bundles = collect_archived_bundles(args.archive_path, args.app_name)
    if not bundles:
        raise AppStoreConnectError(
            f"No app bundles were found in archive: {args.archive_path}"
        )

    install_directory = args.install_directory if args.install else None
    client = AppStoreConnectClient.from_env()
    prepared = ensure_profiles(
        client,
        bundles,
        create_missing=args.create_missing,
        install_directory=install_directory,
    )

    for profile in prepared:
        action = "created" if profile.created else "found"
        profile_name = profile_attributes(profile.profile).get(
            "name", profile.profile["id"]
        )
        print(f"{action}: {profile.bundle.bundle_identifier} -> {profile_name}")

    if args.diagnostics is not None:
        write_diagnostics(args.diagnostics, prepared)


if __name__ == "__main__":
    main()
