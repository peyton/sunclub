import importlib.util
import json
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
VALIDATOR_PATH = REPO_ROOT / "scripts" / "appstore" / "validate_metadata.py"


def load_validator_module():
    spec = importlib.util.spec_from_file_location(
        "sunclub_appstore_validator", VALIDATOR_PATH
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load validator module from {VALIDATOR_PATH}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


validator = load_validator_module()


class AppStoreMetadataValidatorTests(unittest.TestCase):
    def test_validator_rejects_legacy_submission_problems(self) -> None:
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
                "supports_on_demand_resources": true
              },
              "localizations": {
                "en-US": {
                  "description": "Fully Offline. No network connection needed. Premium subscription unlocks extra features.",
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
                "camera_usage_description": "Camera access is used to verify sunscreen.",
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

        self.assertTrue(errors)
        self.assertFalse(warnings)
        self.assertIn("app.subtitle exceeds Apple’s 30-character limit.", errors)
        self.assertIn(
            "localizations.en-US.keywords exceeds Apple’s 100-byte limit.", errors
        )
        self.assertIn(
            "Metadata claims the app is fully offline even though camera verification depends on a one-time ODR download.",
            errors,
        )
        self.assertIn(
            "Metadata mentions subscriptions, premium access, or freemium copy while the release is free-only.",
            errors,
        )
        self.assertIn(
            "urls.support is still marked as not ready for App Store submission.",
            errors,
        )
        self.assertIn(
            "review.contact is still marked as not ready for submission.", errors
        )

    def test_validator_allows_current_manifest_in_draft_mode(self) -> None:
        manifest = validator.load_manifest(
            REPO_ROOT / "scripts" / "appstore" / "metadata.json"
        )

        errors, warnings = validator.validate_manifest(manifest, allow_draft=True)

        self.assertEqual(errors, [])
        self.assertIn(
            "urls.support is still marked as not ready for App Store submission.",
            warnings,
        )
        self.assertIn(
            "review.contact is still marked as not ready for submission.", warnings
        )

    def test_validator_accepts_submission_ready_manifest(self) -> None:
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
                "supports_on_demand_resources": true
              },
              "localizations": {
                "en-US": {
                  "description": "Sunclub helps users keep a sunscreen routine with manual logging, streaks, reminders, and camera verification after a one-time model download.",
                  "keywords": ["sunscreen","spf","habit","streak","reminder","daily","uv"],
                  "promotional_text": "Build a steady sunscreen routine with reminders and camera verification.",
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
                "notes": "Reviewers can log manually or download the verification model once from the Verify screen.",
                "attachments": []
              },
              "privacy": {
                "tracking": false,
                "data_collection": "none",
                "camera_usage_description": "Camera access is used to verify sunscreen before logging today.",
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

        self.assertEqual(errors, [])
        self.assertEqual(warnings, [])


if __name__ == "__main__":
    unittest.main()
