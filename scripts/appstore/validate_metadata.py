#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


APP_NAME_LIMIT = 30
SUBTITLE_LIMIT = 30
KEYWORDS_LIMIT_BYTES = 100
PROMOTIONAL_TEXT_LIMIT = 170
DESCRIPTION_LIMIT = 4000
WHATS_NEW_LIMIT = 4000
VALID_ROUTES = {
    "welcome",
    "home",
    "verifyCamera",
    "verifySuccess",
    "weeklySummary",
    "settings",
    "history",
    "manualLog",
}
FORBIDDEN_OFFLINE_CLAIMS = (
    "fully offline",
    "no network connection needed",
    "no internet connection needed",
)
FORBIDDEN_FREE_COPY = (
    "freemium",
    "subscription",
    "subscriptions",
    "premium",
)


def load_manifest(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def utf8_len(value: str) -> int:
    return len(value.encode("utf-8"))


def validate_https_url(raw_value: str) -> bool:
    parsed = urlparse(raw_value)
    return parsed.scheme == "https" and bool(parsed.netloc)


def lower_strings(values: list[str]) -> str:
    return "\n".join(value.lower() for value in values)


def validate_manifest(manifest: dict[str, Any], *, allow_draft: bool = False) -> tuple[list[str], list[str]]:
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
        errors.append(f"localizations must include the primary locale {primary_locale!r}.")

    name = str(app.get("name", "")).strip()
    subtitle = str(app.get("subtitle", "")).strip()
    pricing_model = str(app.get("pricing_model", "")).strip().lower()
    supports_odr = bool(app.get("supports_on_demand_resources", False))

    if not name:
        errors.append("app.name is required.")
    elif len(name) > APP_NAME_LIMIT:
        errors.append(f"app.name exceeds Apple’s {APP_NAME_LIMIT}-character limit.")

    if not subtitle:
        errors.append("app.subtitle is required.")
    elif len(subtitle) > SUBTITLE_LIMIT:
        errors.append(f"app.subtitle exceeds Apple’s {SUBTITLE_LIMIT}-character limit.")

    if pricing_model != "free":
        errors.append("app.pricing_model must be 'free' for this release train.")

    if app.get("device_family") != "iphone":
        errors.append("app.device_family must be 'iphone' for the iPhone-only release.")

    locale_payload = localizations.get(primary_locale, {}) if isinstance(primary_locale, str) else {}
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
        errors.append(f"localizations.{primary_locale}.description exceeds {DESCRIPTION_LIMIT} characters.")

    if promotional_text and len(promotional_text) > PROMOTIONAL_TEXT_LIMIT:
        errors.append(
            f"localizations.{primary_locale}.promotional_text exceeds Apple’s {PROMOTIONAL_TEXT_LIMIT}-character limit."
        )

    if whats_new and len(whats_new) > WHATS_NEW_LIMIT:
        errors.append(f"localizations.{primary_locale}.whats_new exceeds {WHATS_NEW_LIMIT} characters.")

    if not isinstance(keywords, list) or not all(isinstance(keyword, str) for keyword in keywords):
        errors.append(f"localizations.{primary_locale}.keywords must be an array of strings.")
        keywords = []

    joined_keywords = ",".join(keyword.strip() for keyword in keywords if keyword.strip())
    if not joined_keywords:
        errors.append(f"localizations.{primary_locale}.keywords must contain at least one keyword.")
    elif utf8_len(joined_keywords) > KEYWORDS_LIMIT_BYTES:
        errors.append(
            f"localizations.{primary_locale}.keywords exceeds Apple’s {KEYWORDS_LIMIT_BYTES}-byte limit."
        )

    copy_to_scan = [name, subtitle, description, promotional_text, whats_new, joined_keywords]
    review = manifest.get("review", {})
    if isinstance(review, dict):
        copy_to_scan.append(str(review.get("notes", "")))
        copy_to_scan.append(str(review.get("demo_account_notes", "")))

    lowered_copy = lower_strings(copy_to_scan)

    if supports_odr and any(phrase in lowered_copy for phrase in FORBIDDEN_OFFLINE_CLAIMS):
        errors.append(
            "Metadata claims the app is fully offline even though camera verification depends on a one-time ODR download."
        )

    if pricing_model == "free" and any(word in lowered_copy for word in FORBIDDEN_FREE_COPY):
        errors.append("Metadata mentions subscriptions, premium access, or freemium copy while the release is free-only.")

    urls = manifest.get("urls")
    if not isinstance(urls, dict):
        errors.append("Missing required object: urls.")
    else:
        for key in ("support", "marketing", "privacy_policy"):
            payload = urls.get(key)
            if not isinstance(payload, dict):
                errors.append(f"urls.{key} must be an object with value and ready keys.")
                continue

            value = str(payload.get("value", "")).strip()
            ready = payload.get("ready")

            if not validate_https_url(value):
                errors.append(f"urls.{key}.value must be a valid https URL.")
            if ready is not True:
                message = f"urls.{key} is still marked as not ready for App Store submission."
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
            for field in ("first_name", "last_name", "email", "phone"):
                value = str(contact.get(field, "")).strip()
                if not value:
                    errors.append(f"review.contact.{field} is required.")
            if contact.get("ready") is not True:
                message = "review.contact is still marked as not ready for submission."
                if allow_draft:
                    warnings.append(message)
                else:
                    errors.append(message)

        if "notes" not in review or not str(review.get("notes", "")).strip():
            errors.append("review.notes is required.")

    privacy = manifest.get("privacy")
    if not isinstance(privacy, dict):
        errors.append("Missing required object: privacy.")
    else:
        if privacy.get("tracking") not in (True, False):
            errors.append("privacy.tracking must be a boolean.")
        if not str(privacy.get("camera_usage_description", "")).strip():
            errors.append("privacy.camera_usage_description is required.")
        if not str(privacy.get("notifications_usage_description", "")).strip():
            errors.append("privacy.notifications_usage_description is required.")

    export_compliance = manifest.get("export_compliance")
    if not isinstance(export_compliance, dict):
        errors.append("Missing required object: export_compliance.")
    elif export_compliance.get("uses_encryption") not in (True, False):
        errors.append("export_compliance.uses_encryption must be a boolean.")

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

            screens = screenshots.get("screens")
            if not isinstance(screens, list) or not screens:
                errors.append("assets.screenshots.screens must contain at least one screen definition.")
            else:
                seen_ids: set[str] = set()
                for index, screen in enumerate(screens):
                    if not isinstance(screen, dict):
                        errors.append(f"assets.screenshots.screens[{index}] must be an object.")
                        continue

                    screen_id = str(screen.get("id", "")).strip()
                    route = str(screen.get("route", "")).strip()
                    if not screen_id:
                        errors.append(f"assets.screenshots.screens[{index}].id is required.")
                    elif screen_id in seen_ids:
                        errors.append(f"Duplicate screenshot id: {screen_id}.")
                    else:
                        seen_ids.add(screen_id)

                    if route not in VALID_ROUTES:
                        errors.append(
                            f"assets.screenshots.screens[{index}].route must be one of {sorted(VALID_ROUTES)}."
                        )

    submission = manifest.get("submission")
    if not isinstance(submission, dict):
        errors.append("Missing required object: submission.")
    elif not isinstance(submission.get("manual_steps"), list) or not submission["manual_steps"]:
        warnings.append("submission.manual_steps should document the remaining App Store Connect work.")

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Sunclub App Store metadata manifest.")
    parser.add_argument("manifest", nargs="?", default="scripts/appstore/metadata.json")
    parser.add_argument(
        "--allow-draft",
        action="store_true",
        help="Validate shape and content limits without requiring submission-ready URLs and review contact details.",
    )
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    if not manifest_path.is_file():
        print(f"Metadata file not found: {manifest_path}", file=sys.stderr)
        return 2

    try:
        manifest = load_manifest(manifest_path)
    except json.JSONDecodeError as error:
        print(f"Invalid JSON in {manifest_path}: {error}", file=sys.stderr)
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
