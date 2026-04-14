from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
COPYRIGHT_NOTICE = "Copyright (c) 2026 Peyton Randolph. All rights reserved."
NO_PUBLIC_LICENSE = "No public license is granted."
RESTRICTED_ACTIONS = (
    "use",
    "copy",
    "modify",
    "compile",
    "package",
    "redistribute in source or binary",
    "sublicense",
    "App Store or any other marketplace",
    "modified or derivative works",
)


def normalized(value: str) -> str:
    return " ".join(value.split())


def test_repo_declares_all_rights_reserved_source_available_posture() -> None:
    license_text = (REPO_ROOT / "LICENSE").read_text(encoding="utf-8")
    notice_text = (REPO_ROOT / "NOTICE").read_text(encoding="utf-8")
    readme_text = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    app_readme_text = (REPO_ROOT / "app" / "README.md").read_text(encoding="utf-8")
    pyproject_text = (REPO_ROOT / "pyproject.toml").read_text(encoding="utf-8")

    assert "All Rights Reserved" in license_text
    assert COPYRIGHT_NOTICE in license_text
    assert COPYRIGHT_NOTICE in notice_text
    assert "source-available, not open source" in notice_text
    assert NO_PUBLIC_LICENSE in license_text
    assert NO_PUBLIC_LICENSE in notice_text
    assert "No trademark rights are granted" in normalized(notice_text)
    assert 'license = { file = "LICENSE" }' in pyproject_text

    for text in (license_text, readme_text, app_readme_text):
        compact_text = normalized(text)
        for action in RESTRICTED_ACTIONS:
            assert action in compact_text

    assert "must preserve this notice" in notice_text
    assert "All rights not expressly granted remain reserved" in notice_text


def test_app_store_metadata_preserves_content_ownership_note() -> None:
    metadata_text = (REPO_ROOT / "scripts" / "appstore" / "metadata.json").read_text(
        encoding="utf-8"
    )

    assert "owned by Peyton Randolph" in metadata_text
    assert "does not contain, show, or access third-party content" in metadata_text
