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
import zlib

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
UNRESOLVED_REVIEW_SUBMISSION_STATE = "UNRESOLVED_ISSUES"
ACTIVE_REVIEW_SUBMISSION_STATES = (
    UNRESOLVED_REVIEW_SUBMISSION_STATE,
    READY_REVIEW_SUBMISSION_STATE,
)
RESOLVABLE_REVIEW_ITEM_STATES = {"REJECTED"}
IGNORABLE_REVIEW_ITEM_STATES = {"REMOVED"}
CONFIRMATION_ENV = "SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT"
CHECKPOINT_CONFIRMATION_ENV = "SUNCLUB_APP_REVIEW_CHECKPOINT_CONFIRMED"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
BLANK_SCREENSHOT_MEAN_THRESHOLD = 244.0
BLANK_SCREENSHOT_VARIANCE_THRESHOLD = 400.0
REVIEW_CONTACT_ATTRIBUTE_MAP = {
    "first_name": "contactFirstName",
    "last_name": "contactLastName",
    "phone": "contactPhone",
    "email": "contactEmail",
}

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


def is_current_state_version_create_error(error: AppStoreConnectError) -> bool:
    message = str(error).lower()
    return "cannot create a new version" in message and "current state" in message


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
        reuse_existing_review_contact: bool = False,
    ) -> None:
        self.client = client
        self.manifest = manifest
        self.context = context
        self.repo_root = repo_root
        self.sleep = sleep
        self.build_timeout_seconds = build_timeout_seconds
        self.screenshot_timeout_seconds = screenshot_timeout_seconds
        self.poll_interval_seconds = poll_interval_seconds
        self.reuse_existing_review_contact = reuse_existing_review_contact

    def prepare_draft(self) -> SubmissionResult:
        app_id = self.lookup_app_id()
        build_id = self.wait_for_valid_build(app_id)
        app_store_version_id = self.ensure_app_store_version(app_id, build_id)
        version_localization_id = self.ensure_version_localization(app_store_version_id)
        self.update_app_info(app_id)
        self.upload_screenshots(version_localization_id)
        self.publish_accessibility_declaration(app_id)
        self.upsert_review_detail(app_store_version_id)
        review_submission_id = self.ensure_review_submission(
            app_id,
            app_store_version_id,
        )
        review_submission_item_id = self.ensure_submission_item(
            review_submission_id,
            app_store_version_id,
        )
        return SubmissionResult(
            app_id=app_id,
            build_id=build_id,
            app_store_version_id=app_store_version_id,
            review_submission_id=review_submission_id,
            review_submission_item_id=review_submission_item_id,
        )

    def submit(self) -> SubmissionResult:
        result = self.prepare_draft()
        self.finalize_submission(result.review_submission_id)
        return result

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
                    self.patch_build_encryption(build_id, uses_encryption)
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

    def patch_build_encryption(self, build_id: str, uses_encryption: bool) -> None:
        try:
            self.client.patch(
                f"/builds/{build_id}",
                {
                    "data": {
                        "type": "builds",
                        "id": build_id,
                        "attributes": {"usesNonExemptEncryption": uses_encryption},
                    }
                },
            )
        except AppStoreConnectError as error:
            message = str(error)
            if "already set" not in message:
                raise

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
            try:
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
            except AppStoreConnectError as error:
                if not is_current_state_version_create_error(error):
                    raise
                app_store_version_id = self.reuse_editable_app_store_version(
                    app_id,
                    copyright_value=copyright_value,
                    release_type=release_type,
                )

        self.client.patch(
            f"/appStoreVersions/{app_store_version_id}/relationships/build",
            {"data": {"type": "builds", "id": build_id}},
        )
        return app_store_version_id

    def reuse_editable_app_store_version(
        self,
        app_id: str,
        *,
        copyright_value: str,
        release_type: str,
    ) -> str:
        versions = self.client.get_collection(
            f"/apps/{app_id}/appStoreVersions",
            query={
                "filter[platform]": PLATFORM,
                "include": "build",
                "limit": 10,
            },
        )
        for version in versions:
            state = resource_attributes(version).get("appStoreState")
            if state not in EDITABLE_VERSION_STATES:
                continue
            app_store_version_id = resource_id(version)
            self.client.patch(
                f"/appStoreVersions/{app_store_version_id}",
                {
                    "data": {
                        "type": "appStoreVersions",
                        "id": app_store_version_id,
                        "attributes": {
                            "versionString": self.context.marketing_version,
                            "copyright": copyright_value,
                            "releaseType": release_type,
                            "reviewType": "APP_STORE",
                        },
                    }
                },
            )
            return app_store_version_id
        raise AppStoreConnectError(
            "App Store Connect would not create a new App Store version, "
            "and no editable existing iOS version was available to reuse."
        )

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
        self.patch_version_localization(localization_id, attributes)
        return localization_id

    def patch_version_localization(
        self,
        localization_id: str,
        attributes: JsonObject,
    ) -> None:
        path = f"/appStoreVersionLocalizations/{localization_id}"
        body = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": localization_id,
                "attributes": attributes,
            }
        }
        try:
            self.client.patch(path, body)
        except AppStoreConnectError as error:
            message = str(error)
            if (
                "whatsNew" not in attributes
                or "whatsNew" not in message
                or "cannot be edited" not in message
            ):
                raise
            retry_attributes = dict(attributes)
            retry_attributes.pop("whatsNew", None)
            self.client.patch(
                path,
                {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": localization_id,
                        "attributes": retry_attributes,
                    }
                },
            )

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
            existing_attributes = resource_attributes(existing)
            changed_attributes = {
                key: value
                for key, value in attributes.items()
                if existing_attributes.get(key) != value
            }
            self.patch_app_info_localization(localization_id, changed_attributes)
        self.update_app_categories(app_info_id)

    def patch_app_info_localization(
        self,
        localization_id: str,
        attributes: JsonObject,
    ) -> None:
        if not attributes:
            return
        path = f"/appInfoLocalizations/{localization_id}"
        body = {
            "data": {
                "type": "appInfoLocalizations",
                "id": localization_id,
                "attributes": attributes,
            }
        }
        try:
            self.client.patch(path, body)
        except AppStoreConnectError as error:
            message = str(error)
            locked_fields = {
                field
                for field in attributes
                if f"field '{field}' can not be modified" in message
            }
            if not locked_fields:
                raise
            retry_attributes = {
                key: value
                for key, value in attributes.items()
                if key not in locked_fields
            }
            if not retry_attributes:
                return
            self.client.patch(
                path,
                {
                    "data": {
                        "type": "appInfoLocalizations",
                        "id": localization_id,
                        "attributes": retry_attributes,
                    }
                },
            )

    def update_app_categories(self, app_info_id: str) -> None:
        app = self.manifest["app"]
        primary_category = str(app.get("primary_category", "")).strip()
        secondary_category = str(app.get("secondary_category", "")).strip()

        if primary_category:
            current_primary = self.category_relationship_id(
                app_info_id,
                "primaryCategory",
            )
            if current_primary != primary_category:
                self.client.patch(
                    f"/appInfos/{app_info_id}/relationships/primaryCategory",
                    {"data": {"type": "appCategories", "id": primary_category}},
                )
        if secondary_category:
            current_secondary = self.category_relationship_id(
                app_info_id,
                "secondaryCategory",
            )
            if current_secondary != secondary_category:
                self.client.patch(
                    f"/appInfos/{app_info_id}/relationships/secondaryCategory",
                    {"data": {"type": "appCategories", "id": secondary_category}},
                )

    def category_relationship_id(
        self, app_info_id: str, relationship: str
    ) -> str | None:
        response = self.client.get(
            f"/appInfos/{app_info_id}/relationships/{relationship}"
        )
        data = response.get("data")
        if isinstance(data, Mapping):
            value = data.get("id")
            return value if isinstance(value, str) else None
        return None

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

        self.patch_accessibility_declaration(declaration_id, attributes)

    def patch_accessibility_declaration(
        self,
        declaration_id: str,
        attributes: JsonObject,
    ) -> None:
        path = f"/accessibilityDeclarations/{declaration_id}"
        try:
            self.client.patch(
                path,
                {
                    "data": {
                        "type": "accessibilityDeclarations",
                        "id": declaration_id,
                        "attributes": {"publish": True, **attributes},
                    }
                },
            )
        except AppStoreConnectError as error:
            message = str(error)
            if is_locked_accessibility_declaration_error(message):
                return
            if not is_unpublished_accessibility_declaration_error(message):
                raise
            try:
                self.client.patch(
                    path,
                    {
                        "data": {
                            "type": "accessibilityDeclarations",
                            "id": declaration_id,
                            "attributes": attributes,
                        }
                    },
                )
            except AppStoreConnectError as retry_error:
                if is_locked_accessibility_declaration_error(str(retry_error)):
                    return
                raise

    def upsert_review_detail(self, app_store_version_id: str) -> str:
        review = self.manifest["review"]
        existing = self.client.get_optional(
            f"/appStoreVersions/{app_store_version_id}/appStoreReviewDetail"
        )
        data = existing.get("data") if existing else None
        existing_detail = data if isinstance(data, Mapping) else None
        contact = self.review_contact_with_existing_values(
            review["contact"],
            existing_detail,
        )
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

        if existing_detail is not None:
            detail_id = resource_id(existing_detail)
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

    def review_contact_with_existing_values(
        self,
        contact: Mapping[str, Any],
        existing_detail: Mapping[str, Any] | None,
    ) -> dict[str, str]:
        merged: dict[str, str] = {
            field: str(contact.get(field, "")).strip()
            for field in REVIEW_CONTACT_ATTRIBUTE_MAP
        }
        missing_fields = [field for field, value in merged.items() if not value]
        if not missing_fields:
            return merged
        if not self.reuse_existing_review_contact:
            missing = ", ".join(f"review.contact.{field}" for field in missing_fields)
            raise AppStoreConnectError(f"{missing} is required.")

        existing_attributes = (
            resource_attributes(existing_detail) if existing_detail is not None else {}
        )
        for field in missing_fields:
            attribute = REVIEW_CONTACT_ATTRIBUTE_MAP[field]
            existing_value = str(existing_attributes.get(attribute, "")).strip()
            if existing_value:
                merged[field] = existing_value

        still_missing = [field for field, value in merged.items() if not value]
        if still_missing:
            missing = ", ".join(f"review.contact.{field}" for field in still_missing)
            raise AppStoreConnectError(
                f"{missing} is required because no existing App Store Connect "
                "review contact is available to reuse."
            )
        return merged

    def ensure_review_submission(
        self,
        app_id: str,
        app_store_version_id: str,
    ) -> str:
        submissions = self.active_review_submissions(app_id)

        for submission in submissions:
            version = relationship_data(submission, "appStoreVersionForReview")
            if version and version.get("id") == app_store_version_id:
                return resource_id(submission)

        for submission in submissions:
            submission_id = resource_id(submission)
            if self.review_submission_contains_version(
                submission_id,
                app_store_version_id,
            ):
                return submission_id

        if submissions:
            active = ", ".join(
                active_review_submission_description(submission)
                for submission in submissions
            )
            raise AppStoreConnectError(
                "Active App Review submission exists but is not associated with "
                f"App Store version {app_store_version_id}: {active}. Resolve it "
                "in App Store Connect before submitting this release."
            )

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

    def active_review_submissions(self, app_id: str) -> list[JsonObject]:
        submissions: list[JsonObject] = []
        seen: set[str] = set()
        for state in ACTIVE_REVIEW_SUBMISSION_STATES:
            for submission in self.client.get_collection(
                f"/apps/{app_id}/reviewSubmissions",
                query={
                    "filter[platform]": PLATFORM,
                    "filter[state]": state,
                    "fields[reviewSubmissions]": [
                        "state",
                        "items",
                        "appStoreVersionForReview",
                    ],
                    "fields[reviewSubmissionItems]": [
                        "state",
                        "appStoreVersion",
                    ],
                    "fields[appStoreVersions]": [
                        "versionString",
                        "appStoreState",
                    ],
                    "include": "appStoreVersionForReview,items",
                    "limit": 10,
                    "limit[items]": 10,
                },
            ):
                submission_id = resource_id(submission)
                if submission_id in seen:
                    continue
                seen.add(submission_id)
                submissions.append(submission)
        return submissions

    def review_submission_contains_version(
        self,
        review_submission_id: str,
        app_store_version_id: str,
    ) -> bool:
        for item in self.review_submission_items(review_submission_id):
            version = relationship_data(item, "appStoreVersion")
            if version and version.get("id") == app_store_version_id:
                return True
        return False

    def review_submission_items(self, review_submission_id: str) -> list[JsonObject]:
        return self.client.get_collection(
            f"/reviewSubmissions/{review_submission_id}/items",
            query={
                "fields[reviewSubmissionItems]": [
                    "state",
                    "appStoreVersion",
                ],
                "fields[appStoreVersions]": [
                    "versionString",
                    "appStoreState",
                ],
                "include": "appStoreVersion",
                "limit": 200,
            },
        )

    def ensure_submission_item(
        self,
        review_submission_id: str,
        app_store_version_id: str,
    ) -> str:
        items = self.review_submission_items(review_submission_id)
        for item in items:
            version = relationship_data(item, "appStoreVersion")
            if version and version.get("id") == app_store_version_id:
                item_id = resource_id(item)
                state = resource_attributes(item).get("state")
                if state in RESOLVABLE_REVIEW_ITEM_STATES:
                    self.resolve_submission_item(item_id)
                return item_id
            if version:
                state = resource_attributes(item).get("state")
                if state in IGNORABLE_REVIEW_ITEM_STATES:
                    continue
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

    def resolve_submission_item(self, review_submission_item_id: str) -> None:
        self.client.patch(
            f"/reviewSubmissionItems/{review_submission_item_id}",
            {
                "data": {
                    "type": "reviewSubmissionItems",
                    "id": review_submission_item_id,
                    "attributes": {"resolved": True},
                }
            },
        )

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


