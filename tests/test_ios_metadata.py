import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

from scripts.appstore.release_doctor import (
    BUNDLE_SUFFIXES,
    REQUIRED_CAPABILITIES,
    DoctorContext,
    expected_profile_entitlements,
)

REPO_ROOT = Path(__file__).resolve().parents[1]
INFO_PLIST = REPO_ROOT / "app" / "Sunclub" / "Info.plist"
APP_ENTITLEMENTS = REPO_ROOT / "app" / "Sunclub" / "Sunclub.entitlements"
WIDGET_ENTITLEMENTS = (
    REPO_ROOT / "app" / "Sunclub" / "SunclubWidgetsExtension.entitlements"
)
WATCH_ENTITLEMENTS = REPO_ROOT / "app" / "Sunclub" / "SunclubWatch.entitlements"
WATCH_WIDGET_ENTITLEMENTS = (
    REPO_ROOT / "app" / "Sunclub" / "SunclubWatchWidgets.entitlements"
)
PRIVACY_MANIFEST = REPO_ROOT / "app" / "Sunclub" / "Resources" / "PrivacyInfo.xcprivacy"
PROJECT_SWIFT = REPO_ROOT / "app" / "Sunclub" / "Project.swift"
WIDGETS_SWIFT = (
    REPO_ROOT
    / "app"
    / "Sunclub"
    / "WidgetExtension"
    / "Sources"
    / "SunclubWidgets.swift"
)
SOURCES_DIR = REPO_ROOT / "app" / "Sunclub" / "Sources"
CI_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "ci.yml"
RELEASE_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "release-testflight.yml"
SUBMIT_APP_REVIEW_WORKFLOW = (
    REPO_ROOT / ".github" / "workflows" / "submit-app-review.yml"
)
IOS_XCODE_WORKFLOWS = (
    CI_WORKFLOW,
    RELEASE_WORKFLOW,
    SUBMIT_APP_REVIEW_WORKFLOW,
)
ARCHIVE_SCRIPT = REPO_ROOT / "scripts" / "appstore" / "archive-and-upload.sh"
RESOLVE_ENTITLEMENTS = REPO_ROOT / "scripts" / "appstore" / "resolve_entitlements.py"
APP_ICONSET = (
    REPO_ROOT
    / "app"
    / "Sunclub"
    / "Resources"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
)
WATCH_APP_ICONSET = (
    REPO_ROOT
    / "app"
    / "Sunclub"
    / "WatchApp"
    / "Resources"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
)


def load_info_plist() -> dict:
    with INFO_PLIST.open("rb") as plist_file:
        return plistlib.load(plist_file)


def load_app_entitlements() -> dict:
    with APP_ENTITLEMENTS.open("rb") as plist_file:
        return plistlib.load(plist_file)


def load_entitlements(path: Path) -> dict:
    with path.open("rb") as plist_file:
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


def test_release_doctor_covers_all_production_bundle_ids() -> None:
    assert BUNDLE_SUFFIXES == {
        "main app": "",
        "widget extension": ".widgets",
        "watch app": ".watch",
        "watch widget extension": ".watch.widgets",
    }


def test_release_doctor_requires_weatherkit_for_the_main_app_id() -> None:
    assert REQUIRED_CAPABILITIES["WEATHERKIT"] == "WeatherKit capability"
    assert REQUIRED_CAPABILITIES["WEATHER_KIT"] == "WeatherKit App Service"


def test_release_doctor_uses_target_entitlement_templates() -> None:
    ctx = DoctorContext(flavor="prod")

    main_entitlements = expected_profile_entitlements(ctx, "main app")
    widget_entitlements = expected_profile_entitlements(ctx, "widget extension")
    watch_entitlements = expected_profile_entitlements(
        ctx,
        "watch app",
    )

    assert main_entitlements["aps-environment"] == "production"
    assert main_entitlements["com.apple.developer.icloud-container-identifiers"] == [
        "iCloud.app.peyton.sunclub"
    ]
    assert main_entitlements["com.apple.security.application-groups"] == [
        "group.app.peyton.sunclub"
    ]
    assert widget_entitlements == {
        "com.apple.security.application-groups": ["group.app.peyton.sunclub"]
    }
    assert watch_entitlements == {
        "com.apple.security.application-groups": ["group.app.peyton.sunclub"]
    }
    assert main_entitlements["com.apple.developer.weatherkit"] is True


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


