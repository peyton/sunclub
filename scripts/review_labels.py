#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent


def read_jsonl(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=ROOT / "manifests" / "test_manifest.jsonl")
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--seed", type=int, default=9)
    parser.add_argument("--out-image", type=Path, default=ROOT / "evals/benchmark" / "manual_review_contact_sheet.jpg")
    parser.add_argument("--out-samples", type=Path, default=ROOT / "evals/benchmark" / "manual_review_sample.jsonl")
    args = parser.parse_args()

    rows = read_jsonl(args.manifest)
    rng = random.Random(args.seed)
    sample = rng.sample(rows, k=min(args.count, len(rows)))

    thumb_size = (220, 220)
    cols = 4
    rows_count = (len(sample) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * 240, rows_count * 280), (248, 244, 235))
    draw = ImageDraw.Draw(canvas)

    for index, row in enumerate(sample):
        image = Image.open(row["image_path"]).convert("RGB")
        image.thumbnail(thumb_size)
        x = (index % cols) * 240 + 10
        y = (index // cols) * 280 + 10
        canvas.paste(image, (x, y))
        draw.text((x, y + 228), row["sample_id"], fill=(38, 44, 52))
        draw.text((x, y + 246), f"label={row['label']} slices={','.join(row['slice_names'])[:28]}", fill=(66, 72, 80))

    args.out_image.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.out_image, quality=92)

    with args.out_samples.open("w", encoding="utf-8") as handle:
        for row in sample:
            handle.write(json.dumps(row, sort_keys=True) + "\n")

    print(json.dumps({"sampled": len(sample), "contact_sheet": str(args.out_image)}))


if __name__ == "__main__":
    main()
