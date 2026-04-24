import json
from pathlib import Path

from scripts.appstore import manifest as appstore_manifest
from scripts.appstore import validate_metadata as validator


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = REPO_ROOT / "scripts" / "appstore" / "metadata.json"
READY_ENV = {
    "SUNCLUB_APP_REVIEW_CONTACT_FIRST_NAME": "Peyton",
    "SUNCLUB_APP_REVIEW_CONTACT_LAST_NAME": "Randolph",
    "SUNCLUB_APP_REVIEW_CONTACT_EMAIL": "review@example.com",
    "SUNCLUB_APP_REVIEW_CONTACT_PHONE": "+1-415-555-0100",
    "SUNCLUB_APP_PRIVACY_COMPLETED": "1",
    "SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS": "NOT_MEDICAL_DEVICE",
}


def current_manifest(
    environment: dict[str, str] | None = None,
) -> dict[str, object]:
    return appstore_manifest.load_resolved_manifest(
        MANIFEST_PATH,
        environment=environment or READY_ENV,
        load_env_file=False,
    )


def test_validator_rejects_legacy_submission_problems() -> None:
    manifest = json.loads(
        """
        {
          "app": {
            "name": "Sunclub",
            "subtitle": "AI-Powered Sunscreen Habit Tracker",
            "bundle_id": "app.peyton.sunclub",
            "sku": "sunclub-ios-001",
            "primary_locale": "en-US",
            "primary_category": "HEALTH_AND_FITNESS",
            "secondary_category": "LIFESTYLE",
            "age_rating": "4+",
            "device_family": "iphone",
            "pricing_model": "free",
            "supports_on_demand_resources": false
          },
          "localizations": {
            "en-US": {
              "description": "Fully Offline. Premium subscription unlocks extra features.",
              "keywords": ["sunscreen","sunblock","SPF","skin care","habit tracker","daily routine","UV protection","streak","sun protection","skincare"],
              "promotional_text": "Build an unbreakable sunscreen habit.",
              "whats_new": "Initial release."
            }
          },
          "urls": {
            "support": { "value": "https://sunclub.app/support", "ready": false },
            "marketing": { "value": "https://sunclub.app", "ready": false },
            "privacy_policy": { "value": "https://sunclub.app/privacy", "ready": false }
          },
          "review": {
            "contact": {
              "first_name": "Peyton",
              "last_name": "Randolph",
              "email": "review-contact@sunclub.app",
              "phone": "+1-555-0100",
              "ready": false
            },
            "demo_account_required": false,
            "demo_account_notes": "No account required.",
            "notes": "Premium plan details are in the app.",
            "attachments": []
          },
          "privacy": {
            "tracking": false,
            "data_collection": "none",
            "app_store_connect_completed": false,
            "notifications_usage_description": "Notifications remind the user to apply sunscreen."
          },
          "export_compliance": {
            "uses_encryption": false,
            "contains_third_party_content": false,
            "content_rights_note": "This app does not contain, show, or access third-party content."
          },
          "assets": {
            "icon_source_svg": "icon.svg",
            "screenshots": {
              "capture_device": "iPhone 17 Pro Max",
              "required_size_class": "6.9-inch iPhone",
              "display_type": "APP_IPHONE_67",
              "output_directory": ".build/appstore-screenshots",
              "screens": [
                {
                  "id": "home",
                  "route": "home",
                  "complete_onboarding": true,
                  "launch_arguments": []
                }
              ]
            }
          },
          "submission": {
            "copyright": "2026 Peyton Randolph",
            "manual_steps": ["Replace draft URLs."]
          }
        }
        """
    )

    errors, warnings = validator.validate_manifest(manifest, allow_draft=False)

    assert errors
    assert not warnings
    assert "app.subtitle exceeds Apple's 30-character limit." in errors
    assert "localizations.en-US.keywords exceeds Apple's 100-byte limit." in errors
    assert (
        "Metadata mentions subscriptions, premium access, or freemium copy while the release is free-only."
        in errors
    )
    assert (
        "Metadata contains stale AI, camera verification, fully-offline, or no-cloud copy."
        in errors
    )
    assert (
        "urls.support is still marked as not ready for App Store submission." in errors
    )
    assert "review.contact is still marked as not ready for submission." in errors
    assert (
        "privacy.app_store_connect_completed must be true after the App Privacy questionnaire is completed in App Store Connect."
        in errors
    )
    assert (
        "review.notes must explicitly disclose WeatherKit functionality status (clear yes/no statement)."
        in errors
    )


