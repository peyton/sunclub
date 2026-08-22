"""Import approved design artwork into an Xcode imageset.

The script intentionally uses only Python's standard library plus macOS
`sips`, so visual asset processing stays repo-local and dependency-free.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = REPO_ROOT / "scripts/art/sources/CoverageFaceDiagram.png"
DEFAULT_ASSET_CATALOG = REPO_ROOT / "app/Sunclub/Resources/Assets.xcassets"


def run(command: list[str]) -> str:
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return result.stdout


def image_size(path: Path) -> tuple[int, int]:
    output = run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)])
    width: int | None = None
    height: int | None = None
    for line in output.splitlines():
        stripped = line.strip()
        if stripped.startswith("pixelWidth:"):
            width = int(stripped.split(":", 1)[1].strip())
        elif stripped.startswith("pixelHeight:"):
            height = int(stripped.split(":", 1)[1].strip())
    if width is None or height is None:
        raise RuntimeError(f"Could not read image dimensions for {path}")
    return width, height


def render_source(source: Path, workdir: Path) -> Path:
    if source.suffix.lower() == ".svg":
        rendered = workdir / f"{source.stem}.png"
        run(["sips", "-s", "format", "png", str(source), "--out", str(rendered)])
        return rendered
    if source.suffix.lower() == ".png":
        return source
    raise ValueError(f"Unsupported source format: {source.suffix}")


def resize_image(source: Path, destination: Path, width: int, height: int) -> None:
    run(["sips", "-z", str(height), str(width), str(source), "--out", str(destination)])


def contents_json(asset_name: str) -> dict[str, object]:
    return {
        "images": [
            {"filename": f"{asset_name}.png", "idiom": "universal", "scale": "1x"},
            {"filename": f"{asset_name}@2x.png", "idiom": "universal", "scale": "2x"},
            {"filename": f"{asset_name}@3x.png", "idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }


def import_asset(
    source: Path, catalog: Path, asset_name: str, width: int, height: int
) -> None:
    source = source.resolve()
    catalog = catalog.resolve()
    imageset = catalog / f"{asset_name}.imageset"

    with tempfile.TemporaryDirectory(prefix="sunclub-design-asset-") as tmp:
        rendered_source = render_source(source, Path(tmp))
        source_width, source_height = image_size(rendered_source)
        required_width = width * 3
        required_height = height * 3
        if source_width < required_width or source_height < required_height:
            raise ValueError(
                f"{source} rendered at {source_width}x{source_height}; "
                f"need at least {required_width}x{required_height} for {asset_name}@3x"
            )

        if imageset.exists():
            shutil.rmtree(imageset)
        imageset.mkdir(parents=True)

        for scale in (1, 2, 3):
            suffix = "" if scale == 1 else f"@{scale}x"
            resize_image(
                rendered_source,
                imageset / f"{asset_name}{suffix}.png",
                width * scale,
                height * scale,
            )

        (imageset / "Contents.json").write_text(
            json.dumps(contents_json(asset_name), indent=2) + "\n",
            encoding="utf-8",
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_ASSET_CATALOG)
    parser.add_argument("--asset-name", default="CoverageFaceDiagram")
    parser.add_argument("--width", type=int, default=300)
    parser.add_argument("--height", type=int, default=400)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    import_asset(args.source, args.catalog, args.asset_name, args.width, args.height)
    print(f"Imported {args.asset_name}")


if __name__ == "__main__":
    main()
