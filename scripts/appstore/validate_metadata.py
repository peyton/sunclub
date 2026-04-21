#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from scripts.appstore import manifest as appstore_manifest

APP_NAME_LIMIT = 30
SUBTITLE_LIMIT = 30
KEYWORDS_LIMIT_BYTES = 100
PROMOTIONAL_TEXT_LIMIT = 170
DESCRIPTION_LIMIT = 4000
WHATS_NEW_LIMIT = 4000
VALID_ROUTES = {
    "welcome",
    "home",
    "verifySuccess",
    "weeklySummary",
    "settings",
    "history",
    "manualLog",
}
VALID_RELEASE_TYPES = {"MANUAL", "AFTER_APPROVAL", "SCHEDULED"}
VALID_SCREENSHOT_DISPLAY_TYPES = {"APP_IPHONE_67"}
VALID_PRIMARY_CATEGORIES = {"HEALTH_AND_FITNESS"}
VALID_SECONDARY_CATEGORIES = {"LIFESTYLE"}
VALID_AGE_RATINGS = {"4+"}
VALID_DATA_COLLECTION_VALUES = {"none"}
VALID_MEDICAL_DEVICE_STATUSES = {"not_regulated"}
REQUIRED_MEDICAL_DEVICE_ASC_VALUE = "NOT_MEDICAL_DEVICE"
REQUIRED_AGE_RATING_FIELDS = {
    "ads": False,
    "unrestricted_web_access": False,
    "broad_user_generated_content": False,
    "in_app_chat": False,
    "gambling_or_contests": False,
    "mature_or_suggestive_content": "none",
    "sexual_content_or_nudity": "none",
    "violence": "none",
    "substance_or_tobacco_content": "none",
    "medical_or_treatment_information": "none",
}
REQUIRED_ATTESTATIONS = {
    "free_only": True,
    "in_app_purchases": False,
    "idfa": False,
    "tracking": False,
    "ads": False,
    "analytics_sdks": False,
    "non_exempt_encryption": False,
    "third_party_content": False,
    "kids_category": False,
    "iphone_only_v1": True,
    "accessibility_criteria_reviewed": True,
    "public_cloudkit_accountability_transport_enabled": False,
}
ACCESSIBILITY_FIELDS = {
    "supports_audio_descriptions",
    "supports_captions",
    "supports_dark_interface",
    "supports_differentiate_without_color_alone",
    "supports_larger_text",
    "supports_reduced_motion",
    "supports_sufficient_contrast",
    "supports_voice_control",
    "supports_voiceover",
}
FORBIDDEN_FREE_COPY = (
    "freemium",
    "subscription",
    "subscriptions",
    "premium",
)
FORBIDDEN_STALE_COPY = (
    "ai-powered",
    "ai powered",
    "ai confirms",
    "ai validation",
    "camera verification",
    "camera verify",
    "fully offline",
    "no cloud",
)
WEATHERKIT_DISCLOSURE_ERROR = "review.notes must explicitly disclose WeatherKit functionality status (clear yes/no statement)."
WEATHERKIT_NEGATIVE_DISCLOSURES = (
    "does not include weatherkit",
    "doesn't include weatherkit",
    "no weatherkit",
    "weatherkit is not included",
    "without weatherkit",
)
WEATHERKIT_POSITIVE_DISCLOSURES = (
    "includes weatherkit",
    "uses weatherkit",
    "weatherkit is included",
    "with weatherkit",
)


def load_manifest(path: Path) -> dict[str, Any]:
    return appstore_manifest.load_resolved_manifest(path)