def test_validator_allows_current_manifest_in_draft_mode() -> None:
    manifest = appstore_manifest.load_resolved_manifest(
        MANIFEST_PATH,
        environment={},
        load_env_file=False,
    )
    manual_steps = manifest["submission"]["manual_steps"]

    errors, warnings = validator.validate_manifest(manifest, allow_draft=True)
    iphone_accessibility = manifest["accessibility"]["iphone"]

    assert errors == []
    assert iphone_accessibility["ready"] is True
    assert iphone_accessibility["supports_audio_descriptions"] is False
    assert iphone_accessibility["supports_captions"] is False
    for field in [
        "supports_dark_interface",
        "supports_differentiate_without_color_alone",
        "supports_larger_text",
        "supports_reduced_motion",
        "supports_sufficient_contrast",
        "supports_voice_control",
        "supports_voiceover",
    ]:
        assert iphone_accessibility[field] is True
    assert not any("export compliance" in step.lower() for step in manual_steps)
    assert (
        "urls.support is still marked as not ready for App Store submission."
        not in warnings
    )
    assert not any(warning.startswith("urls.") for warning in warnings)
    assert "review.contact is still marked as not ready for submission." in warnings
    assert (
        "privacy.app_store_connect_completed must be true after the App Privacy questionnaire is completed in App Store Connect."
        in warnings
    )
    assert (
        "SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS must be NOT_MEDICAL_DEVICE after the App Store Connect medical-device status is set."
        in warnings
    )


def test_validator_accepts_submission_ready_manifest() -> None:
    manifest = current_manifest()

    errors, warnings = validator.validate_manifest(manifest, allow_draft=False)

    assert errors == []
    assert warnings == []


def test_validator_requires_complete_weatherkit_positive_review_notes() -> None:
    manifest = current_manifest()
    manifest["review"]["notes"] = "Sunclub uses WeatherKit for live UV."

    errors, warnings = validator.validate_manifest(manifest, allow_draft=False)

    assert validator.WEATHERKIT_POSITIVE_DETAIL_ERROR in errors
    assert warnings == []


def test_validator_rejects_submission_automation_shape_errors() -> None:
    manifest = current_manifest()
    manifest["privacy"]["app_store_connect_completed"] = "yes"
    manifest["assets"]["screenshots"]["display_type"] = "APP_IPHONE_65"
    manifest["submission"]["release_type"] = "AUTO"
    manifest["accessibility"]["iphone"]["ready"] = True
    del manifest["accessibility"]["iphone"]["supports_voiceover"]
    manifest["accessibility"]["iphone"]["supports_larger_text"] = "sometimes"

    errors, warnings = validator.validate_manifest(manifest, allow_draft=False)

    assert (
        "privacy.app_store_connect_completed must be true after the App Privacy questionnaire is completed in App Store Connect."
        in errors
    )
    assert "assets.screenshots.display_type must be one of ['APP_IPHONE_67']." in errors
    assert (
        "submission.release_type must be one of ['AFTER_APPROVAL', 'MANUAL', 'SCHEDULED']."
        in errors
    )
    assert "accessibility.iphone.supports_larger_text must be a boolean." in errors
    assert (
        "accessibility.iphone.supports_voiceover is required when accessibility.iphone.ready is true."
        in errors
    )
    assert warnings == []


def test_manifest_resolver_overlays_review_contact_from_env() -> None:
    manifest = current_manifest()

    assert manifest["review"]["contact"] == {
        "first_name": "Peyton",
        "last_name": "Randolph",
        "email": "review@example.com",
        "phone": "+1-415-555-0100",
    }
    assert manifest["privacy"]["app_store_connect_completed"] is True
    assert (
        manifest["regulatory"]["regulated_medical_device"]["app_store_connect_value"]
        == "NOT_MEDICAL_DEVICE"
    )


def test_strict_validation_requires_privacy_and_medical_gates() -> None:
    env = {
        key: value
        for key, value in READY_ENV.items()
        if key
        not in {
            "SUNCLUB_APP_PRIVACY_COMPLETED",
            "SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS",
        }
    }
    manifest = current_manifest(environment=env)

    errors, warnings = validator.validate_manifest(manifest, allow_draft=False)

    assert (
        "privacy.app_store_connect_completed must be true after the App Privacy questionnaire is completed in App Store Connect."
        in errors
    )
    assert (
        "SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS must be NOT_MEDICAL_DEVICE after the App Store Connect medical-device status is set."
        in errors
    )
    assert warnings == []


def test_public_cloudkit_transport_requires_conservative_privacy_answers() -> None:
    manifest = current_manifest()
    manifest["privacy"]["public_cloudkit_accountability_transport"] = True
    manifest["attestations"]["public_cloudkit_accountability_transport_enabled"] = True

    errors, _warnings = validator.validate_manifest(manifest, allow_draft=False)

    assert (
        "Public CloudKit accountability transport requires conservative App Privacy data-collection answers, not privacy.data_collection='none'."
        in errors
    )
    assert (
        "attestations.public_cloudkit_accountability_transport_enabled must be False for the first submission."
        in errors
    )