def test_info_plist_declares_copyright_owner() -> None:
    info = load_info_plist()

    assert (
        info["NSHumanReadableCopyright"]
        == "Copyright © 2026 Peyton Randolph. All rights reserved."
    )


def test_public_accountability_transport_disabled_for_all_flavors() -> None:
    info = load_info_plist()
    source = PROJECT_SWIFT.read_text()

    assert (
        info["SunclubPublicAccountabilityTransportEnabled"]
        == "$(SUNCLUB_PUBLIC_ACCOUNTABILITY_TRANSPORT_ENABLED)"
    )
    assert "let publicAccountabilityTransportEnabled: Bool" in source
    assert "publicAccountabilityTransportEnabled: true" not in source
    assert source.count("publicAccountabilityTransportEnabled: false") == 2
    assert 'flavor.publicAccountabilityTransportEnabled ? "YES" : "NO"' in source
    assert "SunclubPublicAccountabilityTransportEnabled" in source


def test_info_plist_declares_log_today_home_screen_quick_action() -> None:
    info = load_info_plist()

    quick_action = next(
        item
        for item in info["UIApplicationShortcutItems"]
        if item["UIApplicationShortcutItemType"] == "app.peyton.sunclub.log-today"
    )
    assert quick_action["UIApplicationShortcutItemTitle"] == "Log sunscreen"
    assert quick_action["UIApplicationShortcutItemSubtitle"] == "Open Today"
    assert quick_action["UIApplicationShortcutItemIconSymbolName"] == "sun.max.fill"


def test_support_email_uses_mail_subdomain() -> None:
    links = (SOURCES_DIR / "Shared" / "SunclubWebLinks.swift").read_text()

    assert (
        'static let supportEmail = URL(string: "mailto:support@mail.sunclub.peyton.app")!'
        in links
    )
    for stale_address in (
        "sunclub@peyton.app",
        "support@sunclub.peyton.app",
    ):
        assert stale_address not in links


def test_app_entitlements_enable_weatherkit_for_live_uv_forecast() -> None:
    entitlements = load_app_entitlements()

    assert entitlements.get("com.apple.developer.weatherkit") is True


def test_weatherkit_entitlement_is_main_app_only() -> None:
    app_entitlements = load_entitlements(APP_ENTITLEMENTS)
    extension_entitlements = [
        load_entitlements(path)
        for path in (WIDGET_ENTITLEMENTS, WATCH_ENTITLEMENTS, WATCH_WIDGET_ENTITLEMENTS)
    ]

    assert app_entitlements.get("com.apple.developer.weatherkit") is True
    for entitlements in extension_entitlements:
        assert "com.apple.developer.weatherkit" not in entitlements


def test_info_plist_explains_location_use_for_leave_home_reminders() -> None:
    info = load_info_plist()

    assert "NSLocationWhenInUseUsageDescription" in info
    assert "leave-home reminders" in info["NSLocationWhenInUseUsageDescription"]


def test_widget_extension_inherits_app_version_metadata() -> None:
    source = PROJECT_SWIFT.read_text()

    assert "func widgetTarget(for flavor: SunclubFlavor) -> Target {" in source
    assert '"CFBundleDisplayName": "$(SUNCLUB_DISPLAY_NAME)"' in source
    assert '"CFBundleShortVersionString": "$(MARKETING_VERSION)"' in source
    assert '"CFBundleVersion": "$(SUNCLUB_BUILD_NUMBER)"' in source


def expanded_source_groups(source: str, target: str) -> str:
    for name, body in re.findall(
        r"let (\w+): \[SourceFileGlob\] = \[(.*?)^\]", source, re.MULTILINE | re.DOTALL
    ):
        if re.search(rf"\b{name}\b", target):
            target += "\n" + body
    return target


def test_widget_extension_compiles_manual_log_input_dependencies() -> None:
    source = PROJECT_SWIFT.read_text()
    widget_target = source.split(
        "func widgetTarget(for flavor: SunclubFlavor) -> Target {", 1
    )[1].split("func watchAppTarget(for flavor: SunclubFlavor) -> Target {", 1)[0]

    widget_target = expanded_source_groups(source, widget_target)
    assert '"Sources/Services/SunclubMutationService.swift"' in widget_target
    assert '"Sources/Services/SunclubAutomationRuntime.swift"' in widget_target
    assert '"Sources/Services/ManualLogSuggestions.swift"' in widget_target
    assert '"Sources/Shared/SunManualLogInput.swift"' in widget_target