def active_review_submission_description(resource: Mapping[str, Any]) -> str:
    submission_id = resource_id(resource)
    state = str(resource_attributes(resource).get("state") or "unknown")
    version = relationship_data(resource, "appStoreVersionForReview")
    version_id = str(version.get("id")) if version else "unknown"
    return f"{submission_id} ({state}, app version {version_id})"


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
            continue
        profile = png_luminance_profile(screenshot_file.path)
        if (
            profile is not None
            and profile["mean"] >= BLANK_SCREENSHOT_MEAN_THRESHOLD
            and profile["variance"] <= BLANK_SCREENSHOT_VARIANCE_THRESHOLD
        ):
            errors.append(
                f"Screenshot {screenshot_file.path} appears blank or nearly blank."
            )
    return errors


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or not header.startswith(PNG_SIGNATURE):
        raise AppStoreConnectError(f"Screenshot is not a PNG file: {path}")
    return struct.unpack(">II", header[16:24])


def png_luminance_profile(path: Path) -> dict[str, float] | None:
    data = path.read_bytes()
    if len(data) < 24 or not data.startswith(PNG_SIGNATURE):
        raise AppStoreConnectError(f"Screenshot is not a PNG file: {path}")

    offset = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = None
    idat_chunks: list[bytes] = []
    while offset + 8 <= len(data):
        chunk_length = struct.unpack(">I", data[offset : offset + 4])[0]
        offset += 4
        chunk_type = data[offset : offset + 4]
        offset += 4
        chunk = data[offset : offset + chunk_length]
        offset += chunk_length + 4
        if chunk_type == b"IHDR":
            if len(chunk) < 13:
                return None
            width, height, bit_depth, color_type, _, _, _ = struct.unpack(
                ">IIBBBBB",
                chunk,
            )
        elif chunk_type == b"IDAT":
            idat_chunks.append(chunk)
        elif chunk_type == b"IEND":
            break

    if (
        width is None
        or height is None
        or bit_depth != 8
        or color_type not in {2, 6}
        or not idat_chunks
    ):
        return None

    bytes_per_pixel = 4 if color_type == 6 else 3
    stride = width * bytes_per_pixel
    try:
        raw = zlib.decompress(b"".join(idat_chunks))
    except zlib.error as error:
        raise AppStoreConnectError(
            f"Screenshot PNG data could not be decoded: {path}"
        ) from error

    previous = bytearray(stride)
    position = 0
    sample_count = 0
    luminance_sum = 0.0
    luminance_square_sum = 0.0
    row_step = max(1, height // 160)
    column_step = max(1, width // 80)
    for y in range(height):
        if position >= len(raw):
            return None
        filter_type = raw[position]
        position += 1
        row = bytearray(raw[position : position + stride])
        position += stride
        if len(row) != stride:
            return None

        unfilter_png_row(row, previous, filter_type, bytes_per_pixel)
        if y % row_step == 0:
            for x in range(0, width, column_step):
                index = x * bytes_per_pixel
                red = row[index]
                green = row[index + 1]
                blue = row[index + 2]
                luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                luminance_sum += luminance
                luminance_square_sum += luminance * luminance
                sample_count += 1
        previous = row

    if sample_count == 0:
        return None
    mean = luminance_sum / sample_count
    variance = max(0.0, (luminance_square_sum / sample_count) - (mean * mean))
    return {"mean": mean, "variance": variance}


def unfilter_png_row(
    row: bytearray,
    previous: bytearray,
    filter_type: int,
    bytes_per_pixel: int,
) -> None:
    for index in range(len(row)):
        left = row[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
        up = previous[index]
        upper_left = (
            previous[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
        )
        if filter_type == 1:
            row[index] = (row[index] + left) & 0xFF
        elif filter_type == 2:
            row[index] = (row[index] + up) & 0xFF
        elif filter_type == 3:
            row[index] = (row[index] + ((left + up) // 2)) & 0xFF
        elif filter_type == 4:
            prediction = left + up - upper_left
            left_distance = abs(prediction - left)
            up_distance = abs(prediction - up)
            upper_left_distance = abs(prediction - upper_left)
            if left_distance <= up_distance and left_distance <= upper_left_distance:
                paeth = left
            elif up_distance <= upper_left_distance:
                paeth = up
            else:
                paeth = upper_left
            row[index] = (row[index] + paeth) & 0xFF
        elif filter_type != 0:
            raise AppStoreConnectError(f"Unsupported PNG filter type: {filter_type}")


def accessibility_attributes(payload: Mapping[str, Any]) -> JsonObject:
    return {
        apple_key: bool(payload.get(manifest_key, False))
        for manifest_key, apple_key in ACCESSIBILITY_ATTRIBUTE_MAP.items()
    }


def is_unpublished_accessibility_declaration_error(message: str) -> bool:
    return (
        "accessibilityDeclarations" in message
        and "must be available on the App Store" in message
    )


def is_locked_accessibility_declaration_error(message: str) -> bool:
    normalized = message.lower()
    return (
        "accessibilitydeclaration" in normalized
        and "only be modified" in normalized
        and "'draft'" in normalized
    )


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
    allow_existing_review_contact: bool = False,
) -> tuple[list[str], list[str]]:
    errors, warnings = validate_metadata.validate_manifest(
        dict(manifest),
        allow_draft=not submission_ready,
        allow_existing_review_contact=allow_existing_review_contact,
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
    mode.add_argument(
        "--draft",
        action="store_true",
        help="Apply App Store Connect changes and create or update the draft review submission without submitting it.",
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
        reuse_existing_review_contact = (
            os.environ.get(validate_metadata.EXISTING_REVIEW_CONTACT_ENV) == "1"
        )
        errors, warnings = local_validation(
            manifest,
            repo_root=REPO_ROOT,
            submission_ready=args.submit or args.draft,
            allow_existing_review_contact=reuse_existing_review_contact,
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
        if args.submit:
            require_confirmation(args, os.environ)
        client = AppStoreConnectClient.from_env()
        submitter = AppStoreReviewSubmitter(
            client,
            manifest,
            context,
            build_timeout_seconds=args.build_timeout_seconds,
            screenshot_timeout_seconds=args.screenshot_timeout_seconds,
            poll_interval_seconds=args.poll_interval_seconds,
            reuse_existing_review_contact=reuse_existing_review_contact,
        )
        result = submitter.submit() if args.submit else submitter.prepare_draft()
    except (
        AppStoreConnectError,
        OSError,
        json.JSONDecodeError,
        appstore_manifest.ReviewEnvError,
    ) as error:
        print(f"App Store review submission failed: {error}", file=sys.stderr)
        return 1

    if args.submit:
        print("App Store review submission completed.")
    else:
        print("App Store draft review submission prepared.")
    print(f"- App ID: {result.app_id}")
    print(f"- Build ID: {result.build_id}")
    print(f"- App Store version ID: {result.app_store_version_id}")
    print(f"- Review submission ID: {result.review_submission_id}")
    print(f"- Review submission item ID: {result.review_submission_item_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
