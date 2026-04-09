import plistlib
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INFO_PLIST = REPO_ROOT / "app" / "Sunclub" / "Info.plist"
PROJECT_SWIFT = REPO_ROOT / "app" / "Sunclub" / "Project.swift"
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


def test_widget_extension_inherits_app_version_metadata() -> None:
    source = PROJECT_SWIFT.read_text()

    assert "func widgetTarget(for flavor: SunclubFlavor) -> Target {" in source
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
    assert "xcrun iTMSTransporter" in script
    assert '-apiKey "$ASC_KEY_ID"' in script
    assert '-apiIssuer "$ASC_ISSUER_ID"' in script
    assert "AuthKey_${ASC_KEY_ID}.p8" in script