def test_widget_keeps_shipped_families_and_separates_logging_from_navigation() -> None:
    source = WIDGETS_SWIFT.read_text()
    expected_families = {
        "SunclubLogTodayWidget": {
            "systemSmall",
            "systemMedium",
            "systemLarge",
            "systemExtraLarge",
            "accessoryCircular",
            "accessoryRectangular",
        },
        "SunclubStreakWidget": {
            "systemSmall",
            "systemMedium",
            "accessoryCircular",
            "accessoryRectangular",
        },
        "SunclubStatsWidget": {
            "systemMedium",
            "systemLarge",
            "accessoryInline",
            "accessoryRectangular",
        },
        "SunclubCalendarWidget": {
            "systemMedium",
            "systemLarge",
            "accessoryInline",
            "accessoryRectangular",
        },
        "SunclubAccountabilityWidget": {
            "systemSmall",
            "systemMedium",
            "systemLarge",
            "systemExtraLarge",
            "accessoryInline",
            "accessoryCircular",
            "accessoryRectangular",
        },
    }
    for kind, expected in expected_families.items():
        widget_source = source.split(f"struct {kind}: Widget {{", 1)[1]
        family_list = widget_source.split(".supportedFamilies([", 1)[1].split("])", 1)[
            0
        ]
        assert set(re.findall(r"\.(\w+)", family_list)) == expected

    assert "Button(intent: LogSunscreenWidgetIntent())" in source
    assert "Link(destination: SunclubWidgetRoute.today.url)" in source
    assert ".widgetURL(SunclubWidgetRoute.today.url)" in source
    for kind in (
        "SunclubLogTodayWidget",
        "SunclubStreakWidget",
        "SunclubStatsWidget",
        "SunclubCalendarWidget",
        "SunclubAccountabilityWidget",
    ):
        assert f'widgetKind("{kind}")' in source


def test_widget_extension_avoids_large_bitmap_backgrounds() -> None:
    source = WIDGETS_SWIFT.read_text()

    assert 'Image("WidgetTexture' not in source
    assert 'Image("Motif' not in source


def test_project_embeds_watch_app_in_release_app() -> None:
    source = PROJECT_SWIFT.read_text()
    app_target = source.split(
        "func appTarget(for flavor: SunclubFlavor) -> Target {", 1
    )[1].split("func widgetTarget(for flavor: SunclubFlavor) -> Target {", 1)[0]

    assert ".target(name: flavor.watchTargetName)" in app_target


def test_watch_targets_compile_shared_snapshot_model_dependencies() -> None:
    source = PROJECT_SWIFT.read_text()
    watch_app_target = source.split(
        "func watchAppTarget(for flavor: SunclubFlavor) -> Target {", 1
    )[1].split("func watchWidgetTarget(for flavor: SunclubFlavor) -> Target {", 1)[0]
    watch_widget_target = source.split(
        "func watchWidgetTarget(for flavor: SunclubFlavor) -> Target {", 1
    )[1].split("let project = Project(", 1)[0]

    for target_source in (watch_app_target, watch_widget_target):
        target_source = expanded_source_groups(source, target_source)
        assert '"Sources/Models/AccountabilityModels.swift"' in target_source
        assert '"Sources/Models/VerificationMethod.swift"' in target_source
        assert '"Sources/WidgetSupport/SunclubWidgetSupport.swift"' in target_source


def test_single_target_watch_app_owns_watch_sources_and_metadata() -> None:
    source = PROJECT_SWIFT.read_text()
    watch_app_target = source.split(
        "func watchAppTarget(for flavor: SunclubFlavor) -> Target {", 1
    )[1].split("func watchWidgetTarget(for flavor: SunclubFlavor) -> Target {", 1)[0]

    assert "product: .app" in watch_app_target
    assert "sources: [" in watch_app_target
    assert '"WatchApp/Sources/**"' in watch_app_target
    assert 'entitlements: "SunclubWatch.entitlements"' in watch_app_target
    assert ".target(name: flavor.watchWidgetTargetName)" in watch_app_target
    for runtime_key in (
        "SunclubAppGroupID",
        "SunclubICloudContainerIdentifier",
        "SunclubPublicAccountabilityTransportEnabled",
        "SunclubURLScheme",
    ):
        assert f'"{runtime_key}"' in watch_app_target

    for legacy_marker in (
        ".watch2Extension",
        ".watch2AppContainer",
        "watchExtensionTargetName",
        "watchContainerTargetName",
        "watchExtensionBundleID",
        "watchContainerBundleID",
    ):
        assert legacy_marker not in source

    for legacy_marker in ("NSExtensionPointIdentifier", "WKAppBundleIdentifier"):
        assert legacy_marker not in watch_app_target


