from __future__ import annotations

import argparse
from collections.abc import Mapping, Sequence
import os
from pathlib import Path
from typing import Any

from scripts.appstore import manifest as appstore_manifest
from scripts.appstore import validate_metadata
from scripts.tooling.resolve_versions import REPO_ROOT, resolve_versions


DEFAULT_PACKAGE_PATH = REPO_ROOT / "docs" / "app-store-review-package.md"
DEFAULT_CHECKPOINT_PATH = (
    REPO_ROOT / ".build" / "appstore-review-checkpoint" / "summary.md"
)


def generate_review_package(raw_manifest: Mapping[str, Any]) -> str:
    app = raw_manifest["app"]
    locale = app["primary_locale"]
    localization = raw_manifest["localizations"][locale]
    urls = raw_manifest["urls"]
    review = raw_manifest["review"]
    privacy = raw_manifest["privacy"]
    export = raw_manifest["export_compliance"]
    assets = raw_manifest["assets"]["screenshots"]
    accessibility = raw_manifest["accessibility"]["iphone"]
    age_rating = raw_manifest["age_rating_questionnaire"]
    attestations = raw_manifest["attestations"]
    medical = raw_manifest["regulatory"]["regulated_medical_device"]
    submission = raw_manifest["submission"]
    env_names = tuple(
        dict.fromkeys(
            (
                "ASC_KEY_ID",
                "ASC_ISSUER_ID",
                "ASC_KEY_FILE",
                *appstore_manifest.env_reference_names(raw_manifest),
                "SUNCLUB_CONFIRM_APP_REVIEW_SUBMIT",
                "SUNCLUB_APP_REVIEW_CHECKPOINT_CONFIRMED",
            )
        )
    )

    lines: list[str] = [
        "# App Store Review Package",
        "",
        "Generated from `scripts/appstore/metadata.json`. Sensitive values are supplied through environment variables or `.state/appstore/review.env`; do not paste real contact values into tracked files.",
        "",
        "## Manual Submission Interface",
        "",
        "Run `just appstore-env`, then `source .state/appstore/review.env` if submitting from the current shell. Submission scripts also auto-load that file when it exists.",
        "",
        "Required environment variables:",
        "",
    ]
    lines.extend(f"- `{env_name}`" for env_name in env_names)

    lines.extend(
        [
            "",
            "## Listing",
            "",
            f"- Name: {app['name']}",
            f"- Subtitle: {app['subtitle']}",
            f"- SKU: {app['sku']}",
            f"- Bundle ID: {app['bundle_id']}",
            f"- Primary locale: {locale}",
            f"- Primary category: {app['primary_category']}",
            f"- Secondary category: {app['secondary_category']}",
            f"- Age rating target: {app['age_rating']}",
            f"- Device family: {app['device_family']}",
            f"- Pricing: {app['pricing_model']}",
            f"- Support URL: <{urls['support']['value']}>",
            f"- Marketing URL: <{urls['marketing']['value']}>",
            f"- Privacy Policy URL: <{urls['privacy_policy']['value']}>",
            "",
            "Description:",
            "",
            localization["description"],
            "",
            f"Keywords: {', '.join(localization['keywords'])}",
            "",
            f"Promotional text: {localization['promotional_text']}",
            "",
            f"What's New: {localization['whats_new']}",
            "",
            "## App Review Notes",
            "",
            f"- Demo account required: {yes_no(review['demo_account_required'])}",
            f"- Demo account notes: {review['demo_account_notes']}",
            f"- Notes: {review['notes']}",
            "- Contact first name: `SUNCLUB_APP_REVIEW_CONTACT_FIRST_NAME`",
            "- Contact last name: `SUNCLUB_APP_REVIEW_CONTACT_LAST_NAME`",
            "- Contact email: `SUNCLUB_APP_REVIEW_CONTACT_EMAIL`",
            "- Contact phone: `SUNCLUB_APP_REVIEW_CONTACT_PHONE`",
            "",
            "## Screenshots",
            "",
            f"- Capture device: {assets['capture_device']}",
            f"- Required size class: {assets['required_size_class']}",
            f"- Display type: {assets['display_type']}",
            f"- Generated output: `{assets['output_directory']}`",
        ]
    )
    lines.extend(
        f"- {screen['id']}: route `{screen['route']}`" for screen in assets["screens"]
    )

    lines.extend(
        [
            "",
            "## App Privacy",
            "",
            f"- Tracking: {yes_no(privacy['tracking'])}",
            f"- Data collection: {privacy['data_collection']}",
            (
                "- Public CloudKit accountability transport: "
                f"{yes_no(privacy['public_cloudkit_accountability_transport'])}"
            ),
            f"- Notification purpose: {privacy['notifications_usage_description']}",
            "- App Store Connect questionnaire gate: `SUNCLUB_APP_PRIVACY_COMPLETED=1`",
            "",
            "Manual App Store Connect answer: data not collected for the default release build. Keep this answer only while public CloudKit accountability transport remains disabled.",
            "",
            "## Age Rating",
            "",
        ]
    )
    lines.extend(f"- {key}: {yes_no(value)}" for key, value in age_rating.items())

    lines.extend(
        [
            "",
            "## Accessibility Nutrition Label",
            "",
        ]
    )
    lines.extend(f"- {key}: {yes_no(value)}" for key, value in accessibility.items())

    lines.extend(
        [
            "",
            "## Export Compliance And Rights",
            "",
            f"- Uses encryption: {yes_no(export['uses_encryption'])}",
            (
                "- Contains third-party content: "
                f"{yes_no(export['contains_third_party_content'])}"
            ),
            f"- Content rights note: {export['content_rights_note']}",
            "",
            "## Attestations",
            "",
        ]
    )
    lines.extend(f"- {key}: {yes_no(value)}" for key, value in attestations.items())

    lines.extend(
        [
            "",
            "## Medical Device Status",
            "",
            f"- Manifest status: {medical['status']}",
            f"- App Store Connect value: {medical['required_app_store_connect_value']}",
            f"- Confirmation gate: `SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS={medical['required_app_store_connect_value']}`",
            f"- Notes: {medical['notes']}",
            "",
            "## Manual App Store Connect Checks",
            "",
            "- Confirm App Privacy answers match this package before setting `SUNCLUB_APP_PRIVACY_COMPLETED=1`.",
            "- Confirm regulated medical device status is `NOT_MEDICAL_DEVICE` before setting `SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS=NOT_MEDICAL_DEVICE`.",
            "- Confirm age-rating answers match the questionnaire above.",
            "- Confirm pricing is free, no IAP is configured, and no Kids category is selected.",
            "- Confirm screenshot upload completed for the listed iPhone display type.",
            "- Confirm final checkpoint summary before running `just appstore-submit-review` or `just appstore-send-review`.",
            "",
            "## Submission Commands",
            "",
            "- Draft validation: `just appstore-validate`",
            "- Strict validation: `just appstore-validate-strict`",
            "- Regenerate this package: `just appstore-review-package`",
            "- Dry run: `just appstore-submit-dry-run`",
            "- Submit: `just appstore-submit-review`",
            "- Alias: `just appstore-send-review`",
            "",
            "## Remaining Manual Steps",
            "",
        ]
    )
    lines.extend(f"- {step}" for step in submission["manual_steps"])
    lines.append("")
    return "\n".join(lines)


