from __future__ import annotations

import argparse
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import struct
import sys
import time
from typing import Any, Protocol

from scripts.appstore import manifest as appstore_manifest
from scripts.appstore import validate_metadata
from scripts.appstore.connect_api import (
    AppStoreConnectClient,
    AppStoreConnectError,
    JsonObject,
)
from scripts.tooling.resolve_versions import REPO_ROOT, resolve_versions


PLATFORM = "IOS"
SCREENSHOT_COMPLETE_STATES = {"UPLOAD_COMPLETE", "COMPLETE"}
SCREENSHOT_FAILED_STATE = "FAILED"
BUILD_COMPLETE_STATE = "VALID"
BUILD_FAILED_STATES = {"FAILED", "INVALID"}
EDITABLE_VERSION_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "WAITING_FOR_EXPORT_COMPLIANCE",
    "READY_FOR_REVIEW",
}
READY_REVIEW_SUBMISSION_STATE = "READY_FOR_REVIEW"
CONFIRMATION_ENV = "SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT"
CHECKPOINT_CONFIRMATION_ENV = "SUNCLUB_APP_REVIEW_CHECKPOINT_CONFIRMED"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

SUPPORTED_SCREENSHOT_SIZES = {
    "APP_IPHONE_67": {
        (1260, 2736),
        (2736, 1260),
        (1290, 2796),
        (2796, 1290),
        (1320, 2868),
        (2868, 1320),
    }
}

ACCESSIBILITY_ATTRIBUTE_MAP = {
    "supports_audio_descriptions": "supportsAudioDescriptions",
    "supports_captions": "supportsCaptions",
    "supports_dark_interface": "supportsDarkInterface",
    "supports_differentiate_without_color_alone": (
        "supportsDifferentiateWithoutColorAlone"
    ),
    "supports_larger_text": "supportsLargerText",
    "supports_reduced_motion": "supportsReducedMotion",
    "supports_sufficient_contrast": "supportsSufficientContrast",
    "supports_voice_control": "supportsVoiceControl",
    "supports_voiceover": "supportsVoiceover",
}