def test_watch_app_target_uses_app_store_safe_metadata_and_icons() -> None:
    source = PROJECT_SWIFT.read_text()
    watch_app_target = source.split(
        "func watchAppTarget(for flavor: SunclubFlavor) -> Target {", 1
    )[1].split("func watchWidgetTarget(for flavor: SunclubFlavor) -> Target {", 1)[0]

    assert (
        '"CFBundleShortVersionString": .string("$(MARKETING_VERSION)")'
        in watch_app_target
    )
    assert '"CFBundleVersion": .string("$(SUNCLUB_BUILD_NUMBER)")' in watch_app_target
    assert (
        '"WKCompanionAppBundleIdentifier": .string(flavor.bundleID)' in watch_app_target
    )
    assert '"WKApplication": .boolean(true)' in watch_app_target
    assert '"WatchApp/Resources/**"' in watch_app_target

    for required_key in (
        "SunclubAppGroupID",
        "SunclubICloudContainerIdentifier",
        "SunclubPublicAccountabilityTransportEnabled",
        "SunclubURLScheme",
    ):
        assert required_key in watch_app_target

    for invalid_key in (
        "CFBundleIconName",
        "CFBundleURLTypes",
        "NSExtension",
        "WKAppBundleIdentifier",
    ):
        assert invalid_key not in watch_app_target


def test_ios_app_icons_do_not_contain_alpha_channels() -> None:
    contents = json.loads((APP_ICONSET / "Contents.json").read_text())

    for image in contents["images"]:
        icon = APP_ICONSET / image["filename"]
        png_header = icon.read_bytes()[:26]

        assert png_header.startswith(b"\x89PNG\r\n\x1a\n")
        assert png_header[24] == 8
        assert png_header[25] == 2


def test_watch_app_iconset_declares_watchos_icon_asset() -> None:
    icon = WATCH_APP_ICONSET / "watch-appicon.png"
    contents_json = WATCH_APP_ICONSET / "Contents.json"

    assert icon.exists()
    assert contents_json.exists()

    contents = json.loads(contents_json.read_text())
    assert contents["images"] == [
        {
            "filename": "watch-appicon.png",
            "idiom": "universal",
            "platform": "watchos",
            "size": "1024x1024",
        },
    ]


def test_watch_asset_catalog_declares_accent_color() -> None:
    accent_path = WATCH_APP_ICONSET.parent / "AccentColor.colorset" / "Contents.json"

    assert accent_path.exists()
    contents = json.loads(accent_path.read_text())
    assert contents["info"] == {"author": "xcode", "version": 1}
    assert contents["colors"]
    assert contents["colors"][0]["idiom"] == "universal"
    assert contents["colors"][0]["color"]["color-space"] == "srgb"


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


def test_ci_workflow_pins_supported_stable_xcode_for_ios_jobs() -> None:
    workflow = CI_WORKFLOW.read_text()
    assert workflow.count("runs-on: macos-26") == 3
    assert workflow.count('xcode: "true"') == 3
    assert "name: iOS Unit Tests" in workflow
    assert "name: iOS UI Tests" in workflow
    assert "name: Build iOS (${{ matrix.name }})" in workflow
    assert "flavor: dev" in workflow and "flavor: prod" in workflow
    assert "TEST_APP_SCHEME: Sunclub" in workflow
    assert "just test-unit" in workflow and 'just ci-build "$BUILD_FLAVOR"' in workflow
    assert "timeout-minutes: 45" in workflow
    assert "SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE" not in workflow


def test_ci_workflow_skips_ios_jobs_only_for_known_web_surface_changes() -> None:
    workflow = CI_WORKFLOW.read_text()
    assert "python3 -m scripts.tooling.ci_policy changes" in workflow
    assert "github.event.pull_request.base.sha" in workflow
    assert "github.event.pull_request.head.sha" in workflow
    assert "workflow_dispatch:" in workflow
    assert "if: always()" in workflow
    assert (
        "needs: [changes, lint, test-python, test-ios-unit, test-ios-ui, build-ios]"
        in workflow
    )
    assert "NEEDS_JSON: ${{ toJSON(needs) }}" in workflow
    assert "python3 -m scripts.tooling.ci_policy gate" in workflow
    assert "just test-ui-smoke" in workflow and "just test-ui" in workflow
    assert "if: github.event_name == 'pull_request'" in workflow
    assert "if: github.event_name != 'pull_request'" in workflow
    assert "needs: lint" not in workflow