def generate_checkpoint(
    report: appstore_manifest.ResolvedManifest,
    *,
    warnings: Sequence[str],
) -> str:
    versions = resolve_versions(os.environ, REPO_ROOT)
    lines = appstore_manifest.redacted_summary_lines(
        report.value,
        missing_env_vars=report.missing_env_vars,
        env_file=report.env_file,
        env_file_loaded=report.env_file_loaded,
        warnings=warnings,
    )
    lines.extend(
        [
            f"- Marketing version: {versions.marketing_version}",
            f"- Build number: {versions.build_number}",
            "",
            (
                "Exact local confirmation phrase: "
                f"`submit Sunclub {versions.marketing_version} "
                f"({versions.build_number}) to App Review`"
            ),
            "",
            "No secret values are written here.",
            "",
        ]
    )
    return "\n".join(lines)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)


def yes_no(value: Any) -> str:
    if value is True:
        return "yes"
    if value is False:
        return "no"
    return str(value)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate Sunclub App Store review package docs and checkpoint summaries."
    )
    parser.add_argument(
        "--manifest",
        default=str(appstore_manifest.DEFAULT_MANIFEST_PATH),
        help="Path to the App Store metadata manifest.",
    )
    parser.add_argument(
        "--output",
        default=str(DEFAULT_PACKAGE_PATH),
        help="Path to write the generated review package.",
    )
    parser.add_argument(
        "--checkpoint",
        action="store_true",
        help="Write the redacted final submission checkpoint instead of the review package.",
    )
    parser.add_argument(
        "--checkpoint-output",
        default=str(DEFAULT_CHECKPOINT_PATH),
        help="Path to write the redacted checkpoint summary.",
    )
    parser.add_argument(
        "--no-print",
        action="store_true",
        help="Write files without printing their content.",
    )
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    if args.checkpoint:
        report = appstore_manifest.load_resolved_manifest_report(manifest_path)
        _errors, warnings = validate_metadata.validate_manifest(
            report.value,
            allow_draft=True,
        )
        content = generate_checkpoint(report, warnings=warnings)
        output_path = Path(args.checkpoint_output)
    else:
        raw_manifest = appstore_manifest.load_raw_manifest(manifest_path)
        content = generate_review_package(raw_manifest)
        output_path = Path(args.output)

    write_text(output_path, content)
    if not args.no_print:
        print(content)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
