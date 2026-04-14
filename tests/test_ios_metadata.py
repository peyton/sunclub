import plistlib
import re
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INFO_PLIST = REPO_ROOT / "app" / "Sunclub" / "Info.plist"
APP_ENTITLEMENTS = REPO_ROOT / "app" / "Sunclub" / "Sunclub.entitlements"
PRIVACY_MANIFEST = REPO_ROOT / "app" / "Sunclub" / "Resources" / "PrivacyInfo.xcprivacy"
PROJECT_SWIFT = REPO_ROOT / "app" / "Sunclub" / "Project.swift"
APP_ENTITLEMENTS = REPO_ROOT / "app" / "Sunclub" / "Sunclub.entitlements"
SOURCES_DIR = REPO_ROOT / "app" / "Sunclub" / "Sources"
RELEASE_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "release-testflight.yml"
ARCHIVE_SCRIPT = REPO_ROOT / "scripts" / "appstore" / "archive-and-upload.sh"
RESOLVE_ENTITLEMENTS = REPO_ROOT / "scripts" / "appstore" / "resolve_entitlements.py"


def load_info_plist() -> dict:
    with INFO_PLIST.open("rb") as plist_file:
        return plistlib.load(plist_file)


def load_app_entitlements() -> dict:
    with APP_ENTITLEMENTS.open("rb") as plist_file:
        return plistlib.load(plist_file)


def test_main_target_uses_checked_in_info_plist() -> None:
    source = PROJECT_SWIFT.read_text()

    assert "func appTarget(for flavor: SunclubFlavor) -> Target {" in source
    assert 'infoPlist: .file(path: "Info.plist")' in source


def test_project_reads_signing_team_from_team_id_env() -> None:
    source = PROJECT_SWIFT.read_text()

    assert (
        'let signingTeam = Environment.teamId.getString(default: "3VDQ4656LX")'
        in source
    )


def test_project_reads_versioning_from_tuist_manifest_environment() -> None:
    source = PROJECT_SWIFT.read_text()

    assert (
        'let marketingVersion = Environment.sunclubMarketingVersion.getString(default: "1.0.0")'
        in source
    )
    assert (
        'let buildNumber = Environment.sunclubBuildNumber.getString(default: "1")'
        in source
    )


def test_remote_notification_background_mode_has_push_entitlement() -> None:
    info = load_info_plist()
    entitlements = load_app_entitlements()
    source = PROJECT_SWIFT.read_text()

    assert "remote-notification" in info["UIBackgroundModes"]
    assert entitlements["aps-environment"] == "$(SUNCLUB_APS_ENVIRONMENT)"
    assert (
        'let apsEnvironment = Environment.sunclubApsEnvironment.getString(default: "development")'
        in source
    )
    assert '"SUNCLUB_APS_ENVIRONMENT": .string(apsEnvironment)' in source


def test_info_plist_declares_background_task_and_backup_document_type() -> None:
    info = load_info_plist()

    assert (
        "com.peyton.sunclub.weekly-report"
        in info["BGTaskSchedulerPermittedIdentifiers"]
    )

    exported_types = info["UTExportedTypeDeclarations"]
    backup_type = next(
        item
        for item in exported_types
        if item["UTTypeIdentifier"] == "app.peyton.sunclub.backup"
    )
    assert backup_type["UTTypeConformsTo"] == ["public.json"]
    assert backup_type["UTTypeDescription"] == "Sunclub Backup"

    document_types = info["CFBundleDocumentTypes"]
    backup_document_type = next(
        item
        for item in document_types
        if "app.peyton.sunclub.backup" in item["LSItemContentTypes"]
    )
    assert backup_document_type["CFBundleTypeRole"] == "Editor"
    assert backup_document_type["LSHandlerRank"] == "Owner"


def test_info_plist_declares_explicit_file_opening_behavior() -> None:
    info = load_info_plist()

    assert info["LSSupportsOpeningDocumentsInPlace"] is False


def test_info_plist_declares_no_non_exempt_encryption() -> None:
    info = load_info_plist()

    assert info["ITSAppUsesNonExemptEncryption"] is False