def test_ci_workflow_restores_repo_local_caches_without_build_artifacts() -> None:
    setup = (REPO_ROOT / ".github/actions/setup/action.yml").read_text()
    assert "install_args: --locked" in setup
    assert "setup_local_tooling_env" in setup
    assert "actions/cache@27d5ce7f107fe9357f9df03efb73ab90386fccae" in setup
    for directory in [".cache/uv", ".cache/npm", ".cache/hk", ".cache/swiftlint"]:
        assert directory in setup
    assert ".DerivedData" not in setup and ".venv" not in setup
    assert "${{ runner.os }}-${{ runner.arch }}" in setup


def test_ios_workflows_share_single_xcode_version_pin() -> None:
    setup = (REPO_ROOT / ".github/actions/setup/action.yml").read_text()
    assert 'SUNCLUB_XCODE_VERSION: "26.4"' in setup
    assert "sudo xcode-select -s" in setup
    assert "scripts/tooling/prepare_ci_workspace.sh" in setup
    for workflow_path in IOS_XCODE_WORKFLOWS:
        workflow = workflow_path.read_text()
        assert "uses: ./.github/actions/setup" in workflow
        assert 'xcode: "true"' in workflow
        assert "SUNCLUB_XCODE_VERSION:" not in workflow
        assert "runs-on: macos-26" in workflow


def test_release_workflow_pins_supported_stable_xcode_and_tag_trigger() -> None:
    workflow = RELEASE_WORKFLOW.read_text()
    release_safety_step = re.search(
        r"- name: Run release launch safety tests\n"
        r"(?P<body>(?:        .*\n)+?)"
        r"\n      - name: Archive and export production app",
        workflow,
    )
    archive_upload_step = re.search(
        r"- name: Archive and export production app\n"
        r"(?P<body>(?:        .*\n)+?)"
        r"\n      - name: Add Internal testers group",
        workflow,
    )
    internal_group_step = re.search(
        r"- name: Add Internal testers group\n"
        r"(?P<body>(?:        .*\n)+?)"
        r"\n      - name: Upload release artifacts",
        workflow,
    )

    assert '- "v*.*.*"' in workflow
    assert "uses: ./.github/actions/setup" in workflow
    assert 'xcode: "true"' in workflow
    assert "scripts.tooling.ci_policy require-release" in workflow
    assert "actions: read" in workflow
    assert "environment: testflight" in workflow
    assert 'echo "SUNCLUB_APS_ENVIRONMENT=production"' in workflow
    assert release_safety_step is not None
    release_safety_body = release_safety_step.group("body")
    assert "timeout-minutes: 45" in release_safety_body
    assert (
        "_".join(  # noqa: FLY002
            ("SUNCLUB", "DISABLE", "SWIFT", "COMPILE", "CACHE")
        )
        not in release_safety_body
    )
    assert "mise --locked exec -- just test-unit" in release_safety_body
    assert archive_upload_step is not None
    archive_upload_body = archive_upload_step.group("body")
    assert "timeout-minutes: 90" in archive_upload_body
    assert (
        "_".join(  # noqa: FLY002
            ("SUNCLUB", "DISABLE", "SWIFT", "COMPILE", "CACHE")
        )
        not in archive_upload_body
    )
    assert (
        'bash scripts/appstore/archive-and-upload.sh "${archive_args[@]}"'
        in archive_upload_body
    )
    assert "--unsigned-archive" in workflow
    assert internal_group_step is not None
    internal_group_body = internal_group_step.group("body")
    assert "timeout-minutes: 60" in internal_group_body
    assert "python -m scripts.appstore.testflight_groups --group Internal" in (
        internal_group_body
    )
    assert "if: always()" in workflow
    assert "retention-days: 90" in workflow
    assert ".build/release-diagnostics" in workflow