def load_raw_manifest(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def utf8_len(value: str) -> int:
    return len(value.encode("utf-8"))


def validate_https_url(raw_value: str) -> bool:
    parsed = urlparse(raw_value)
    return parsed.scheme == "https" and bool(parsed.netloc)


def lower_strings(values: list[str]) -> str:
    return "\n".join(value.lower() for value in values)


def validate_manifest(
    manifest: dict[str, Any], *, allow_draft: bool = False
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []

    app = manifest.get("app")
    if not isinstance(app, dict):
        return (["Missing required object: app"], warnings)

    localizations = manifest.get("localizations")
    if not isinstance(localizations, dict):
        return (["Missing required object: localizations"], warnings)

    primary_locale = app.get("primary_locale")
    if not isinstance(primary_locale, str) or not primary_locale:
        errors.append("app.primary_locale is required.")
    elif primary_locale not in localizations:
        errors.append(
            f"localizations must include the primary locale {primary_locale!r}."
        )

    name = str(app.get("name", "")).strip()
    subtitle = str(app.get("subtitle", "")).strip()
    pricing_model = str(app.get("pricing_model", "")).strip().lower()
    if not name:
        errors.append("app.name is required.")
    elif len(name) > APP_NAME_LIMIT:
        errors.append(f"app.name exceeds Apple's {APP_NAME_LIMIT}-character limit.")

    if not subtitle:
        errors.append("app.subtitle is required.")
    elif len(subtitle) > SUBTITLE_LIMIT:
        errors.append(f"app.subtitle exceeds Apple's {SUBTITLE_LIMIT}-character limit.")

    if pricing_model != "free":
        errors.append("app.pricing_model must be 'free' for this release train.")

    if app.get("primary_category") not in VALID_PRIMARY_CATEGORIES:
        errors.append(
            "app.primary_category must be HEALTH_AND_FITNESS for the first submission."
        )

    if app.get("secondary_category") not in VALID_SECONDARY_CATEGORIES:
        errors.append(
            "app.secondary_category must be LIFESTYLE for the first submission."
        )

    if app.get("age_rating") not in VALID_AGE_RATINGS:
        errors.append("app.age_rating must remain 4+ for the first submission.")

    if app.get("device_family") != "iphone":
        errors.append("app.device_family must be 'iphone' for the iPhone-only release.")

    locale_payload = (
        localizations.get(primary_locale, {}) if isinstance(primary_locale, str) else {}
    )
    if not isinstance(locale_payload, dict):
        errors.append(f"localizations.{primary_locale} must be an object.")
        locale_payload = {}

    description = str(locale_payload.get("description", "")).strip()
    promotional_text = str(locale_payload.get("promotional_text", "")).strip()
    whats_new = str(locale_payload.get("whats_new", "")).strip()
    keywords = locale_payload.get("keywords", [])

    if not description:
        errors.append(f"localizations.{primary_locale}.description is required.")
    elif len(description) > DESCRIPTION_LIMIT:
        errors.append(
            f"localizations.{primary_locale}.description exceeds {DESCRIPTION_LIMIT} characters."
        )

    if promotional_text and len(promotional_text) > PROMOTIONAL_TEXT_LIMIT:
        errors.append(
            f"localizations.{primary_locale}.promotional_text exceeds Apple's {PROMOTIONAL_TEXT_LIMIT}-character limit."
        )

    if whats_new and len(whats_new) > WHATS_NEW_LIMIT:
        errors.append(
            f"localizations.{primary_locale}.whats_new exceeds {WHATS_NEW_LIMIT} characters."
        )

    if not isinstance(keywords, list) or not all(
        isinstance(keyword, str) for keyword in keywords
    ):
        errors.append(
            f"localizations.{primary_locale}.keywords must be an array of strings."
        )
        keywords = []

    joined_keywords = ",".join(
        keyword.strip() for keyword in keywords if keyword.strip()
    )
    if not joined_keywords:
        errors.append(
            f"localizations.{primary_locale}.keywords must contain at least one keyword."
        )
    elif utf8_len(joined_keywords) > KEYWORDS_LIMIT_BYTES:
        errors.append(
            f"localizations.{primary_locale}.keywords exceeds Apple's {KEYWORDS_LIMIT_BYTES}-byte limit."
        )

    copy_to_scan = [
        name,
        subtitle,
        description,
        promotional_text,
        whats_new,
        joined_keywords,
    ]
    review = manifest.get("review", {})
    if isinstance(review, dict):
        copy_to_scan.append(str(review.get("notes", "")))
        copy_to_scan.append(str(review.get("demo_account_notes", "")))

    lowered_copy = lower_strings(copy_to_scan)

    if pricing_model == "free" and any(
        word in lowered_copy for word in FORBIDDEN_FREE_COPY
    ):
        errors.append(
            "Metadata mentions subscriptions, premium access, or freemium copy while the release is free-only."
        )

    if any(phrase in lowered_copy for phrase in FORBIDDEN_STALE_COPY):
        errors.append(
            "Metadata contains stale AI, camera verification, fully-offline, or no-cloud copy."
        )

    urls = manifest.get("urls")
    if not isinstance(urls, dict):
        errors.append("Missing required object: urls.")
    else:
        for key in ("support", "marketing", "privacy_policy"):
            payload = urls.get(key)
            if not isinstance(payload, dict):
                errors.append(
                    f"urls.{key} must be an object with value and ready keys."
                )
                continue

            value = str(payload.get("value", "")).strip()
            ready = payload.get("ready")

            if not validate_https_url(value):
                errors.append(f"urls.{key}.value must be a valid https URL.")
            if ready is not True:
                message = (
                    f"urls.{key} is still marked as not ready for App Store submission."
                )
                if allow_draft:
                    warnings.append(message)
                else:
                    errors.append(message)

    if not isinstance(review, dict):
        errors.append("Missing required object: review.")
    else:
        contact = review.get("contact")
        if not isinstance(contact, dict):
            errors.append("review.contact must be an object.")
        else:
            missing_contact_fields: list[str] = []
            for field in ("first_name", "last_name", "email", "phone"):
                raw_value = contact.get(field, "")
                value = "" if isinstance(raw_value, dict) else str(raw_value).strip()
                if not value:
                    missing_contact_fields.append(field)
            if missing_contact_fields:
                message = "review.contact is still marked as not ready for submission."
                if allow_draft:
                    warnings.append(message)
                else:
                    for field in missing_contact_fields:
                        errors.append(f"review.contact.{field} is required.")
            elif contact.get("ready") is False:
                message = "review.contact is still marked as not ready for submission."
                if allow_draft:
                    warnings.append(message)
                else:
                    errors.append(message)

        notes = str(review.get("notes", "")).strip()
        if not notes:
            errors.append("review.notes is required.")
        else:
            lowered_notes = notes.lower()
            if "weatherkit" not in lowered_notes:
                errors.append(WEATHERKIT_DISCLOSURE_ERROR)
            else:
                has_negative = any(
                    disclosure in lowered_notes
                    for disclosure in WEATHERKIT_NEGATIVE_DISCLOSURES
                )
                has_positive = any(
                    disclosure in lowered_notes
                    for disclosure in WEATHERKIT_POSITIVE_DISCLOSURES
                )
                if has_negative == has_positive:
                    errors.append(WEATHERKIT_DISCLOSURE_ERROR)

    privacy = manifest.get("privacy")
    if not isinstance(privacy, dict):
        errors.append("Missing required object: privacy.")
    else:
        if privacy.get("tracking") not in (True, False):
            errors.append("privacy.tracking must be a boolean.")
        if privacy.get("data_collection") not in VALID_DATA_COLLECTION_VALUES:
            errors.append("privacy.data_collection must be 'none' for this release.")
        public_transport = privacy.get("public_cloudkit_accountability_transport")
        if public_transport not in (True, False):
            errors.append(
                "privacy.public_cloudkit_accountability_transport must be a boolean."
            )
        elif public_transport is True and privacy.get("data_collection") == "none":
            errors.append(
                "Public CloudKit accountability transport requires conservative App Privacy data-collection answers, not privacy.data_collection='none'."
            )
        if not str(privacy.get("notifications_usage_description", "")).strip():
            errors.append("privacy.notifications_usage_description is required.")
        if privacy.get("app_store_connect_completed") is not True:
            message = (
                "privacy.app_store_connect_completed must be true after the App "
                "Privacy questionnaire is completed in App Store Connect."
            )
            if allow_draft:
                warnings.append(message)
            else:
                errors.append(message)

    age_rating = manifest.get("age_rating_questionnaire")
    if not isinstance(age_rating, dict):
        errors.append("Missing required object: age_rating_questionnaire.")
    else:
        for field, expected in REQUIRED_AGE_RATING_FIELDS.items():
            if age_rating.get(field) != expected:
                errors.append(
                    f"age_rating_questionnaire.{field} must be {expected!r} for the first submission."
                )
        wellness_topic = str(age_rating.get("health_or_wellness_topics", "")).lower()
        if "sunscreen" not in wellness_topic or "guidance" not in wellness_topic:
            errors.append(
                "age_rating_questionnaire.health_or_wellness_topics must document sunscreen habit guidance only."
            )

    export_compliance = manifest.get("export_compliance")
    if not isinstance(export_compliance, dict):
        errors.append("Missing required object: export_compliance.")
    elif export_compliance.get("uses_encryption") not in (True, False):
        errors.append("export_compliance.uses_encryption must be a boolean.")
    elif export_compliance.get("uses_encryption") is True:
        errors.append("export_compliance.uses_encryption must remain false.")
    elif export_compliance.get("contains_third_party_content") is not False:
        errors.append(
            "export_compliance.contains_third_party_content must remain false."
        )

    attestations = manifest.get("attestations")
    if not isinstance(attestations, dict):
        errors.append("Missing required object: attestations.")
    else:
        for field, expected in REQUIRED_ATTESTATIONS.items():
            if attestations.get(field) != expected:
                errors.append(
                    f"attestations.{field} must be {expected!r} for the first submission."
                )

    regulatory = manifest.get("regulatory")
    if not isinstance(regulatory, dict):
        errors.append("Missing required object: regulatory.")
    else:
        medical = regulatory.get("regulated_medical_device")
        if not isinstance(medical, dict):
            errors.append("regulatory.regulated_medical_device must be an object.")
        else:
            if medical.get("status") not in VALID_MEDICAL_DEVICE_STATUSES:
                errors.append(
                    "regulatory.regulated_medical_device.status must be not_regulated."
                )
            if (
                medical.get("required_app_store_connect_value")
                != REQUIRED_MEDICAL_DEVICE_ASC_VALUE
            ):
                errors.append(
                    "regulatory.regulated_medical_device.required_app_store_connect_value must be NOT_MEDICAL_DEVICE."
                )
            if (
                medical.get("app_store_connect_value")
                != REQUIRED_MEDICAL_DEVICE_ASC_VALUE
            ):
                message = (
                    "SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS must be "
                    "NOT_MEDICAL_DEVICE after the App Store Connect medical-device "
                    "status is set."
                )
                if allow_draft:
                    warnings.append(message)
                else:
                    errors.append(message)
            if medical.get("confirmation_completed") is not True:
                message = (
                    "regulatory.regulated_medical_device.confirmation_completed "
                    "must be true for submission."
                )
                if allow_draft:
                    warnings.append(message)
                else:
                    errors.append(message)

    assets = manifest.get("assets")
    if not isinstance(assets, dict):
        errors.append("Missing required object: assets.")
    else:
        if not str(assets.get("icon_source_svg", "")).strip():
            errors.append("assets.icon_source_svg is required.")

        screenshots = assets.get("screenshots")
        if not isinstance(screenshots, dict):
            errors.append("assets.screenshots must be an object.")
        else:
            if not str(screenshots.get("capture_device", "")).strip():
                errors.append("assets.screenshots.capture_device is required.")
            if not str(screenshots.get("required_size_class", "")).strip():
                errors.append("assets.screenshots.required_size_class is required.")
            display_type = str(screenshots.get("display_type", "")).strip()
            if display_type not in VALID_SCREENSHOT_DISPLAY_TYPES:
                errors.append(
                    "assets.screenshots.display_type must be one of "
                    f"{sorted(VALID_SCREENSHOT_DISPLAY_TYPES)}."
                )

            screens = screenshots.get("screens")
            if not isinstance(screens, list) or not screens:
                errors.append(
                    "assets.screenshots.screens must contain at least one screen definition."
                )
            else:
                seen_ids: set[str] = set()
                for index, screen in enumerate(screens):
                    if not isinstance(screen, dict):
                        errors.append(
                            f"assets.screenshots.screens[{index}] must be an object."
                        )
                        continue

                    screen_id = str(screen.get("id", "")).strip()
                    route = str(screen.get("route", "")).strip()
                    if not screen_id:
                        errors.append(
                            f"assets.screenshots.screens[{index}].id is required."
                        )
                    elif screen_id in seen_ids:
                        errors.append(f"Duplicate screenshot id: {screen_id}.")
                    else:
                        seen_ids.add(screen_id)

                    if route not in VALID_ROUTES:
                        errors.append(
                            f"assets.screenshots.screens[{index}].route must be one of {sorted(VALID_ROUTES)}."
                        )

    accessibility = manifest.get("accessibility")
    if accessibility is not None:
        if not isinstance(accessibility, dict):
            errors.append("accessibility must be an object when provided.")
        else:
            iphone_accessibility = accessibility.get("iphone")
            if iphone_accessibility is not None:
                if not isinstance(iphone_accessibility, dict):
                    errors.append("accessibility.iphone must be an object.")
                else:
                    ready = iphone_accessibility.get("ready", False)
                    if ready not in (True, False):
                        errors.append("accessibility.iphone.ready must be a boolean.")
                    for field, value in iphone_accessibility.items():
                        if field == "ready":
                            continue
                        if field not in ACCESSIBILITY_FIELDS:
                            errors.append(
                                f"accessibility.iphone.{field} is not a supported accessibility declaration field."
                            )
                        elif value not in (True, False):
                            errors.append(
                                f"accessibility.iphone.{field} must be a boolean."
                            )
                    if ready is True:
                        for field in sorted(ACCESSIBILITY_FIELDS):
                            if field not in iphone_accessibility:
                                errors.append(
                                    f"accessibility.iphone.{field} is required when accessibility.iphone.ready is true."
                                )

    submission = manifest.get("submission")
    if not isinstance(submission, dict):
        errors.append("Missing required object: submission.")
    else:
        release_type = str(submission.get("release_type", "MANUAL"))
        if release_type not in VALID_RELEASE_TYPES:
            errors.append(
                f"submission.release_type must be one of {sorted(VALID_RELEASE_TYPES)}."
            )
        if (
            not isinstance(submission.get("manual_steps"), list)
            or not submission["manual_steps"]
        ):
            warnings.append(
                "submission.manual_steps should document the remaining App Store Connect work."
            )

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate Sunclub App Store metadata manifest."
    )
    parser.add_argument("manifest", nargs="?", default="scripts/appstore/metadata.json")
    parser.add_argument(
        "--allow-draft",
        action="store_true",
        help="Validate shape and content limits without requiring submission-ready URLs and review contact details.",
    )
    parser.add_argument(
        "--no-env-file",
        action="store_true",
        help="Do not auto-load .state/appstore/review.env before resolving env-backed metadata.",
    )
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    if not manifest_path.is_file():
        print(f"Metadata file not found: {manifest_path}", file=sys.stderr)
        return 2

    try:
        report = appstore_manifest.load_resolved_manifest_report(
            manifest_path,
            load_env_file=not args.no_env_file,
        )
        manifest = report.value
    except json.JSONDecodeError as error:
        print(f"Invalid JSON in {manifest_path}: {error}", file=sys.stderr)
        return 2
    except appstore_manifest.ReviewEnvError as error:
        print(f"Invalid App Store review environment: {error}", file=sys.stderr)
        return 2

    errors, warnings = validate_manifest(manifest, allow_draft=args.allow_draft)

    if errors:
        print(f"Metadata validation failed for {manifest_path}:")
        for error in errors:
            print(f"- ERROR: {error}")
        for warning in warnings:
            print(f"- WARNING: {warning}")
        return 1

    print(f"Metadata validation passed for {manifest_path}.")
    for warning in warnings:
        print(f"- WARNING: {warning}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
