from __future__ import annotations

import argparse
import base64
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
import json
import os
import plistlib
from pathlib import Path
import secrets
import shlex
import subprocess
import tempfile
from typing import Any, Protocol

from scripts.appstore.connect_api import (
    AppStoreConnectClient,
    AppStoreConnectError,
    JsonObject,
)


APP_STORE_PROFILE_TYPE = "IOS_APP_STORE"
DISTRIBUTION_CERTIFICATE_TYPES = ("DISTRIBUTION", "IOS_DISTRIBUTION")
PROFILE_BACKED_ENTITLEMENTS = (
    "aps-environment",
    "com.apple.developer.healthkit",
    "com.apple.developer.icloud-container-identifiers",
    "com.apple.developer.icloud-services",
    "com.apple.developer.weatherkit",
    "com.apple.security.application-groups",
)
WILDCARD_LIST_ENTITLEMENTS = {"com.apple.developer.icloud-services"}


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

    def patch(self, path: str, body: Mapping[str, Any]) -> JsonObject: ...


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
    distribution_certificate_ids: list[str] | None = None
    reusable_certificate_ids_by_profile_type: dict[str, list[str]] = {}
    bundle_ids: dict[str, JsonObject] = {}
    required_entitlements_by_bundle: dict[str, JsonObject] = {}

    for bundle in bundles:
        required_entitlements = read_bundle_profile_entitlements(bundle.path)
        required_entitlements_by_bundle[bundle.bundle_identifier] = (
            required_entitlements
        )
        bundle_id = ensure_bundle_id(
            client,
            bundle,
            required_entitlements=required_entitlements,
            create_missing=create_missing,
        )
        bundle_ids[bundle.bundle_identifier] = bundle_id
        reusable_certificate_ids_by_profile_type[bundle.profile_type] = (
            append_unique_certificate_ids(
                reusable_certificate_ids_by_profile_type.get(bundle.profile_type, []),
                find_reusable_certificate_ids(
                    client, bundle_id["id"], bundle.profile_type
                ),
            )
        )

    for bundle in bundles:
        required_entitlements = required_entitlements_by_bundle[
            bundle.bundle_identifier
        ]
        bundle_id = bundle_ids[bundle.bundle_identifier]
        profile = find_active_profile(
            client,
            bundle_id["id"],
            bundle.profile_type,
            required_entitlements=required_entitlements,
        )
        created = False
        if profile is None:
            if not create_missing:
                raise AppStoreConnectError(
                    "No compatible active App Store provisioning profile found for "
                    f"{bundle.bundle_identifier}"
                )
            certificate_ids = find_reusable_certificate_ids(
                client, bundle_id["id"], bundle.profile_type
            )
            if not certificate_ids:
                certificate_ids = reusable_certificate_ids_by_profile_type.get(
                    bundle.profile_type, []
                )
            if not certificate_ids:
                if distribution_certificate_ids is None:
                    distribution_certificate_ids = [
                        find_or_create_distribution_certificate(client)["id"]
                    ]
                certificate_ids = distribution_certificate_ids
            profile = create_profile(client, bundle, bundle_id["id"], certificate_ids)
            created = True
            validate_profile_entitlements(
                client, profile, bundle, required_entitlements
            )
            reusable_certificate_ids_by_profile_type[bundle.profile_type] = (
                append_unique_certificate_ids(
                    reusable_certificate_ids_by_profile_type.get(
                        bundle.profile_type, []
                    ),
                    certificate_ids,
                )
            )
        else:
            reusable_certificate_ids_by_profile_type[bundle.profile_type] = (
                append_unique_certificate_ids(
                    reusable_certificate_ids_by_profile_type.get(
                        bundle.profile_type, []
                    ),
                    profile_certificate_ids(client, profile),
                )
            )

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


def ensure_bundle_id(
    client: ProfilesClient,
    bundle: ArchivedBundle,
    *,
    required_entitlements: Mapping[str, Any],
    create_missing: bool,
) -> JsonObject:
    bundle_id = find_bundle_id_or_none(client, bundle.bundle_identifier)
    if bundle_id is None:
        if not create_missing:
            raise_missing_bundle_id(bundle.bundle_identifier)
        bundle_id = create_bundle_id(client, bundle)
        ensure_bundle_id_capabilities(client, bundle_id, required_entitlements)
    return bundle_id