def test_submit_app_review_workflow_bounds_xcode_heavy_steps() -> None:
    workflow = SUBMIT_APP_REVIEW_WORKFLOW.read_text()
    screenshot_step = re.search(
        r"- name: Capture App Store screenshots\n"
        r"(?P<body>(?:        .*\n)+?)"
        r"\n      - name: Write App Review checkpoint",
        workflow,
    )
    archive_upload_step = re.search(
        r"- name: Archive and upload to TestFlight\n"
        r"(?P<body>(?:        .*\n)+?)"
        r"\n      - name: Prepare draft App Review submission",
        workflow,
    )
    draft_step = re.search(
        r"- name: Prepare draft App Review submission\n"
        r"(?P<body>(?:        .*\n)+?)"
        r"\n      - name: Submit app for review",
        workflow,
    )
    submit_step = re.search(
        r"- name: Submit app for review\n"
        r"(?P<body>(?:        .*\n)+?)$",
        workflow,
    )

    assert "uses: ./.github/actions/setup" in workflow
    assert 'xcode: "true"' in workflow
    assert "scripts.tooling.ci_policy require-release" in workflow
    assert "actions: read" in workflow
    assert "environment: app-store-review" in workflow
    assert (
        "_".join(  # noqa: FLY002
            ("SUNCLUB", "DISABLE", "SWIFT", "COMPILE", "CACHE")
        )
        not in workflow
    )

    assert screenshot_step is not None
    screenshot_body = screenshot_step.group("body")
    assert "timeout-minutes: 45" in screenshot_body
    assert "mise --locked exec -- just appstore-screenshots" in screenshot_body

    assert archive_upload_step is not None
    archive_upload_body = archive_upload_step.group("body")
    assert "timeout-minutes: 90" in archive_upload_body
    assert (
        "_".join(  # noqa: FLY002
            ("SUNCLUB", "DISABLE", "SWIFT", "COMPILE", "CACHE")
        )
        not in archive_upload_body
    )
    assert (
        "bash scripts/appstore/archive-and-upload.sh --allow-draft-metadata --unsigned-archive --upload-testflight"
        in archive_upload_body
    )
    assert "--unsigned-archive" in archive_upload_body

    assert draft_step is not None
    draft_body = draft_step.group("body")
    assert "timeout-minutes: 30" in draft_body
    assert "bash scripts/appstore/submit-review.sh --draft" in draft_body
    assert "--skip-screenshots --skip-archive-upload" in draft_body

    assert submit_step is not None
    submit_body = submit_step.group("body")
    assert "timeout-minutes: 30" in submit_body
    assert "bash scripts/appstore/submit-review.sh --submit" in submit_body


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


