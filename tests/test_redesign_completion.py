from __future__ import annotations

import json
from pathlib import Path
import re
import shutil
import subprocess
import struct
import sys
import zlib

import pytest

from conftest import REPO_ROOT


LEDGER_PATTERN = re.compile(r"^- \[x\] \[(?P<category>[^\]]+)\] \d{3}\. ", re.MULTILINE)


def png_info(path: Path) -> tuple[int, int, int]:
    with path.open("rb") as handle:
        header = handle.read(29)
    assert header.startswith(b"\x89PNG\r\n\x1a\n")
    assert header[12:16] == b"IHDR"
    width, height = struct.unpack(">II", header[16:24])
    color_type = header[25]
    return width, height, color_type


def png_dimensions(path: Path) -> tuple[int, int]:
    width, height, _ = png_info(path)
    return width, height


def png_corner_alpha(path: Path) -> int:
    with path.open("rb") as handle:
        data = handle.read()

    offset = 8
    width = height = color_type = bit_depth = None
    idat = bytearray()
    while offset < len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        chunk_type = data[offset + 4 : offset + 8]
        chunk_data = data[offset + 8 : offset + 8 + length]
        offset += length + 12
        if chunk_type == b"IHDR":
            width, height = struct.unpack(">II", chunk_data[:8])
            bit_depth = chunk_data[8]
            color_type = chunk_data[9]
        elif chunk_type == b"IDAT":
            idat.extend(chunk_data)
        elif chunk_type == b"IEND":
            break

    assert width is not None
    assert height is not None
    assert bit_depth == 8
    assert color_type == 6

    channels = 4
    row_length = width * channels
    raw = zlib.decompress(bytes(idat))
    prior = [0] * row_length
    rows: list[list[int]] = []
    cursor = 0
    for _ in range(height):
        filter_type = raw[cursor]
        cursor += 1
        row = list(raw[cursor : cursor + row_length])
        cursor += row_length
        for index, value in enumerate(row):
            left = row[index - channels] if index >= channels else 0
            up = prior[index]
            upper_left = prior[index - channels] if index >= channels else 0
            if filter_type == 1:
                row[index] = (value + left) & 0xFF
            elif filter_type == 2:
                row[index] = (value + up) & 0xFF
            elif filter_type == 3:
                row[index] = (value + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                estimate = left + up - upper_left
                pa = abs(estimate - left)
                pb = abs(estimate - up)
                pc = abs(estimate - upper_left)
                predictor = (
                    left if pa <= pb and pa <= pc else up if pb <= pc else upper_left
                )
                row[index] = (value + predictor) & 0xFF
            else:
                assert filter_type == 0
        rows.append(row)
        prior = row

    return rows[0][3]


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
    assert png_dimensions(imageset / "CoverageFaceDiagram.png") == (300, 400)
    assert png_dimensions(imageset / "CoverageFaceDiagram@2x.png") == (600, 800)
    assert png_dimensions(imageset / "CoverageFaceDiagram@3x.png") == (900, 1200)
    assert png_info(imageset / "CoverageFaceDiagram.png")[2] == 6
    assert png_info(imageset / "CoverageFaceDiagram@2x.png")[2] == 6
    assert png_info(imageset / "CoverageFaceDiagram@3x.png")[2] == 6
    assert png_corner_alpha(imageset / "CoverageFaceDiagram.png") == 0


def test_coverage_face_diagram_source_is_high_resolution_png() -> None:
    source = REPO_ROOT / "scripts/art/sources/CoverageFaceDiagram.png"
    legacy_source = REPO_ROOT / "scripts/art/sources/CoverageFaceDiagram.svg"
    width, height, color_type = png_info(source)

    assert source.exists()
    assert width >= 900
    assert height >= 1200
    assert color_type == 6
    assert png_corner_alpha(source) == 0
    assert not legacy_source.exists()


def test_coverage_face_diagram_imageset_is_reproducible(tmp_path: Path) -> None:
    if shutil.which("sips") is None:
        pytest.skip("Coverage asset import uses macOS sips.")

    generated_catalog = tmp_path / "Assets.xcassets"
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "scripts.art.import_design_asset",
            "--catalog",
            str(generated_catalog),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )

    assert "Imported CoverageFaceDiagram" in result.stdout
    expected_imageset = (
        REPO_ROOT / "app/Sunclub/Resources/Assets.xcassets/CoverageFaceDiagram.imageset"
    )
    generated_imageset = generated_catalog / "CoverageFaceDiagram.imageset"
    for filename in (
        "Contents.json",
        "CoverageFaceDiagram.png",
        "CoverageFaceDiagram@2x.png",
        "CoverageFaceDiagram@3x.png",
    ):
        assert (generated_imageset / filename).read_bytes() == (
            expected_imageset / filename
        ).read_bytes()


def test_design_asset_importer_stays_dependency_free_and_validates_resolution() -> None:
    script = (REPO_ROOT / "scripts/art/import_design_asset.py").read_text(
        encoding="utf-8"
    )

    assert "from PIL" not in script
    assert "import cv2" not in script
    assert "CoverageFaceDiagram.png" in script
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
