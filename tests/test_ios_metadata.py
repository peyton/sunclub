import plistlib
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INFO_PLIST = REPO_ROOT / "app" / "Sunclub" / "Info.plist"
PROJECT_SWIFT = REPO_ROOT / "app" / "Sunclub" / "Project.swift"


def load_info_plist() -> dict:
    with INFO_PLIST.open("rb") as plist_file:
        return plistlib.load(plist_file)


def test_main_target_uses_checked_in_info_plist() -> None:
    source = PROJECT_SWIFT.read_text()

    assert re.search(
        r'\.target\(\s*name: "Sunclub".*?infoPlist: \.file\(path: "Info\.plist"\)',
        source,
        re.DOTALL,
    )


def test_project_reads_signing_team_from_team_id_env() -> None:
    source = PROJECT_SWIFT.read_text()

    assert (
        'let signingTeam = Environment.TEAM_ID.getString(default: "3VDQ4656LX")'
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

    assert re.search(
        r'name: "SunclubWidgetsExtension".*?"CFBundleShortVersionString": "\$\(MARKETING_VERSION\)".*?"CFBundleVersion": "\$\(CURRENT_PROJECT_VERSION\)"',
        source,
        re.DOTALL,
    )