def test_info_plist_declares_log_today_home_screen_quick_action() -> None:
    info = load_info_plist()

    quick_action = next(
        item
        for item in info["UIApplicationShortcutItems"]
        if item["UIApplicationShortcutItemType"] == "app.peyton.sunclub.log-today"
    )
    assert quick_action["UIApplicationShortcutItemTitle"] == "Log Today"
    assert quick_action["UIApplicationShortcutItemIconSymbolName"] == "sun.max.fill"


def test_app_entitlements_enable_weatherkit_for_live_uv() -> None:
    entitlements = load_app_entitlements()

    assert entitlements["com.apple.developer.weatherkit"] is True


def test_info_plist_explains_location_use_for_live_uv() -> None:
    info = load_info_plist()

    assert "NSLocationWhenInUseUsageDescription" in info
    assert "live UV" in info["NSLocationWhenInUseUsageDescription"]


def test_widget_extension_inherits_app_version_metadata() -> None:
    source = PROJECT_SWIFT.read_text()

    assert "func widgetTarget(for flavor: SunclubFlavor) -> Target {" in source
    assert '"CFBundleDisplayName": "$(SUNCLUB_DISPLAY_NAME)"' in source
    assert '"CFBundleShortVersionString": "$(MARKETING_VERSION)"' in source
    assert '"CFBundleVersion": "$(SUNCLUB_BUILD_NUMBER)"' in source


def test_project_uses_tuist_version_helpers_and_explicit_bundle_build_number() -> None:
    source = PROJECT_SWIFT.read_text()

    assert ".marketingVersion(marketingVersion)" in source
    assert ".currentProjectVersion(currentProjectVersion)" in source
    assert 'base["SUNCLUB_BUILD_NUMBER"] = .string(buildNumber)' in source


def test_project_declares_prod_and_dev_flavors() -> None:
    source = PROJECT_SWIFT.read_text()

    assert 'bundleID: "app.peyton.sunclub"' in source
    assert 'widgetBundleID: "app.peyton.sunclub.widgets"' in source
    assert 'bundleID: "app.peyton.sunclub.dev"' in source
    assert 'widgetBundleID: "app.peyton.sunclub.dev.widgets"' in source
    assert 'appGroupID: "group.app.peyton.sunclub.dev"' in source
    assert 'cloudKitContainerIdentifier: "iCloud.app.peyton.sunclub.dev"' in source


def test_targets_do_not_override_automatic_signing_identity() -> None:
    source = PROJECT_SWIFT.read_text()

    assert ".automaticCodeSigning(devTeam: signingTeam)" in source
    assert "releaseSigningSettings" not in source
    assert "codeSignIdentity" not in source
    assert "CODE_SIGN_IDENTITY" not in source


def test_project_test_targets_follow_production_flavor_contract() -> None:
    source = PROJECT_SWIFT.read_text()

    assert source.count(".target(name: productionFlavor.appTargetName)") == 2
    assert source.count(".settings(base: flavorBuildSettings(productionFlavor))") == 2


def test_tests_plist_uses_resolved_version_placeholders() -> None:
    tests_plist = (REPO_ROOT / "app" / "Sunclub" / "Tests.plist").read_text()

    assert "$(MARKETING_VERSION)" in tests_plist
    assert "$(SUNCLUB_BUILD_NUMBER)" in tests_plist
    assert ">1.0<" not in tests_plist


def test_release_workflow_pins_supported_stable_xcode_and_tag_trigger() -> None:
    workflow = RELEASE_WORKFLOW.read_text()

    assert '- "v*.*.*"' in workflow
    assert 'xcode-version: "26.3"' in workflow
    assert "environment: testflight" in workflow
    assert 'echo "SUNCLUB_APS_ENVIRONMENT=production"' in workflow
    assert 'SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE: "1"' in workflow
    assert "mise exec -- just test-unit" in workflow
    assert (
        "bash scripts/appstore/archive-and-upload.sh --allow-draft-metadata --unsigned-archive --upload-testflight"
        in workflow
    )
    assert "--unsigned-archive" in workflow
    assert "if: always()" in workflow
    assert "retention-days: 90" in workflow
    assert ".build/release-diagnostics" in workflow


