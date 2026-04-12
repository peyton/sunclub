import json
from pathlib import Path

from scripts.appstore import validate_metadata as validator


REPO_ROOT = Path(__file__).resolve().parents[1]


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


def test_validator_allows_current_manifest_in_draft_mode() -> None:
    manifest = validator.load_manifest(
        REPO_ROOT / "scripts" / "appstore" / "metadata.json"
    )
    manual_steps = manifest["submission"]["manual_steps"]

    errors, warnings = validator.validate_manifest(manifest, allow_draft=True)

    assert errors == []
    assert not any("export compliance" in step.lower() for step in manual_steps)
    assert (
        "urls.support is still marked as not ready for App Store submission."
        not in warnings
    )
    assert not any(warning.startswith("urls.") for warning in warnings)
    assert "review.contact is still marked as not ready for submission." in warnings


def test_validator_accepts_submission_ready_manifest() -> None:
    manifest = json.loads(
        """
        {
          "app": {
            "name": "Sunclub",
            "subtitle": "Daily SPF Habit Tracker",
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
              "description": "Sunclub helps users keep a sunscreen routine with manual logging, streaks, reminders, and weekly summaries.",
              "keywords": ["sunscreen","spf","habit","streak","reminder","daily","uv"],
              "promotional_text": "Build a steady sunscreen routine with reminders and quick logging.",
              "whats_new": "Initial release."
            }
          },
          "urls": {
            "support": { "value": "https://support.example.com/sunclub", "ready": true },
            "marketing": { "value": "https://www.example.com/sunclub", "ready": true },
            "privacy_policy": { "value": "https://www.example.com/privacy", "ready": true }
          },
          "review": {
            "contact": {
              "first_name": "Peyton",
              "last_name": "Randolph",
              "email": "review@example.com",
              "phone": "+1-415-555-0100",
              "ready": true
            },
            "demo_account_required": false,
            "demo_account_notes": "No account required.",
            "notes": "Reviewers can complete onboarding, log manually from Home, and open Weekly Summary and Settings.",
            "attachments": []
          },
          "privacy": {
            "tracking": false,
            "data_collection": "none",
            "notifications_usage_description": "Notifications remind the user to apply or reapply sunscreen."
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
            "manual_steps": ["Upload screenshots in App Store Connect."]
          }
        }
        """
    )

    errors, warnings = validator.validate_manifest(manifest, allow_draft=False)

    assert errors == []
    assert warnings == []