class SubmissionClient(Protocol):
    def get(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> JsonObject: ...

    def get_optional(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> JsonObject | None: ...

    def get_collection(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[JsonObject]: ...

    def post(self, path: str, body: Mapping[str, Any]) -> JsonObject: ...

    def patch(self, path: str, body: Mapping[str, Any]) -> JsonObject: ...

    def delete(self, path: str) -> None: ...

    def upload_operations(
        self,
        file_path: Path,
        operations: Sequence[JsonObject],
    ) -> None: ...


@dataclass(frozen=True)
class SubmissionContext:
    marketing_version: str
    build_number: str


@dataclass(frozen=True)
class ScreenshotFile:
    screen_id: str
    path: Path
    display_type: str


@dataclass(frozen=True)
class ScreenshotAsset:
    screen_id: str
    path: Path
    display_type: str
    filename: str
    file_size: int
    checksum: str


@dataclass(frozen=True)
class SubmissionResult:
    app_id: str
    build_id: str
    app_store_version_id: str
    review_submission_id: str
    review_submission_item_id: str


class AppStoreReviewSubmitter:
    def __init__(
        self,
        client: SubmissionClient,
        manifest: Mapping[str, Any],
        context: SubmissionContext,
        *,
        repo_root: Path = REPO_ROOT,
        sleep: Any = time.sleep,
        build_timeout_seconds: int = 1800,
        screenshot_timeout_seconds: int = 600,
        poll_interval_seconds: int = 30,
    ) -> None:
        self.client = client
        self.manifest = manifest
        self.context = context
        self.repo_root = repo_root
        self.sleep = sleep
        self.build_timeout_seconds = build_timeout_seconds
        self.screenshot_timeout_seconds = screenshot_timeout_seconds
        self.poll_interval_seconds = poll_interval_seconds

    def submit(self) -> SubmissionResult:
        app_id = self.lookup_app_id()
        build_id = self.wait_for_valid_build(app_id)
        app_store_version_id = self.ensure_app_store_version(app_id, build_id)
        version_localization_id = self.ensure_version_localization(app_store_version_id)
        self.update_app_info(app_id)
        self.upload_screenshots(version_localization_id)
        self.publish_accessibility_declaration(app_id)
        self.upsert_review_detail(app_store_version_id)
        review_submission_id = self.ensure_review_submission(app_id)
        review_submission_item_id = self.ensure_submission_item(
            review_submission_id,
            app_store_version_id,
        )
        self.finalize_submission(review_submission_id)
        return SubmissionResult(
            app_id=app_id,
            build_id=build_id,
            app_store_version_id=app_store_version_id,
            review_submission_id=review_submission_id,
            review_submission_item_id=review_submission_item_id,
        )

    def lookup_app_id(self) -> str:
        bundle_id = str(self.manifest["app"]["bundle_id"])
        apps = self.client.get_collection(
            "/apps",
            query={"filter[bundleId]": bundle_id, "limit": 1},
        )
        if not apps:
            raise AppStoreConnectError(
                f"No App Store Connect app exists for bundle ID {bundle_id}."
            )
        return resource_id(apps[0])

    def wait_for_valid_build(self, app_id: str) -> str:
        deadline = time.monotonic() + self.build_timeout_seconds
        while True:
            builds = self.client.get_collection(
                "/builds",
                query={
                    "filter[app]": app_id,
                    "filter[version]": self.context.build_number,
                    "filter[preReleaseVersion.version]": (
                        self.context.marketing_version
                    ),
                    "sort": "-uploadedDate",
                    "limit": 10,
                },
            )
            if builds:
                build = builds[0]
                state = resource_attributes(build).get("processingState")
                if state == BUILD_COMPLETE_STATE:
                    build_id = resource_id(build)
                    uses_encryption = bool(
                        self.manifest.get("export_compliance", {}).get(
                            "uses_encryption",
                            False,
                        )
                    )
                    self.client.patch(
                        f"/builds/{build_id}",
                        {
                            "data": {
                                "type": "builds",
                                "id": build_id,
                                "attributes": {
                                    "usesNonExemptEncryption": uses_encryption
                                },
                            }
                        },
                    )
                    return build_id
                if state in BUILD_FAILED_STATES:
                    raise AppStoreConnectError(
                        f"Build {resource_id(build)} processing failed: {state}."
                    )

            if time.monotonic() >= deadline:
                raise AppStoreConnectError(
                    "Timed out waiting for App Store Connect build "
                    f"{self.context.marketing_version} "
                    f"({self.context.build_number}) to become VALID."
                )
            self.sleep(self.poll_interval_seconds)

    def ensure_app_store_version(self, app_id: str, build_id: str) -> str:
        versions = self.client.get_collection(
            f"/apps/{app_id}/appStoreVersions",
            query={
                "filter[platform]": PLATFORM,
                "filter[versionString]": self.context.marketing_version,
                "include": "build",
                "limit": 1,
            },
        )
        release_type = str(self.manifest["submission"].get("release_type", "MANUAL"))
        copyright_value = str(self.manifest["submission"]["copyright"])

        if versions:
            app_store_version_id = resource_id(versions[0])
            state = resource_attributes(versions[0]).get("appStoreState")
            if state not in EDITABLE_VERSION_STATES:
                raise AppStoreConnectError(
                    "App Store version "
                    f"{self.context.marketing_version} is not editable "
                    f"(state: {state})."
                )
            self.client.patch(
                f"/appStoreVersions/{app_store_version_id}",
                {
                    "data": {
                        "type": "appStoreVersions",
                        "id": app_store_version_id,
                        "attributes": {
                            "copyright": copyright_value,
                            "releaseType": release_type,
                            "reviewType": "APP_STORE",
                        },
                    }
                },
            )
        else:
            response = self.client.post(
                "/appStoreVersions",
                {
                    "data": {
                        "type": "appStoreVersions",
                        "attributes": {
                            "platform": PLATFORM,
                            "versionString": self.context.marketing_version,
                            "copyright": copyright_value,
                            "releaseType": release_type,
                            "reviewType": "APP_STORE",
                        },
                        "relationships": {
                            "app": {"data": {"type": "apps", "id": app_id}}
                        },
                    }
                },
            )
            app_store_version_id = resource_id(response["data"])

        self.client.patch(
            f"/appStoreVersions/{app_store_version_id}/relationships/build",
            {"data": {"type": "builds", "id": build_id}},
        )
        return app_store_version_id

    def ensure_version_localization(self, app_store_version_id: str) -> str:
        locale = primary_locale(self.manifest)
        localizations = self.client.get_collection(
            f"/appStoreVersions/{app_store_version_id}/appStoreVersionLocalizations"
        )
        existing = find_by_attribute(localizations, "locale", locale)

        if existing is None:
            response = self.client.post(
                "/appStoreVersionLocalizations",
                {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "attributes": {"locale": locale},
                        "relationships": {
                            "appStoreVersion": {
                                "data": {
                                    "type": "appStoreVersions",
                                    "id": app_store_version_id,
                                }
                            }
                        },
                    }
                },
            )
            localization_id = resource_id(response["data"])
        else:
            localization_id = resource_id(existing)

        locale_payload = self.manifest["localizations"][locale]
        attributes: JsonObject = {
            "description": locale_payload["description"],
            "keywords": ",".join(locale_payload["keywords"]),
            "marketingUrl": self.manifest["urls"]["marketing"]["value"],
            "promotionalText": locale_payload.get("promotional_text"),
            "supportUrl": self.manifest["urls"]["support"]["value"],
            "whatsNew": locale_payload.get("whats_new"),
        }
        self.client.patch(
            f"/appStoreVersionLocalizations/{localization_id}",
            {
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": localization_id,
                    "attributes": attributes,
                }
            },
        )
        return localization_id

    def update_app_info(self, app_id: str) -> None:
        locale = primary_locale(self.manifest)
        app_infos = self.client.get_collection(f"/apps/{app_id}/appInfos", {"limit": 1})
        if not app_infos:
            raise AppStoreConnectError(f"No app info record exists for app {app_id}.")
        app_info_id = resource_id(app_infos[0])
        localizations = self.client.get_collection(
            f"/appInfos/{app_info_id}/appInfoLocalizations"
        )
        existing = find_by_attribute(localizations, "locale", locale)

        attributes: JsonObject = {
            "name": self.manifest["app"]["name"],
            "subtitle": self.manifest["app"]["subtitle"],
            "privacyPolicyUrl": self.manifest["urls"]["privacy_policy"]["value"],
        }

        if existing is None:
            response = self.client.post(
                "/appInfoLocalizations",
                {
                    "data": {
                        "type": "appInfoLocalizations",
                        "attributes": {"locale": locale, **attributes},
                        "relationships": {
                            "appInfo": {"data": {"type": "appInfos", "id": app_info_id}}
                        },
                    }
                },
            )
            localization_id = resource_id(response["data"])
        else:
            localization_id = resource_id(existing)

        self.client.patch(
            f"/appInfoLocalizations/{localization_id}",
            {
                "data": {
                    "type": "appInfoLocalizations",
                    "id": localization_id,
                    "attributes": attributes,
                }
            },
        )
        self.update_app_categories(app_info_id)

    def update_app_categories(self, app_info_id: str) -> None:
        app = self.manifest["app"]
        primary_category = str(app.get("primary_category", "")).strip()
        secondary_category = str(app.get("secondary_category", "")).strip()

        if primary_category:
            self.client.patch(
                f"/appInfos/{app_info_id}/relationships/primaryCategory",
                {"data": {"type": "appCategories", "id": primary_category}},
            )
        if secondary_category:
            self.client.patch(
                f"/appInfos/{app_info_id}/relationships/secondaryCategory",
                {"data": {"type": "appCategories", "id": secondary_category}},
            )

    def upload_screenshots(self, version_localization_id: str) -> None:
        screenshot_files = collect_screenshot_files(self.manifest, self.repo_root)
        display_type = screenshot_files[0].display_type
        screenshot_sets = self.client.get_collection(
            f"/appStoreVersionLocalizations/{version_localization_id}/appScreenshotSets"
        )
        existing_set = find_by_attribute(
            screenshot_sets,
            "screenshotDisplayType",
            display_type,
        )

        if existing_set is None:
            response = self.client.post(
                "/appScreenshotSets",
                {
                    "data": {
                        "type": "appScreenshotSets",
                        "attributes": {"screenshotDisplayType": display_type},
                        "relationships": {
                            "appStoreVersionLocalization": {
                                "data": {
                                    "type": "appStoreVersionLocalizations",
                                    "id": version_localization_id,
                                }
                            }
                        },
                    }
                },
            )
            screenshot_set_id = resource_id(response["data"])
        else:
            screenshot_set_id = resource_id(existing_set)
            for screenshot in self.client.get_collection(
                f"/appScreenshotSets/{screenshot_set_id}/appScreenshots"
            ):
                self.client.delete(f"/appScreenshots/{resource_id(screenshot)}")

        for screenshot_file in screenshot_files:
            asset = read_screenshot_asset(screenshot_file)
            response = self.client.post(
                "/appScreenshots",
                {
                    "data": {
                        "type": "appScreenshots",
                        "attributes": {
                            "fileName": asset.filename,
                            "fileSize": asset.file_size,
                        },
                        "relationships": {
                            "appScreenshotSet": {
                                "data": {
                                    "type": "appScreenshotSets",
                                    "id": screenshot_set_id,
                                }
                            }
                        },
                    }
                },
            )
            screenshot_id = resource_id(response["data"])
            operations = resource_attributes(response["data"]).get(
                "uploadOperations",
                [],
            )
            self.client.upload_operations(asset.path, operations)
            self.client.patch(
                f"/appScreenshots/{screenshot_id}",
                {
                    "data": {
                        "type": "appScreenshots",
                        "id": screenshot_id,
                        "attributes": {
                            "sourceFileChecksum": asset.checksum,
                            "uploaded": True,
                        },
                    }
                },
            )
            self.wait_for_screenshot(screenshot_id)

    def wait_for_screenshot(self, screenshot_id: str) -> None:
        deadline = time.monotonic() + self.screenshot_timeout_seconds
        while True:
            response = self.client.get(f"/appScreenshots/{screenshot_id}")
            state = (
                resource_attributes(response["data"])
                .get("assetDeliveryState", {})
                .get("state")
            )
            if state in SCREENSHOT_COMPLETE_STATES or state is None:
                return
            if state == SCREENSHOT_FAILED_STATE:
                raise AppStoreConnectError(
                    f"Screenshot {screenshot_id} failed App Store processing."
                )
            if time.monotonic() >= deadline:
                raise AppStoreConnectError(
                    f"Timed out waiting for screenshot {screenshot_id} processing."
                )
            self.sleep(self.poll_interval_seconds)

    def publish_accessibility_declaration(self, app_id: str) -> None:
        accessibility = self.manifest.get("accessibility")
        if not isinstance(accessibility, Mapping):
            return
        iphone = accessibility.get("iphone")
        if not isinstance(iphone, Mapping) or iphone.get("ready") is not True:
            return

        attributes = accessibility_attributes(iphone)
        declarations = self.client.get_collection(
            f"/apps/{app_id}/accessibilityDeclarations"
        )
        existing = find_by_attribute(declarations, "deviceFamily", "IPHONE")
        if existing is None:
            response = self.client.post(
                "/accessibilityDeclarations",
                {
                    "data": {
                        "type": "accessibilityDeclarations",
                        "attributes": {"deviceFamily": "IPHONE", **attributes},
                        "relationships": {
                            "app": {"data": {"type": "apps", "id": app_id}}
                        },
                    }
                },
            )
            declaration_id = resource_id(response["data"])
        else:
            declaration_id = resource_id(existing)

        self.client.patch(
            f"/accessibilityDeclarations/{declaration_id}",
            {
                "data": {
                    "type": "accessibilityDeclarations",
                    "id": declaration_id,
                    "attributes": {"publish": True, **attributes},
                }
            },
        )

    def upsert_review_detail(self, app_store_version_id: str) -> str:
        review = self.manifest["review"]
        contact = review["contact"]
        payload = {
            "contactFirstName": contact["first_name"],
            "contactLastName": contact["last_name"],
            "contactPhone": contact["phone"],
            "contactEmail": contact["email"],
            "demoAccountRequired": bool(review.get("demo_account_required", False)),
            "notes": review["notes"],
        }
        if review.get("demo_account_name"):
            payload["demoAccountName"] = review["demo_account_name"]
        if review.get("demo_account_password"):
            payload["demoAccountPassword"] = review["demo_account_password"]

        existing = self.client.get_optional(
            f"/appStoreVersions/{app_store_version_id}/appStoreReviewDetail"
        )
        data = existing.get("data") if existing else None
        if isinstance(data, Mapping):
            detail_id = resource_id(data)
            self.client.patch(
                f"/appStoreReviewDetails/{detail_id}",
                {
                    "data": {
                        "type": "appStoreReviewDetails",
                        "id": detail_id,
                        "attributes": payload,
                    }
                },
            )
            return detail_id

        response = self.client.post(
            "/appStoreReviewDetails",
            {
                "data": {
                    "type": "appStoreReviewDetails",
                    "attributes": payload,
                    "relationships": {
                        "appStoreVersion": {
                            "data": {
                                "type": "appStoreVersions",
                                "id": app_store_version_id,
                            }
                        }
                    },
                }
            },
        )
        return resource_id(response["data"])

    def ensure_review_submission(self, app_id: str) -> str:
        submissions = self.client.get_collection(
            f"/apps/{app_id}/reviewSubmissions",
            query={"filter[state]": READY_REVIEW_SUBMISSION_STATE, "limit": 10},
        )
        if submissions:
            return resource_id(submissions[0])

        response = self.client.post(
            "/reviewSubmissions",
            {
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": PLATFORM},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )
        return resource_id(response["data"])

    def ensure_submission_item(
        self,
        review_submission_id: str,
        app_store_version_id: str,
    ) -> str:
        items = self.client.get_collection(
            f"/reviewSubmissions/{review_submission_id}/items"
        )
        for item in items:
            version = relationship_data(item, "appStoreVersion")
            if version and version.get("id") == app_store_version_id:
                return resource_id(item)
            if version:
                raise AppStoreConnectError(
                    "Draft review submission already contains a different "
                    f"app version ({version.get('id')}). Resolve it before "
                    "submitting this release."
                )

        response = self.client.post(
            "/reviewSubmissionItems",
            {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {
                            "data": {
                                "type": "reviewSubmissions",
                                "id": review_submission_id,
                            }
                        },
                        "appStoreVersion": {
                            "data": {
                                "type": "appStoreVersions",
                                "id": app_store_version_id,
                            }
                        },
                    },
                }
            },
        )
        return resource_id(response["data"])

    def finalize_submission(self, review_submission_id: str) -> None:
        self.client.patch(
            f"/reviewSubmissions/{review_submission_id}",
            {
                "data": {
                    "type": "reviewSubmissions",
                    "id": review_submission_id,
                    "attributes": {"submitted": True},
                }
            },
        )


def primary_locale(manifest: Mapping[str, Any]) -> str:
    return str(manifest["app"]["primary_locale"])


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


def relationship_data(resource: Mapping[str, Any], name: str) -> JsonObject | None:
    relationships = resource.get("relationships", {})
    if not isinstance(relationships, Mapping):
        return None
    relationship = relationships.get(name, {})
    if not isinstance(relationship, Mapping):
        return None
    data = relationship.get("data")
    return data if isinstance(data, dict) else None


def find_by_attribute(
    resources: Sequence[Mapping[str, Any]],
    attribute: str,
    expected: str,
) -> Mapping[str, Any] | None:
    for resource in resources:
        if resource_attributes(resource).get(attribute) == expected:
            return resource
    return None


def collect_screenshot_files(
    manifest: Mapping[str, Any],
    repo_root: Path = REPO_ROOT,
) -> list[ScreenshotFile]:
    screenshots = manifest["assets"]["screenshots"]
    output_dir = repo_root / str(screenshots["output_directory"])
    display_type = str(screenshots["display_type"])
    return [
        ScreenshotFile(
            screen_id=str(screen["id"]),
            path=output_dir / f"{screen['id']}.png",
            display_type=display_type,
        )
        for screen in screenshots["screens"]
    ]


def read_screenshot_asset(screenshot_file: ScreenshotFile) -> ScreenshotAsset:
    data = screenshot_file.path.read_bytes()
    return ScreenshotAsset(
        screen_id=screenshot_file.screen_id,
        path=screenshot_file.path,
        display_type=screenshot_file.display_type,
        filename=screenshot_file.path.name,
        file_size=len(data),
        checksum=hashlib.md5(data, usedforsecurity=False).hexdigest(),
    )


def validate_screenshot_files(
    screenshot_files: Sequence[ScreenshotFile],
) -> list[str]:
    errors: list[str] = []
    for screenshot_file in screenshot_files:
        if not screenshot_file.path.is_file():
            errors.append(f"Missing screenshot: {screenshot_file.path}")
            continue
        try:
            size = png_dimensions(screenshot_file.path)
        except AppStoreConnectError as error:
            errors.append(str(error))
            continue
        accepted_sizes = SUPPORTED_SCREENSHOT_SIZES.get(screenshot_file.display_type)
        if accepted_sizes and size not in accepted_sizes:
            errors.append(
                f"Screenshot {screenshot_file.path} is {size[0]}x{size[1]}, "
                f"which is not accepted for {screenshot_file.display_type}."
            )
    return errors


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or not header.startswith(PNG_SIGNATURE):
        raise AppStoreConnectError(f"Screenshot is not a PNG file: {path}")
    return struct.unpack(">II", header[16:24])


def accessibility_attributes(payload: Mapping[str, Any]) -> JsonObject:
    return {
        apple_key: bool(payload.get(manifest_key, False))
        for manifest_key, apple_key in ACCESSIBILITY_ATTRIBUTE_MAP.items()
    }


def load_manifest(path: Path) -> dict[str, Any]:
    return appstore_manifest.load_resolved_manifest(path)


def write_checkpoint_summary(
    report: appstore_manifest.ResolvedManifest,
    *,
    context: SubmissionContext,
    warnings: Sequence[str],
    output_path: Path | None = None,
) -> Path:
    path = (
        output_path
        or REPO_ROOT / ".build" / "appstore-review-checkpoint" / "summary.md"
    )
    lines = appstore_manifest.redacted_summary_lines(
        report.value,
        missing_env_vars=report.missing_env_vars,
        env_file=report.env_file,
        env_file_loaded=report.env_file_loaded,
        warnings=warnings,
    )
    lines.extend(
        [
            f"- Marketing version: {context.marketing_version}",
            f"- Build number: {context.build_number}",
            "",
            (
                "Exact local confirmation phrase: "
                f"`submit Sunclub {context.marketing_version} "
                f"({context.build_number}) to App Review`"
            ),
            "",
            "No secret values are written here.",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines))
    return path


def local_validation(
    manifest: Mapping[str, Any],
    *,
    repo_root: Path,
    submission_ready: bool,
) -> tuple[list[str], list[str]]:
    errors, warnings = validate_metadata.validate_manifest(
        dict(manifest),
        allow_draft=not submission_ready,
    )
    screenshot_errors = validate_screenshot_files(
        collect_screenshot_files(manifest, repo_root)
    )
    if submission_ready:
        errors.extend(screenshot_errors)
    else:
        warnings.extend(screenshot_errors)
    return errors, warnings


def resolve_submission_context(
    environment: Mapping[str, str] | None = None,
) -> SubmissionContext:
    versions = resolve_versions(environment or os.environ, REPO_ROOT)
    return SubmissionContext(
        marketing_version=versions.marketing_version,
        build_number=versions.build_number,
    )


def dry_run_lines(
    manifest: Mapping[str, Any],
    context: SubmissionContext,
    warnings: Sequence[str],
) -> list[str]:
    screenshot_files = collect_screenshot_files(manifest, REPO_ROOT)
    accessibility = manifest.get("accessibility", {})
    iphone_accessibility = (
        accessibility.get("iphone", {}) if isinstance(accessibility, Mapping) else {}
    )
    accessibility_ready = (
        isinstance(iphone_accessibility, Mapping)
        and iphone_accessibility.get("ready") is True
    )
    planned_steps = [
        "Look up the existing app record by bundle ID.",
        "Poll the uploaded build until App Store Connect marks it VALID.",
        "Reuse or create the iOS App Store version and attach the build.",
        "Patch app info, categories, version localization, support, marketing, and privacy URLs.",
        "Replace the version screenshot set with the generated PNG screenshots.",
    ]
    if accessibility_ready:
        planned_steps.append(
            "Publish the audited iPhone Accessibility Nutrition Label declaration."
        )
    planned_steps.extend(
        [
            "Create or update App Review contact details and notes.",
            "Create or reuse a draft review submission and add this app version.",
            "Submit the draft review submission for App Review.",
        ]
    )
    lines = [
        "App Store review submission dry run",
        f"- Bundle ID: {manifest['app']['bundle_id']}",
        f"- Marketing version: {context.marketing_version}",
        f"- Build number: {context.build_number}",
        f"- Release type: {manifest['submission'].get('release_type', 'MANUAL')}",
        f"- Screenshot display type: {screenshot_files[0].display_type}",
        "",
        "Planned App Store Connect mutations:",
    ]
    lines.extend(
        f"{index}. {step}" for index, step in enumerate(planned_steps, start=1)
    )
    if not accessibility_ready:
        lines.append("")
        lines.append("Accessibility declaration: skipped until marked ready.")
    lines.append("")
    lines.extend(appstore_manifest.redacted_summary_lines(manifest))
    if warnings:
        lines.append("")
        lines.append("Warnings before final submission:")
        lines.extend(f"- {warning}" for warning in warnings)
    return lines


def require_confirmation(
    args: argparse.Namespace, environment: Mapping[str, str]
) -> None:
    submit_confirmed = args.confirm_submit or environment.get(CONFIRMATION_ENV) == "1"
    if not submit_confirmed:
        raise AppStoreConnectError(
            "Final App Review submission requires --confirm-submit or "
            f"{CONFIRMATION_ENV}=1."
        )
    if environment.get(CHECKPOINT_CONFIRMATION_ENV) == "1":
        return
    raise AppStoreConnectError(
        "Final App Review submission requires the checkpoint gate "
        f"{CHECKPOINT_CONFIRMATION_ENV}=1 after reviewing "
        ".build/appstore-review-checkpoint/summary.md."
    )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare and submit Sunclub to App Review."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate local state and print the planned App Store Connect changes.",
    )
    mode.add_argument(
        "--submit",
        action="store_true",
        help="Apply App Store Connect changes and submit for App Review.",
    )
    parser.add_argument(
        "--confirm-submit",
        action="store_true",
        help="Required for --submit unless SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT=1 is set.",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=REPO_ROOT / "scripts/appstore/metadata.json",
    )
    parser.add_argument("--build-timeout-seconds", type=int, default=1800)
    parser.add_argument("--screenshot-timeout-seconds", type=int, default=600)
    parser.add_argument("--poll-interval-seconds", type=int, default=30)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        report = appstore_manifest.load_resolved_manifest_report(args.manifest)
        manifest = report.value
        context = resolve_submission_context(os.environ)
        errors, warnings = local_validation(
            manifest,
            repo_root=REPO_ROOT,
            submission_ready=args.submit,
        )
        if errors:
            print(f"App Store review submission validation failed for {args.manifest}:")
            for error in errors:
                print(f"- ERROR: {error}")
            for warning in warnings:
                print(f"- WARNING: {warning}")
            return 1

        if args.dry_run:
            print("\n".join(dry_run_lines(manifest, context, warnings)))
            return 0

        checkpoint_path = write_checkpoint_summary(
            report,
            context=context,
            warnings=warnings,
        )
        print(f"Review checkpoint written to {checkpoint_path}.")
        print("\n".join(checkpoint_path.read_text().splitlines()))
        require_confirmation(args, os.environ)
        client = AppStoreConnectClient.from_env()
        submitter = AppStoreReviewSubmitter(
            client,
            manifest,
            context,
            build_timeout_seconds=args.build_timeout_seconds,
            screenshot_timeout_seconds=args.screenshot_timeout_seconds,
            poll_interval_seconds=args.poll_interval_seconds,
        )
        result = submitter.submit()
    except (
        AppStoreConnectError,
        OSError,
        json.JSONDecodeError,
        appstore_manifest.ReviewEnvError,
    ) as error:
        print(f"App Store review submission failed: {error}", file=sys.stderr)
        return 1

    print("App Store review submission completed.")
    print(f"- App ID: {result.app_id}")
    print(f"- Build ID: {result.build_id}")
    print(f"- App Store version ID: {result.app_store_version_id}")
    print(f"- Review submission ID: {result.review_submission_id}")
    print(f"- Review submission item ID: {result.review_submission_item_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