def test_resolve_entitlements_replaces_xcode_placeholders(tmp_path: Path) -> None:
    source = tmp_path / "Source.entitlements"
    output = tmp_path / "Resolved.entitlements"
    with source.open("wb") as source_file:
        plistlib.dump(
            {
                "aps-environment": "$(SUNCLUB_APS_ENVIRONMENT)",
                "com.apple.developer.icloud-container-identifiers": [
                    "$(SUNCLUB_ICLOUD_CONTAINER)",
                ],
                "com.apple.security.application-groups": [
                    "$(SUNCLUB_APP_GROUP_ID)",
                ],
            },
            source_file,
        )

    subprocess.run(
        [
            sys.executable,
            str(RESOLVE_ENTITLEMENTS),
            "--source",
            str(source),
            "--output",
            str(output),
            "--set",
            "SUNCLUB_APS_ENVIRONMENT=production",
            "--set",
            "SUNCLUB_ICLOUD_CONTAINER=iCloud.app.peyton.sunclub",
            "--set",
            "SUNCLUB_APP_GROUP_ID=group.app.peyton.sunclub",
        ],
        check=True,
    )

    with output.open("rb") as output_file:
        resolved = plistlib.load(output_file)

    assert resolved["aps-environment"] == "production"
    assert resolved["com.apple.developer.icloud-container-identifiers"] == [
        "iCloud.app.peyton.sunclub",
    ]
    assert resolved["com.apple.security.application-groups"] == [
        "group.app.peyton.sunclub",
    ]


def test_resolve_entitlements_rejects_unresolved_placeholders(tmp_path: Path) -> None:
    source = tmp_path / "Source.entitlements"
    output = tmp_path / "Resolved.entitlements"
    with source.open("wb") as source_file:
        plistlib.dump({"aps-environment": "$(SUNCLUB_APS_ENVIRONMENT)"}, source_file)

    result = subprocess.run(
        [
            sys.executable,
            str(RESOLVE_ENTITLEMENTS),
            "--source",
            str(source),
            "--output",
            str(output),
        ],
        check=False,
        text=True,
        capture_output=True,
    )

    assert result.returncode == 1
    assert "SUNCLUB_APS_ENVIRONMENT" in result.stderr
    assert not output.exists()


def test_archive_script_uses_app_store_connect_cli_auth() -> None:
    script = ARCHIVE_SCRIPT.read_text()
    archive_step = script.split('step "Archiving the signed release build"', 1)[
        1
    ].split('ok "Archive created', 1)[0]
    export_step = script.split('step "Exporting the App Store package"', 1)[1].split(
        'IPA_FILE="',
        1,
    )[0]

    assert "XCODEBUILD_AUTH_ARGS=(" in script
    assert "XCODEBUILD_ARCHIVE_PROVISIONING_ARGS=(" in script
    assert "-allowProvisioningUpdates" in script
    assert '"${XCODEBUILD_ARCHIVE_PROVISIONING_ARGS[@]}"' in archive_step
    assert 'xcodebuild "${xcodebuild_archive_args[@]}"' in archive_step
    assert '"${XCODEBUILD_AUTH_ARGS[@]}"' in script
    assert "XCODEBUILD_ARCHIVE_SIGNING_ARGS=(" in script
    assert "--unsigned-archive can only be used with --skip-export" not in script
    assert "write_ipa_entitlement_diagnostics" in script
    assert "adhoc_sign_archived_app_with_release_entitlements" in script
    assert "scripts.appstore.resolve_entitlements" in script
    assert "--generate-entitlement-der" in script
    assert "Unsigned archive export detected" not in script
    assert "Skipping signed app entitlement validation" not in script
    assert 'validate_signed_ipa_entitlements "$IPA_FILE"' in script
    assert "CODE_SIGNING_ALLOWED=NO" in script
    assert "CODE_SIGNING_REQUIRED=NO" in script
    assert "xcodebuild_export_args=(" in export_step
    assert "-exportArchive" in export_step
    assert "-allowProvisioningUpdates" in export_step
    assert '"${XCODEBUILD_AUTH_ARGS[@]}"' in export_step
    assert 'xcodebuild "${xcodebuild_export_args[@]}"' in export_step
    assert '-authenticationKeyPath "$ASC_KEY_FILE"' in script
    assert '-authenticationKeyID "$ASC_KEY_ID"' in script
    assert '-authenticationKeyIssuerID "$ASC_ISSUER_ID"' in script
    assert "SWIFT_ENABLE_COMPILE_CACHE=NO" in script
    assert "COMPILATION_CACHE_REMOTE_SERVICE_PATH=" in script
    assert "APPLE_TEAM_ID" not in script
    assert "CODE_SIGN_STYLE=Automatic" not in script
    assert "CODE_SIGN_IDENTITY" not in script
    assert ': "${SUNCLUB_APS_ENVIRONMENT:=production}"' in script
    assert '-exportPath "$EXPORT_OUTPUT_PATH"' in script
    assert "xcrun --find altool" in script
    assert "xcrun altool \\" in script
    assert '--upload-package "$IPA_FILE"' in script
    assert '--api-key "$ASC_KEY_ID"' in script
    assert '--api-issuer "$ASC_ISSUER_ID"' in script
    assert '--p8-file-path "$ASC_KEY_FILE"' in script
    assert "--wait \\" in script
    assert "PIPESTATUS[0]" in script
    assert "UPLOAD FAILED" in script
    assert "App Store Connect upload failed" in script
    assert "xcrun iTMSTransporter" in script
    assert '-apiKey "$ASC_KEY_ID"' in script
    assert '-apiIssuer "$ASC_ISSUER_ID"' in script
    assert "AuthKey_${ASC_KEY_ID}.p8" in script


