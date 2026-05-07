from __future__ import annotations

import json
import re

from conftest import REPO_ROOT


LEDGER_PATTERN = re.compile(r"^- \[x\] \[(?P<category>[^\]]+)\] \d{3}\. ", re.MULTILINE)


def test_product_redesign_completion_ledger_has_required_polish_counts() -> None:
    execplan = (REPO_ROOT / "docs/product-page-app-redesign-execplan.md").read_text(
        encoding="utf-8"
    )
    categories = LEDGER_PATTERN.findall(execplan)

    assert len(categories) >= 100
    assert categories.count("Settings") >= 20
    assert categories.count("Tab/Nav") >= 15
    assert categories.count("Manual Log/Art") >= 15
    assert categories.count("Home/UV") >= 15
    assert categories.count("History/Insights") >= 15
    assert categories.count("Privacy/Support/Automation") >= 10
    assert categories.count("Accessibility/Watch/Widget/Dark Mode") >= 10


def test_coverage_face_diagram_imageset_has_real_scaled_outputs() -> None:
    imageset = (
        REPO_ROOT / "app/Sunclub/Resources/Assets.xcassets/CoverageFaceDiagram.imageset"
    )
    contents = json.loads((imageset / "Contents.json").read_text(encoding="utf-8"))

    assert contents["images"] == [
        {
            "filename": "CoverageFaceDiagram.png",
            "idiom": "universal",
            "scale": "1x",
        },
        {
            "filename": "CoverageFaceDiagram@2x.png",
            "idiom": "universal",
            "scale": "2x",
        },
        {
            "filename": "CoverageFaceDiagram@3x.png",
            "idiom": "universal",
            "scale": "3x",
        },
    ]
    assert (imageset / "CoverageFaceDiagram.png").stat().st_size > 0
    assert (imageset / "CoverageFaceDiagram@2x.png").stat().st_size > 0
    assert (imageset / "CoverageFaceDiagram@3x.png").stat().st_size > 0


def test_design_asset_importer_stays_dependency_free_and_validates_resolution() -> None:
    script = (REPO_ROOT / "scripts/art/import_design_asset.py").read_text(
        encoding="utf-8"
    )

    assert "from PIL" not in script
    assert "import cv2" not in script
    assert '["sips",' in script
    assert "need at least" in script
    assert "Contents.json" in script


def test_coverage_art_is_wired_through_visual_asset_enum() -> None:
    app_theme = (REPO_ROOT / "app/Sunclub/Sources/Shared/AppTheme.swift").read_text(
        encoding="utf-8"
    )
    manual_fields = (
        REPO_ROOT / "app/Sunclub/Sources/Shared/SunManualLogFields.swift"
    ).read_text(encoding="utf-8")

    assert 'case coverageFaceDiagram = "CoverageFaceDiagram"' in app_theme
    assert "SunclubVisualAsset.coverageFaceDiagram.image" in manual_fields
    assert "Canvas" not in manual_fields