def append_unique_certificate_ids(
    existing: Sequence[str], additional: Sequence[str]
) -> list[str]:
    merged = list(existing)
    seen = set(merged)
    for certificate_id in additional:
        if certificate_id in seen:
            continue
        merged.append(certificate_id)
        seen.add(certificate_id)
    return merged


def find_bundle_id(client: ProfilesClient, identifier: str) -> JsonObject:
    match = find_bundle_id_or_none(client, identifier)
    if match is None:
        raise_missing_bundle_id(identifier)
    return match


def find_bundle_id_or_none(
    client: ProfilesClient, identifier: str
) -> JsonObject | None:
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
        return None
    if len(exact_matches) > 1:
        raise AppStoreConnectError(
            f"App Store Connect returned multiple bundle IDs for {identifier}."
        )
    return exact_matches[0]


def raise_missing_bundle_id(identifier: str) -> None:
    raise AppStoreConnectError(
        "App Store Connect bundle ID is missing for "
        f"{identifier}. Open the Apple Developer portal or Xcode once to "
        "register this bundle ID before cutting the release."
    )


def create_bundle_id(client: ProfilesClient, bundle: ArchivedBundle) -> JsonObject:
    response = client.post(
        "/bundleIds",
        {
            "data": {
                "type": "bundleIds",
                "attributes": {
                    "identifier": bundle.bundle_identifier,
                    "name": app_id_name(bundle.bundle_identifier),
                    "platform": "IOS",
                },
            }
        },
    )
    data = response.get("data")
    if not isinstance(data, dict):
        raise AppStoreConnectError(
            f"App Store Connect did not return a bundle ID for {bundle.bundle_identifier}."
        )
    return data


def app_id_name(identifier: str) -> str:
    suffix = identifier.removeprefix("app.peyton.sunclub").strip(".")
    if not suffix:
        return "Sunclub"
    return f"Sunclub {suffix.replace('.', ' ').title()}"


def ensure_bundle_id_capabilities(
    client: ProfilesClient,
    bundle_id: JsonObject,
    required_entitlements: Mapping[str, Any],
) -> None:
    required_capabilities = required_capabilities_from_entitlements(
        required_entitlements
    )
    if not required_capabilities:
        return

    bundle_id_value = str(bundle_id["id"])
    existing = {
        str(profile_attributes(capability).get("capabilityType")): capability
        for capability in client.get_collection(
            f"/bundleIds/{bundle_id_value}/bundleIdCapabilities"
        )
    }

    for capability in required_capabilities:
        capability_type = str(capability["capabilityType"])
        existing_capability = existing.get(capability_type)
        if existing_capability is None:
            client.post(
                "/bundleIdCapabilities",
                create_capability_body(bundle_id_value, capability),
            )
            continue
        if capability_satisfies(existing_capability, capability):
            continue
        client.patch(
            f"/bundleIdCapabilities/{existing_capability['id']}",
            update_capability_body(str(existing_capability["id"]), capability),
        )


def required_capabilities_from_entitlements(
    required_entitlements: Mapping[str, Any],
) -> list[JsonObject]:
    capabilities: list[JsonObject] = []
    app_groups = string_list_entitlement(
        required_entitlements.get("com.apple.security.application-groups")
    )
    if app_groups:
        capabilities.append(
            {
                "capabilityType": "APP_GROUPS",
            }
        )
    if required_entitlements.get("aps-environment"):
        capabilities.append({"capabilityType": "PUSH_NOTIFICATIONS"})
    if required_entitlements.get("com.apple.developer.healthkit") is True:
        capabilities.append({"capabilityType": "HEALTHKIT"})
    if required_entitlements.get("com.apple.developer.weatherkit") is True:
        capabilities.append({"capabilityType": "WEATHERKIT"})
    if required_entitlements.get("com.apple.developer.icloud-container-identifiers"):
        capabilities.append(
            {
                "capabilityType": "ICLOUD",
                "settings": [
                    {
                        "key": "ICLOUD_VERSION",
                        "options": [{"key": "XCODE_6", "enabled": True}],
                    }
                ],
            }
        )
    return capabilities