# ---------------------------------------------------------------------------
# Privacy manifest (PrivacyInfo.xcprivacy)
# ---------------------------------------------------------------------------


def load_privacy_manifest() -> dict:
    with PRIVACY_MANIFEST.open("rb") as f:
        return plistlib.load(f)


def test_privacy_manifest_exists() -> None:
    assert PRIVACY_MANIFEST.exists(), (
        "PrivacyInfo.xcprivacy is missing — Apple rejects apps without a privacy manifest"
    )


def test_privacy_manifest_declares_no_tracking() -> None:
    manifest = load_privacy_manifest()

    assert manifest["NSPrivacyTracking"] is False


def test_privacy_manifest_declares_no_collected_data_types() -> None:
    manifest = load_privacy_manifest()

    assert manifest["NSPrivacyCollectedDataTypes"] == []


def test_privacy_manifest_declares_no_tracking_domains() -> None:
    manifest = load_privacy_manifest()

    assert manifest["NSPrivacyTrackingDomains"] == []


def test_privacy_manifest_declares_user_defaults_required_reason_api() -> None:
    manifest = load_privacy_manifest()

    api_types = manifest["NSPrivacyAccessedAPITypes"]
    user_defaults_entry = next(
        (
            entry
            for entry in api_types
            if entry["NSPrivacyAccessedAPIType"]
            == "NSPrivacyAccessedAPICategoryUserDefaults"
        ),
        None,
    )
    assert user_defaults_entry is not None, (
        "Privacy manifest must declare UserDefaults as a Required Reason API"
    )
    assert "CA92.1" in user_defaults_entry["NSPrivacyAccessedAPITypeReasons"]


def test_privacy_manifest_covers_all_source_user_defaults_usage() -> None:
    """If source code uses UserDefaults, the privacy manifest must declare it."""
    pattern = re.compile(r"\bUserDefaults\b")
    files_using_defaults = [
        p.relative_to(REPO_ROOT)
        for p in SOURCES_DIR.rglob("*.swift")
        if pattern.search(p.read_text())
    ]

    assert len(files_using_defaults) > 0, "Sanity: expected at least one file"

    manifest = load_privacy_manifest()
    declared_apis = {
        entry["NSPrivacyAccessedAPIType"]
        for entry in manifest["NSPrivacyAccessedAPITypes"]
    }
    assert "NSPrivacyAccessedAPICategoryUserDefaults" in declared_apis, (
        f"Source files use UserDefaults ({files_using_defaults}) but the privacy "
        "manifest does not declare NSPrivacyAccessedAPICategoryUserDefaults"
    )


def test_privacy_manifest_included_in_app_resources_glob() -> None:
    source = PROJECT_SWIFT.read_text()

    assert '"Resources/**"' in source, (
        "App target must include Resources/** so PrivacyInfo.xcprivacy is bundled"
    )


# ---------------------------------------------------------------------------
# Info.plist: no empty or invalid string values
# ---------------------------------------------------------------------------


def test_info_plist_has_no_empty_string_values() -> None:
    info = load_info_plist()

    empty_keys = [
        key for key, value in info.items() if isinstance(value, str) and value == ""
    ]
    assert empty_keys == [], (
        f"Info.plist has empty string values for keys: {empty_keys}"
    )
