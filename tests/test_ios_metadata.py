import plistlib
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INFO_PLIST = REPO_ROOT / "app" / "Sunclub" / "Info.plist"
PRIVACY_MANIFEST = REPO_ROOT / "app" / "Sunclub" / "Resources" / "PrivacyInfo.xcprivacy"
PROJECT_SWIFT = REPO_ROOT / "app" / "Sunclub" / "Project.swift"
SOURCES_DIR = REPO_ROOT / "app" / "Sunclub" / "Sources"
RELEASE_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "release-testflight.yml"
ARCHIVE_SCRIPT = REPO_ROOT / "scripts" / "appstore" / "archive-and-upload.sh"


def load_info_plist() -> dict:
    with INFO_PLIST.open("rb") as plist_file:
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
    assert 'SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE: "1"' in workflow
    assert (
        "bash scripts/appstore/archive-and-upload.sh --allow-draft-metadata --upload-testflight"
        in workflow
    )


def test_archive_script_uses_app_store_connect_cli_auth() -> None:
    script = ARCHIVE_SCRIPT.read_text()

    assert "XCODEBUILD_AUTH_ARGS=(" in script
    assert "-allowProvisioningUpdates \\" in script
    assert '-authenticationKeyPath "$ASC_KEY_FILE"' in script
    assert '-authenticationKeyID "$ASC_KEY_ID"' in script
    assert '-authenticationKeyIssuerID "$ASC_ISSUER_ID"' in script
    assert "SWIFT_ENABLE_COMPILE_CACHE=NO" in script
    assert "COMPILATION_CACHE_REMOTE_SERVICE_PATH=" in script
    assert '-exportPath "$EXPORT_OUTPUT_PATH" \\' in script
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