def string_list_entitlement(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [item for item in value if isinstance(item, str) and item]
    return []


def create_capability_body(
    bundle_id: str,
    capability: Mapping[str, Any],
) -> JsonObject:
    return {
        "data": {
            "type": "bundleIdCapabilities",
            "attributes": capability_attributes(capability),
            "relationships": {
                "bundleId": {
                    "data": {
                        "type": "bundleIds",
                        "id": bundle_id,
                    }
                }
            },
        }
    }


def update_capability_body(
    capability_id: str,
    capability: Mapping[str, Any],
) -> JsonObject:
    return {
        "data": {
            "type": "bundleIdCapabilities",
            "id": capability_id,
            "attributes": capability_attributes(capability),
        }
    }


def capability_attributes(capability: Mapping[str, Any]) -> JsonObject:
    attributes: JsonObject = {"capabilityType": capability["capabilityType"]}
    settings = capability.get("settings")
    if settings:
        attributes["settings"] = settings
    return attributes


def capability_satisfies(
    actual: JsonObject,
    expected: Mapping[str, Any],
) -> bool:
    if profile_attributes(actual).get("capabilityType") != expected.get(
        "capabilityType"
    ):
        return False
    return all(
        setting_has_option(profile_attributes(actual).get("settings"), setting)
        for setting in expected.get("settings", [])
        if isinstance(setting, dict)
    )


def setting_has_option(
    actual_settings: Any, expected_setting: Mapping[str, Any]
) -> bool:
    expected_key = expected_setting.get("key")
    expected_options = expected_setting.get("options", [])
    if not expected_key or not isinstance(expected_options, list):
        return True
    if not isinstance(actual_settings, list):
        return False

    for actual_setting in actual_settings:
        if not isinstance(actual_setting, dict):
            continue
        if actual_setting.get("key") != expected_key:
            continue
        actual_options = actual_setting.get("options", [])
        if not isinstance(actual_options, list):
            return False
        actual_enabled_keys = {
            str(option.get("key"))
            for option in actual_options
            if isinstance(option, dict) and option.get("enabled", True) is not False
        }
        return all(
            str(option.get("key")) in actual_enabled_keys
            for option in expected_options
            if isinstance(option, dict)
        )
    return False


def bundle_id_identifier(bundle_id: JsonObject) -> str | None:
    attributes = bundle_id.get("attributes")
    if not isinstance(attributes, dict):
        return None
    identifier = attributes.get("identifier")
    if not isinstance(identifier, str):
        return None
    return identifier


def find_active_profile(
    client: ProfilesClient,
    bundle_id: str,
    profile_type: str,
    *,
    required_entitlements: Mapping[str, Any] | None = None,
) -> JsonObject | None:
    profiles = client.get_collection(
        f"/bundleIds/{bundle_id}/profiles",
        {
            "limit": 200,
        },
    )
    required_entitlements = required_entitlements or {}
    active_profiles = [
        profile
        for profile in profiles
        if profile_matches_type(profile, profile_type)
        and profile_is_active(profile)
        and profile_satisfies_entitlements(client, profile, required_entitlements)
    ]
    if not active_profiles:
        return None
    return max(active_profiles, key=profile_expiration)


def profile_matches_type(profile: JsonObject, profile_type: str) -> bool:
    return profile_attributes(profile).get("profileType") == profile_type


def find_reusable_certificate_ids(
    client: ProfilesClient,
    bundle_id: str,
    profile_type: str,
) -> list[str]:
    profiles = client.get_collection(
        f"/bundleIds/{bundle_id}/profiles",
        {
            "limit": 200,
        },
    )
    active_profiles = [
        profile
        for profile in profiles
        if profile_matches_type(profile, profile_type) and profile_is_active(profile)
    ]
    for profile in sorted(active_profiles, key=profile_expiration, reverse=True):
        certificate_ids = profile_certificate_ids(client, profile)
        if certificate_ids:
            return certificate_ids
    return []


def profile_certificate_ids(client: ProfilesClient, profile: JsonObject) -> list[str]:
    certificates = relationship_data(profile, "certificates")
    if certificates:
        return relationship_ids(certificates)

    profile_id = profile.get("id")
    if not isinstance(profile_id, str) or not profile_id:
        return []

    certificate_ids = included_profile_certificate_ids(client, profile_id)
    if certificate_ids:
        return certificate_ids

    try:
        response = client.get(f"/profiles/{profile_id}/certificates")
    except AppStoreConnectError as error_:
        if is_not_found_error(error_):
            return []
        raise
    data = response.get("data")
    if not isinstance(data, list):
        return []
    return relationship_ids(data)


def included_profile_certificate_ids(
    client: ProfilesClient, profile_id: str
) -> list[str]:
    try:
        response = client.get(
            f"/profiles/{profile_id}",
            {
                "include": "certificates",
                "fields[profiles]": "certificates",
                "fields[certificates]": "activated,certificateType,expirationDate",
            },
        )
    except AppStoreConnectError as error_:
        if is_not_found_error(error_):
            return []
        raise

    included = response.get("included")
    if isinstance(included, list):
        certificates = [
            resource
            for resource in included
            if isinstance(resource, dict)
            and resource.get("type") == "certificates"
            and certificate_is_usable(resource)
        ]
        certificate_ids = relationship_ids(certificates)
        if certificate_ids:
            return certificate_ids

    data = response.get("data")
    if isinstance(data, dict):
        return relationship_ids(relationship_data(data, "certificates"))
    return []


def is_not_found_error(error_: AppStoreConnectError) -> bool:
    return "HTTP 404" in str(error_)


def relationship_data(resource: JsonObject, name: str) -> list[JsonObject]:
    relationships = resource.get("relationships")
    if not isinstance(relationships, dict):
        return []
    relationship = relationships.get(name)
    if not isinstance(relationship, dict):
        return []
    data = relationship.get("data")
    if not isinstance(data, list):
        return []
    return [item for item in data if isinstance(item, dict)]


def relationship_ids(resources: Sequence[JsonObject]) -> list[str]:
    return [
        resource_id
        for resource in resources
        if isinstance(resource_id := resource.get("id"), str) and resource_id
    ]


def profile_satisfies_entitlements(
    client: ProfilesClient,
    profile: JsonObject,
    required_entitlements: Mapping[str, Any],
) -> bool:
    if not required_entitlements:
        return True
    profile_entitlements = profile_entitlements_from_content(client, profile)
    missing = missing_profile_entitlements(profile_entitlements, required_entitlements)
    return not missing


def validate_profile_entitlements(
    client: ProfilesClient,
    profile: JsonObject,
    bundle: ArchivedBundle,
    required_entitlements: Mapping[str, Any],
) -> None:
    if not required_entitlements:
        return
    profile_entitlements = profile_entitlements_from_content(client, profile)
    missing = missing_profile_entitlements(profile_entitlements, required_entitlements)
    if not missing:
        return
    profile_name = profile_attributes(profile).get("name", profile.get("id", "unknown"))
    formatted_missing = ", ".join(missing)
    raise AppStoreConnectError(
        f"Provisioning profile {profile_name} for {bundle.bundle_identifier} "
        f"does not cover required archived entitlements: {formatted_missing}."
    )


def missing_profile_entitlements(
    profile_entitlements: Mapping[str, Any],
    required_entitlements: Mapping[str, Any],
) -> list[str]:
    missing: list[str] = []
    for key in PROFILE_BACKED_ENTITLEMENTS:
        if key not in required_entitlements:
            continue
        required_value = required_entitlements[key]
        profile_value = profile_entitlements.get(key)
        if isinstance(required_value, list):
            if profile_value == "*" and key in WILDCARD_LIST_ENTITLEMENTS:
                continue
            profile_values = (
                set(profile_value) if isinstance(profile_value, list) else set()
            )
            missing_values = [
                value for value in required_value if value not in profile_values
            ]
            if missing_values:
                missing.append(f"{key}={missing_values}")
        elif profile_value != required_value:
            missing.append(f"{key}={required_value!r}")
    return missing


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


def find_or_create_distribution_certificate(client: ProfilesClient) -> JsonObject:
    try:
        return find_distribution_certificate(client)
    except AppStoreConnectError as error_:
        if not str(error_).startswith(
            "No active Apple distribution certificate is available"
        ):
            raise
    return create_and_install_distribution_certificate(client)


def create_and_install_distribution_certificate(client: ProfilesClient) -> JsonObject:
    with tempfile.TemporaryDirectory(prefix="sunclub-release-certificate-") as raw_tmp:
        tmp_path = Path(raw_tmp)
        key_path = tmp_path / "distribution.key"
        csr_path = tmp_path / "distribution.csr"
        certificate_path = tmp_path / "distribution.cer"
        certificate_pem_path = tmp_path / "distribution.pem"
        p12_path = tmp_path / "distribution.p12"
        p12_password = secrets.token_urlsafe(32)

        run_command(
            [
                "openssl",
                "req",
                "-new",
                "-newkey",
                "rsa:2048",
                "-nodes",
                "-keyout",
                str(key_path),
                "-out",
                str(csr_path),
                "-subj",
                "/CN=Sunclub Release Signing/",
            ],
            error_prefix="Failed to generate Apple distribution certificate CSR",
        )
        certificate = request_distribution_certificate(client, csr_path)
        write_certificate_content(certificate, certificate_path)
        run_command(
            [
                "openssl",
                "x509",
                "-inform",
                "DER",
                "-in",
                str(certificate_path),
                "-out",
                str(certificate_pem_path),
            ],
            error_prefix="Failed to convert Apple distribution certificate",
        )
        run_command(
            [
                "openssl",
                "pkcs12",
                "-export",
                "-inkey",
                str(key_path),
                "-in",
                str(certificate_pem_path),
                "-out",
                str(p12_path),
                "-passout",
                f"pass:{p12_password}",
                "-name",
                "Apple Distribution: Sunclub Release Signing",
            ],
            error_prefix="Failed to package Apple distribution certificate",
        )
        install_signing_identity(p12_path, p12_password)
        return certificate


def request_distribution_certificate(
    client: ProfilesClient, csr_path: Path
) -> JsonObject:
    csr_content = csr_path.read_text(encoding="utf-8")
    errors: list[str] = []
    for certificate_type in DISTRIBUTION_CERTIFICATE_TYPES:
        try:
            return create_distribution_certificate(
                client, certificate_type, csr_content
            )
        except AppStoreConnectError as error_:
            errors.append(f"{certificate_type}: {error_}")
            if certificate_type == "DISTRIBUTION" and is_certificate_type_error(error_):
                continue
            break

    joined = "; ".join(errors)
    raise AppStoreConnectError(
        "Could not create an Apple distribution certificate for release "
        f"profile generation. {joined}"
    )


def create_distribution_certificate(
    client: ProfilesClient, certificate_type: str, csr_content: str
) -> JsonObject:
    response = client.post(
        "/certificates",
        {
            "data": {
                "type": "certificates",
                "attributes": {
                    "certificateType": certificate_type,
                    "csrContent": csr_content,
                },
            }
        },
    )
    data = response.get("data")
    if not isinstance(data, dict):
        raise AppStoreConnectError(
            "App Store Connect did not return a distribution certificate."
        )
    return data


def is_certificate_type_error(error_: AppStoreConnectError) -> bool:
    message = str(error_).lower()
    return "certificatetype" in message or "certificate type" in message


def write_certificate_content(certificate: JsonObject, destination: Path) -> None:
    content = profile_attributes(certificate).get("certificateContent")
    if not isinstance(content, str) or not content:
        certificate_name = certificate.get("id", "unknown")
        raise AppStoreConnectError(
            f"App Store Connect certificate {certificate_name} has no content."
        )
    try:
        destination.write_bytes(base64.b64decode(content, validate=True))
    except ValueError as error:
        raise AppStoreConnectError(
            f"App Store Connect certificate {certificate.get('id')} content is "
            "not base64."
        ) from error


def install_signing_identity(p12_path: Path, p12_password: str) -> None:
    keychain_root = Path(os.environ.get("RUNNER_TEMP", tempfile.gettempdir()))
    keychain_root = keychain_root / "sunclub-release-keychains"
    keychain_root.mkdir(parents=True, exist_ok=True)
    keychain_password = secrets.token_urlsafe(32)
    keychain_path = (
        keychain_root
        / f"sunclub-release-{datetime.now(UTC).strftime('%Y%m%d%H%M%S')}.keychain-db"
    )
    existing_keychains = current_user_keychains()

    run_command(
        ["security", "create-keychain", "-p", keychain_password, str(keychain_path)],
        error_prefix="Failed to create release signing keychain",
    )
    run_command(
        ["security", "set-keychain-settings", "-lut", "21600", str(keychain_path)],
        error_prefix="Failed to configure release signing keychain",
    )
    run_command(
        ["security", "unlock-keychain", "-p", keychain_password, str(keychain_path)],
        error_prefix="Failed to unlock release signing keychain",
    )
    run_command(
        [
            "security",
            "list-keychains",
            "-d",
            "user",
            "-s",
            str(keychain_path),
            *existing_keychains,
        ],
        error_prefix="Failed to add release signing keychain to search list",
    )
    run_command(
        [
            "security",
            "import",
            str(p12_path),
            "-k",
            str(keychain_path),
            "-P",
            p12_password,
            "-T",
            "/usr/bin/codesign",
            "-T",
            "/usr/bin/security",
            "-T",
            "/usr/bin/productbuild",
            "-T",
            "/usr/bin/xcodebuild",
        ],
        error_prefix="Failed to import release signing identity",
    )
    run_command(
        [
            "security",
            "set-key-partition-list",
            "-S",
            "apple-tool:,apple:,codesign:",
            "-s",
            "-k",
            keychain_password,
            str(keychain_path),
        ],
        error_prefix="Failed to authorize release signing identity",
    )
    identity_output = run_command(
        ["security", "find-identity", "-v", "-p", "codesigning", str(keychain_path)],
        error_prefix="Failed to verify release signing identity",
    )
    if "0 valid identities found" in identity_output:
        raise AppStoreConnectError(
            "Imported Apple distribution certificate did not create a valid "
            "code-signing identity."
        )


def current_user_keychains() -> list[str]:
    output = run_command(
        ["security", "list-keychains", "-d", "user"],
        error_prefix="Failed to read user keychain search list",
    )
    return shlex.split(output)


def run_command(command: Sequence[str], *, error_prefix: str) -> str:
    try:
        result = subprocess.run(
            list(command),
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as error_:
        raise AppStoreConnectError(
            f"{error_prefix}: {command[0]} is not available."
        ) from error_
    except subprocess.CalledProcessError as error_:
        details = error_.stderr.strip() or error_.stdout.strip()
        if not details:
            details = f"{command[0]} exited with status {error_.returncode}"
        raise AppStoreConnectError(f"{error_prefix}: {details}") from error_
    return result.stdout


def create_profile(
    client: ProfilesClient,
    bundle: ArchivedBundle,
    bundle_id: str,
    certificate_ids: Sequence[str],
) -> JsonObject:
    timestamp = datetime.now(UTC).strftime("%Y%m%d%H%M%S")
    name = f"Sunclub App Store {bundle.bundle_identifier} {timestamp}"
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
                            {"type": "certificates", "id": certificate_id}
                            for certificate_id in certificate_ids
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


def read_bundle_profile_entitlements(bundle_path: Path) -> JsonObject:
    process = subprocess.run(
        ["/usr/bin/codesign", "-d", "--entitlements", ":-", str(bundle_path)],
        check=False,
        capture_output=True,
    )
    if process.returncode != 0 or not process.stdout.strip():
        return {}
    payload = plistlib.loads(process.stdout)
    if not isinstance(payload, dict):
        return {}
    return {
        key: value
        for key, value in payload.items()
        if key in PROFILE_BACKED_ENTITLEMENTS
    }


def profile_entitlements_from_content(
    client: ProfilesClient, profile: JsonObject
) -> JsonObject:
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

    profile_plist = decode_mobileprovision(decoded)
    entitlements = profile_plist.get("Entitlements")
    if not isinstance(entitlements, dict):
        return {}
    return entitlements


def decode_mobileprovision(payload: bytes) -> JsonObject:
    with tempfile.NamedTemporaryFile(suffix=".mobileprovision") as profile_file:
        profile_file.write(payload)
        profile_file.flush()
        process = subprocess.run(
            ["/usr/bin/security", "cms", "-D", "-i", profile_file.name],
            check=False,
            capture_output=True,
        )
    if process.returncode != 0:
        message = process.stderr.decode("utf-8", errors="replace").strip()
        raise AppStoreConnectError(
            "Could not decode provisioning profile content"
            + (f": {message}" if message else ".")
        )
    decoded = plistlib.loads(process.stdout)
    if not isinstance(decoded, dict):
        raise AppStoreConnectError("Provisioning profile content is not a plist.")
    return decoded


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