def test_resolve_entitlements_rejects_placeholders_introduced_by_replacements(
    tmp_path: Path,
) -> None:
    source = tmp_path / "Source.entitlements"
    output = tmp_path / "Resolved.entitlements"
    with source.open("wb") as source_file:
        plistlib.dump({"aps-environment": "$(A)"}, source_file)

    result = subprocess.run(
        [
            sys.executable,
            str(RESOLVE_ENTITLEMENTS),
            "--source",
            str(source),
            "--output",
            str(output),
            "--set",
            "A=$(B)",
        ],
        check=False,
        text=True,
        capture_output=True,
    )

    assert result.returncode == 1
    assert "B" in result.stderr
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
    profile_step = script.split('step "Preparing App Store provisioning profiles"', 1)[
        1
    ].split('step "Exporting the App Store package"', 1)[0]

    assert "XCODEBUILD_AUTH_ARGS=(" in script
    assert "XCODEBUILD_ARCHIVE_PROVISIONING_ARGS=(" in script
    assert "-allowProvisioningUpdates" in script
    assert '"${XCODEBUILD_ARCHIVE_PROVISIONING_ARGS[@]}"' in archive_step
    assert 'run_tuist_xcodebuild "${xcodebuild_archive_args[@]}"' in archive_step
    assert '"${XCODEBUILD_AUTH_ARGS[@]}"' in script
    assert "XCODEBUILD_ARCHIVE_SIGNING_ARGS=(" in script
    assert "resolve_repo_path() {" in script
    assert 'ARCHIVE_OUTPUT_PATH="$(resolve_repo_path "$ARCHIVE_PATH")"' in script
    assert 'EXPORT_OUTPUT_PATH="$(resolve_repo_path "$EXPORT_PATH")"' in script
    assert "--unsigned-archive can only be used with --skip-export" not in script
    assert "write_ipa_entitlement_diagnostics" in script
    assert "adhoc_sign_archived_app_with_release_entitlements" in script
    assert "REGISTER_APP_GROUPS=YES" in script
    assert "validate_signed_ipa_nested_bundle_identifiers" in script
    assert "prepare_app_store_provisioning_profiles" in script
    assert "scripts.appstore.provisioning_profiles" in script
    assert "scripts.appstore.resolve_entitlements" in script
    assert "--generate-entitlement-der" in script
    assert '--identifier "$bundle_id"' in script
    assert "Unsigned archive export detected" not in script
    assert "Skipping signed app entitlement validation" not in script
    assert 'validate_signed_ipa_entitlements "$IPA_FILE"' in script
    assert 'validate_signed_ipa_nested_bundle_identifiers "$IPA_FILE"' in script
    assert 'validate_signed_ipa_watch_bundle "$IPA_FILE"' in script
    assert 'codesign -d --entitlements :- "$watch_app_path"' in script
    assert "watch_entitlements_path=" in script
    assert "legacy_watch_extension_path=" in script
    assert "legacy WatchKit extension" in script
    assert "assert_codesign_identifier_matches_bundle" in script
    assert "WatchKit stub code-signing identifier com.apple.WK" in script
    assert 'Print :CFBundleShortVersionString" "$signed_app_path/Info.plist"' in script
    assert 'Print :CFBundleVersion" "$signed_app_path/Info.plist"' in script
    assert (
        'assert_info_plist_string "$watch_info_path" "CFBundleShortVersionString" "$main_marketing_version"'
        in script
    )
    assert (
        'assert_info_plist_string "$watch_info_path" "CFBundleVersion" "$main_build_number"'
        in script
    )
    assert (
        '"${RELEASE_APP_PRODUCT_NAME}Watch.app") entitlements_path="$watch_entitlements_path" ;;'
        in script
    )
    assert '"${RELEASE_APP_PRODUCT_NAME}WatchExtension.appex"' not in script
    assert '"${RELEASE_APP_PRODUCT_NAME}WatchWidgetsExtension.appex"' in script
    assert (
        "$RELEASE_APP_PRODUCT_NAME Watch app is missing compiled icon assets" in script
    )
    assert 'assert_plist_key_absent "$watch_info_path" "CFBundleIconName"' in script
    assert "CFBundleURLTypes" in script
    for runtime_key in (
        "SunclubAppGroupID",
        "SunclubICloudContainerIdentifier",
        "SunclubPublicAccountabilityTransportEnabled",
        "SunclubURLScheme",
    ):
        assert (
            f'assert_plist_key_absent "$watch_info_path" "{runtime_key}"' not in script
        )
    assert "CODE_SIGNING_ALLOWED=NO" in script
    assert "CODE_SIGNING_REQUIRED=NO" in script
    assert "prepare_app_store_provisioning_profiles" in profile_step
    assert '--archive-path "$ARCHIVE_OUTPUT_PATH"' in script
    assert '--app-name "$RELEASE_APP_PRODUCT_NAME"' in script
    assert "--create-missing" in script
    assert "--install" in script
    assert "provisioning-profiles.json" in script
    assert 'rm -rf "$RELEASE_DIAGNOSTICS_PATH"' not in script
    assert "xcodebuild_export_args=(" in export_step
    assert "-exportArchive" in export_step
    assert "-allowProvisioningUpdates" in export_step
    assert '"${XCODEBUILD_AUTH_ARGS[@]}"' in export_step
    assert 'xcodebuild "${xcodebuild_export_args[@]}"' in export_step
    assert 'tuist xcodebuild "${xcodebuild_export_args[@]}"' not in export_step
    assert '-authenticationKeyPath "$ASC_KEY_FILE"' in script
    assert '-authenticationKeyID "$ASC_KEY_ID"' in script
    assert '-authenticationKeyIssuerID "$ASC_ISSUER_ID"' in script
    assert (
        "_".join(  # noqa: FLY002
            ("SWIFT", "ENABLE", "COMPILE", "CACHE")
        )
        + "=NO"
        not in script
    )
    assert (
        "_".join(  # noqa: FLY002
            ("COMPILATION", "CACHE", "REMOTE", "SERVICE", "PATH")
        )
        + "="
        not in script
    )
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


