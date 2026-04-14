from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
COPYRIGHT_NOTICE = "Copyright (c) 2026 Peyton Randolph. All rights reserved."
POLYFORM_LICENSE = "PolyForm Strict License 1.0.0"
RESTRICTED_ACTIONS = (
    "source redistribution",
    "binary redistribution",
    "public fork distribution",
    "App Store or other marketplace publication",
    "modified or derivative work",
)


def normalized(value: str) -> str:
    return " ".join(value.split())


def test_repo_declares_source_available_restricted_license() -> None:
    license_text = (REPO_ROOT / "LICENSE").read_text(encoding="utf-8")
    notice_text = (REPO_ROOT / "NOTICE").read_text(encoding="utf-8")
    readme_text = (REPO_ROOT / "README.md").read_text(encoding="utf-8")
    app_readme_text = (REPO_ROOT / "app" / "README.md").read_text(encoding="utf-8")
    pyproject_text = (REPO_ROOT / "pyproject.toml").read_text(encoding="utf-8")

    assert POLYFORM_LICENSE in license_text
    assert "polyformproject.org/licenses/strict/1.0.0" in license_text
    assert COPYRIGHT_NOTICE in notice_text
    assert "source-available, not open source" in notice_text
    assert "No trademark rights are granted" in notice_text
    assert 'license = { file = "LICENSE" }' in pyproject_text

    for text in (notice_text, readme_text, app_readme_text):
        compact_text = normalized(text)
        for action in RESTRICTED_ACTIONS:
            assert action in compact_text


def test_app_store_metadata_preserves_content_ownership_note() -> None:
    metadata_text = (REPO_ROOT / "scripts" / "appstore" / "metadata.json").read_text(
        encoding="utf-8"
    )

    assert "owned by Peyton Randolph" in metadata_text
    assert "does not contain, show, or access third-party content" in metadata_text