def test_release_scripts_set_production_defaults_before_shared_environment() -> None:
    for relative_path in (
        "scripts/appstore/archive-and-upload.sh",
        "scripts/appstore/submit-review.sh",
    ):
        script = (REPO_ROOT / relative_path).read_text()
        shared_environment = script.index(
            'source "$ROOT_DIR/scripts/tooling/common.sh"'
        )

        assert script.index(': "${SUNCLUB_FLAVOR:=prod}"') < shared_environment
        assert (
            script.index(': "${SUNCLUB_APS_ENVIRONMENT:=production}"')
            < shared_environment
        )


def test_foreground_reminders_wait_for_uv_refresh() -> None:
    source = (SOURCES_DIR / "SunclubApp.swift").read_text()
    foreground_refresh = source.split("private func refreshAppStateForForeground()", 1)[
        1
    ].split("private func refreshReminderScheduleIfNeeded", 1)[0]
    reminder_refresh = source.split("private func refreshReminderScheduleIfNeeded", 1)[
        1
    ].split("private func handleIncomingURL", 1)[0]

    assert (
        "let uvRefreshTask = appState.refreshUVForecastIfNeeded()" in foreground_refresh
    )
    assert "refreshReminderScheduleIfNeeded(after: uvRefreshTask)" in foreground_refresh
    assert "await uvRefreshTask.value" in reminder_refresh


def test_archive_script_writes_diagnostics_for_every_nested_bundle() -> None:
    script = ARCHIVE_SCRIPT.read_text()
    diagnostics_function = script.split("write_ipa_entitlement_diagnostics() {", 1)[
        1
    ].split("\n}\n\n[ -f", 1)[0]
    nested_validation_function = script.split(
        "validate_signed_ipa_nested_bundle_identifiers() {",
        1,
    )[1].split("\n}\n\nresolve_release_entitlements", 1)[0]

    assert 'find "$signed_app_path"' in diagnostics_function
    assert "-mindepth 2" in diagnostics_function
    assert "\\( -name '*.app' -o -name '*.appex' \\)" in diagnostics_function
    assert 'find "$signed_app_path/PlugIns"' not in diagnostics_function
    assert 'nested_diagnostic_stem="${nested_bundle_path#"$signed_app_path"/}"' in (
        diagnostics_function
    )
    assert (
        "Could not write entitlement diagnostics for $nested_diagnostic_stem"
        in diagnostics_function
    )
    assert 'codesign -d --entitlements :- "$nested_bundle_path"' in (
        diagnostics_function
    )

    assert 'find "$signed_app_path"' in nested_validation_function
    assert "\\( -name '*.app' -o -name '*.appex' \\)" in nested_validation_function
    assert (
        'assert_codesign_identifier_matches_bundle "$nested_bundle_path" "$nested_label"'
        in nested_validation_function
    )


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


def test_privacy_manifest_declares_no_collected_data() -> None:
    manifest = load_privacy_manifest()
    assert manifest["NSPrivacyCollectedDataTypes"] == []


def test_public_cloudkit_database_usage_is_guarded_by_transport_flag() -> None:
    app_state = "\n".join(
        path.read_text() for path in (SOURCES_DIR / "Services").rglob("*.swift")
    )
    runtime_config = (
        SOURCES_DIR / "Shared" / "SunclubRuntimeConfiguration.swift"
    ).read_text()
    service = (
        SOURCES_DIR / "Services" / "SunclubAccountabilityService.swift"
    ).read_text()
    files_with_public_database = [
        path.relative_to(REPO_ROOT).as_posix()
        for path in SOURCES_DIR.rglob("*.swift")
        if "publicCloudDatabase" in path.read_text()
    ]

    assert files_with_public_database == [
        "app/Sunclub/Sources/Services/SunclubAccountabilityService.swift"
    ]
    assert "isPublicAccountabilityTransportEnabled" in runtime_config
    assert "if !runtimeEnvironment.isPublicAccountabilityTransportEnabled" in app_state
    assert "return NoopSunclubAccountabilityService()" in app_state
    assert "publicCloudDatabase" in service


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


def test_app_owned_logging_intents_run_in_app_process_without_opening_app():
    source = (
        REPO_ROOT / "app/Sunclub/Sources/Intents/LogSunscreenIntent.swift"
    ).read_text()
    for intent in ("LogSunscreenWidgetIntent", "LogReapplicationLiveActivityIntent"):
        declaration = f"struct {intent}: LiveActivityIntent {{"
        assert declaration in source
        body = source.split(declaration, 1)[1].split("\nstruct ", 1)[0]
        assert "static let openAppWhenRun = false" in body
