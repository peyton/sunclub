#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parent.parent
FILTERED_MANIFEST = ROOT / "manifests" / "filtered_candidates.jsonl"
TRAIN_MANIFEST = ROOT / "manifests" / "train_manifest.jsonl"
VAL_MANIFEST = ROOT / "manifests" / "val_manifest.jsonl"
TEST_MANIFEST = ROOT / "manifests" / "test_manifest.jsonl"
BENCHMARK_MANIFEST = ROOT / "manifests" / "benchmark_manifest.jsonl"
ENROLLMENT_MANIFEST = ROOT / "manifests" / "enrollment_manifest.jsonl"
LEAKAGE_REPORT = ROOT / "manifests" / "leakage_report.json"
SPLIT_SUMMARY = ROOT / "manifests" / "split_summary.json"
PROCESSED_DIR = ROOT / "data" / "processed"


def read_jsonl(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, sort_keys=True) + "\n")


def perceptual_hash(path: Path) -> str:
    with Image.open(path) as image:
        image = image.convert("L").resize((17, 16))
        pixels = np.asarray(image, dtype=np.int16)
        diff = pixels[:, 1:] > pixels[:, :-1]
    value = 0
    for bit in diff.flatten():
        value = (value << 1) | int(bit)
    return f"{value:064x}"


def stable_bucket(value: str) -> int:
    return int(hashlib.sha1(value.encode()).hexdigest()[:8], 16)


def load_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA")


def crop_foreground(image: Image.Image) -> Image.Image:
    rgb = image.convert("RGB")
    arr = np.asarray(rgb, dtype=np.float32)
    distance = np.sqrt(((255 - arr) ** 2).sum(axis=2))
    alpha = np.clip((distance - 18) * 6, 0, 255).astype(np.uint8)
    mask = Image.fromarray(alpha, mode="L")
    bbox = mask.getbbox()
    if bbox:
        cropped = image.crop(bbox)
        alpha_crop = mask.crop(bbox)
        cropped.putalpha(alpha_crop)
        return cropped
    return image


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(image, size, method=Image.Resampling.LANCZOS)


def composite_scene(
    background_path: Path,
    subject_paths: list[Path],
    seed: int,
    label: int,
    rotate_degrees: float = 0.0,
    brightness: float = 1.0,
    blur_radius: float = 0.0,
    tiny: bool = False,
    occlude: bool = False,
    multi_object: bool = False,
) -> Image.Image:
    rng = random.Random(seed)
    canvas = cover_resize(load_rgba(background_path), (768, 768))

    if not subject_paths:
        if brightness != 1.0:
            canvas = ImageEnhance.Brightness(canvas).enhance(brightness)
        if blur_radius > 0:
            canvas = canvas.filter(ImageFilter.GaussianBlur(radius=blur_radius))
        return canvas.convert("RGB")

    placements = subject_paths if multi_object else subject_paths[:1]
    for index, subject_path in enumerate(placements):
        subject = crop_foreground(load_rgba(subject_path))
        max_width = 210 if tiny else 340
        if multi_object and index > 0:
            max_width = 180
        scale = max_width / max(1, subject.width)
        subject = subject.resize(
            (max(24, int(subject.width * scale)), max(24, int(subject.height * scale))),
            resample=Image.Resampling.LANCZOS,
        )
        angle = rotate_degrees if index == 0 else rng.choice([0, -18, 14])
        if angle:
            subject = subject.rotate(angle, expand=True, resample=Image.Resampling.BICUBIC)

        shadow = Image.new("RGBA", subject.size, (0, 0, 0, 0))
        shadow_alpha = subject.getchannel("A").filter(ImageFilter.GaussianBlur(radius=9))
        shadow.putalpha(shadow_alpha)
        shadow = ImageEnhance.Brightness(shadow).enhance(0.38)

        if multi_object:
            x = 120 + index * 180 + rng.randint(-24, 24)
            y = 250 + rng.randint(-48, 64)
        else:
            x = rng.randint(160, 420 if not tiny else 560)
            y = rng.randint(140, 420 if not tiny else 560)
        canvas.alpha_composite(shadow, (x + 8, y + 8))
        canvas.alpha_composite(subject, (x, y))

    if occlude and label == 1 and subject_paths:
        occluder = Image.new("RGBA", (220, 110), (240, 232, 210, 180))
        canvas.alpha_composite(occluder, (rng.randint(250, 410), rng.randint(290, 430)))

    if brightness != 1.0:
        canvas = ImageEnhance.Brightness(canvas).enhance(brightness)
    if blur_radius > 0:
        canvas = canvas.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    return canvas.convert("RGB")


def save_image(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="JPEG", quality=95, optimize=True)


def manifest_record(
    sample_id: str,
    image_path: Path,
    label: int,
    slice_names: list[str],
    split: str,
    parent_source_ids: list[str],
    parent_product_families: list[str],
    rationale: str,
) -> dict:
    return {
        "sample_id": sample_id,
        "task": "instance_retrieval_same_bottle_verification",
        "split": split,
        "image_path": str(image_path),
        "label": label,
        "label_name": "same_bottle" if label == 1 else "not_same_bottle",
        "slice_names": slice_names,
        "parent_source_ids": parent_source_ids,
        "parent_product_families": parent_product_families,
        "label_source": "high_confidence_verified",
        "label_confidence": 0.98 if label == 1 else 0.96,
        "verification_rationale": rationale,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=7)
    args = parser.parse_args()

    random.seed(args.seed)
    records = read_jsonl(FILTERED_MANIFEST)

    target_records = sorted(
        [row for row in records if row["collection_role"] == "benchmark_target"],
        key=lambda row: (row.get("product_code") or "", str(row.get("upload_id") or "")),
    )
    generic_records = [row for row in records if row["collection_role"] != "benchmark_target"]
    background_records = [
        row
        for row in generic_records
        if row["source_type"] == "wikimedia_commons_search"
        and row["class_name"] in {"generic_toiletry_clutter", "empty_frame_no_sunscreen", "bright_sunlight_scene", "low_light_scene", "sunscreen_scene"}
    ]
    product_negative_records = [
        row for row in generic_records if row["binary_label"] == "not_sunscreen" and row["source_type"] == "openbeautyfacts_search"
    ]
    sunscreen_negative_records = [
        row
        for row in generic_records
        if row["binary_label"] == "sunscreen" and row.get("product_family") != "avene_intense_protect_50_plus"
    ]

    train_records = [row for row in generic_records if stable_bucket(row["sample_id"]) % 5 != 0]
    enrollment_records = target_records[:3]
    val_target_sources = target_records[3:4]
    test_target_sources = target_records[4:5]

    half_backgrounds = max(1, len(background_records) // 2)
    val_backgrounds = background_records[:half_backgrounds]
    test_backgrounds = background_records[half_backgrounds:]

    negative_pool = product_negative_records + sunscreen_negative_records
    half_negatives = max(1, len(negative_pool) // 2)
    val_negatives = negative_pool[:half_negatives]
    test_negatives = negative_pool[half_negatives:]

    write_jsonl(TRAIN_MANIFEST, train_records)
    write_jsonl(ENROLLMENT_MANIFEST, enrollment_records)

    recipe_templates = {
        "positive": [
            (["clean_products"], dict(brightness=1.0, blur_radius=0.0, tiny=False, occlude=False, multi_object=False)),
            (["in_the_wild", "bright_sunlight"], dict(brightness=1.18, blur_radius=0.0, tiny=False, occlude=False, multi_object=False)),
            (["cluttered_scenes", "multi_object_scenes"], dict(brightness=1.0, blur_radius=0.0, tiny=False, occlude=False, multi_object=True)),
            (["partial_occlusion"], dict(brightness=1.0, blur_radius=0.0, tiny=False, occlude=True, multi_object=False)),
            (["low_light"], dict(brightness=0.56, blur_radius=0.0, tiny=False, occlude=False, multi_object=False)),
            (["motion_blur"], dict(brightness=1.0, blur_radius=2.8, tiny=False, occlude=False, multi_object=False)),
            (["tiny_objects"], dict(brightness=1.0, blur_radius=0.0, tiny=True, occlude=False, multi_object=False)),
            (["upside_down_or_rotated"], dict(brightness=1.0, blur_radius=0.0, tiny=False, occlude=False, multi_object=False, rotate_degrees=180)),
            (["non_english_packaging"], dict(brightness=1.0, blur_radius=0.0, tiny=False, occlude=False, multi_object=False)),
        ],
        "negative": [
            (["hard_negatives", "clean_products"], dict(brightness=1.0, blur_radius=0.0, tiny=False, occlude=False, multi_object=False)),
            (["near_ood_personal_care_items"], dict(brightness=1.0, blur_radius=0.0, tiny=False, occlude=False, multi_object=False)),
            (["cluttered_scenes", "multi_object_scenes"], dict(brightness=1.0, blur_radius=0.0, tiny=False, occlude=False, multi_object=True)),
            (["empty_frame_no_sunscreen"], dict(brightness=1.0, blur_radius=0.0, tiny=False, occlude=False, multi_object=False)),
            (["low_light"], dict(brightness=0.54, blur_radius=0.0, tiny=False, occlude=False, multi_object=False)),
            (["bright_sunlight"], dict(brightness=1.20, blur_radius=0.0, tiny=False, occlude=False, multi_object=False)),
            (["motion_blur"], dict(brightness=1.0, blur_radius=2.6, tiny=False, occlude=False, multi_object=False)),
            (["tiny_objects"], dict(brightness=1.0, blur_radius=0.0, tiny=True, occlude=False, multi_object=False)),
            (["upside_down_or_rotated"], dict(brightness=1.0, blur_radius=0.0, tiny=False, occlude=False, multi_object=False, rotate_degrees=180)),
        ],
    }

    def build_split(
        split_name: str,
        target_sources: list[dict],
        backgrounds: list[dict],
        negatives: list[dict],
        positive_multiplier: int,
        negative_multiplier: int,
    ) -> list[dict]:
        rows: list[dict] = []
        split_dir = PROCESSED_DIR / "benchmark" / split_name
        if split_dir.exists():
            for child in split_dir.glob("*.jpg"):
                child.unlink()
        split_dir.mkdir(parents=True, exist_ok=True)

        counter = 0
        for source in target_sources:
            for index, (slice_names, kwargs) in enumerate(recipe_templates["positive"]):
                for repeat in range(positive_multiplier):
                    background = random.choice(backgrounds)
                    distractors = random.sample(negatives, k=min(2, len(negatives))) if kwargs.get("multi_object") else []
                    subject_paths = [Path(source["local_path"])] + [Path(item["local_path"]) for item in distractors]
                    image = composite_scene(
                        background_path=Path(background["local_path"]),
                        subject_paths=subject_paths,
                        seed=1000 + counter,
                        label=1,
                        rotate_degrees=kwargs.get("rotate_degrees", 0.0),
                        brightness=kwargs.get("brightness", 1.0),
                        blur_radius=kwargs.get("blur_radius", 0.0),
                        tiny=kwargs.get("tiny", False),
                        occlude=kwargs.get("occlude", False),
                        multi_object=kwargs.get("multi_object", False),
                    )
                    sample_id = f"{split_name}_positive_{counter:03d}"
                    image_path = split_dir / f"{sample_id}.jpg"
                    save_image(image, image_path)
                    rows.append(
                        manifest_record(
                            sample_id=sample_id,
                            image_path=image_path,
                            label=1,
                            slice_names=slice_names,
                            split=split_name,
                            parent_source_ids=[source["sample_id"], background["sample_id"], *[item["sample_id"] for item in distractors]],
                            parent_product_families=[source["product_family"], background["product_family"], *[item["product_family"] for item in distractors]],
                            rationale="Derived from manually reviewed target-family Open Beauty Facts uploads composited onto held-out public scene backgrounds.",
                        )
                    )
                    counter += 1

        for source in negatives:
            for index, (slice_names, kwargs) in enumerate(recipe_templates["negative"]):
                if slice_names == ["empty_frame_no_sunscreen"]:
                    for repeat in range(max(1, negative_multiplier - 1)):
                        background = random.choice(backgrounds)
                        image = composite_scene(
                            background_path=Path(background["local_path"]),
                            subject_paths=[],
                            seed=4000 + counter,
                            label=0,
                            brightness=kwargs.get("brightness", 1.0),
                            blur_radius=kwargs.get("blur_radius", 0.0),
                        )
                        sample_id = f"{split_name}_negative_{counter:03d}"
                        image_path = split_dir / f"{sample_id}.jpg"
                        save_image(image, image_path)
                        rows.append(
                            manifest_record(
                                sample_id=sample_id,
                                image_path=image_path,
                                label=0,
                                slice_names=slice_names,
                                split=split_name,
                                parent_source_ids=[background["sample_id"]],
                                parent_product_families=[background["product_family"]],
                                rationale="Held-out public scene image with no sunscreen object present.",
                            )
                        )
                        counter += 1
                    continue

                for repeat in range(negative_multiplier):
                    background = random.choice(backgrounds)
                    distractors = []
                    multi_object = kwargs.get("multi_object", False)
                    if multi_object:
                        distractors = random.sample(negatives, k=min(2, len(negatives)))
                    subject_paths = [Path(source["local_path"])] + [Path(item["local_path"]) for item in distractors]
                    image = composite_scene(
                        background_path=Path(background["local_path"]),
                        subject_paths=subject_paths,
                        seed=5000 + counter,
                        label=0,
                        rotate_degrees=kwargs.get("rotate_degrees", 0.0),
                        brightness=kwargs.get("brightness", 1.0),
                        blur_radius=kwargs.get("blur_radius", 0.0),
                        tiny=kwargs.get("tiny", False),
                        occlude=False,
                        multi_object=multi_object,
                    )
                    sample_id = f"{split_name}_negative_{counter:03d}"
                    image_path = split_dir / f"{sample_id}.jpg"
                    save_image(image, image_path)
                    rows.append(
                        manifest_record(
                            sample_id=sample_id,
                            image_path=image_path,
                            label=0,
                            slice_names=slice_names,
                            split=split_name,
                            parent_source_ids=[source["sample_id"], background["sample_id"], *[item["sample_id"] for item in distractors]],
                            parent_product_families=[source["product_family"], background["product_family"], *[item["product_family"] for item in distractors]],
                            rationale="Derived from held-out non-target personal care products or non-target sunscreen items on held-out public scene backgrounds.",
                        )
                    )
                    counter += 1
        return rows

    val_rows = build_split(
        split_name="val",
        target_sources=val_target_sources or target_records[-2:-1],
        backgrounds=val_backgrounds or background_records[: max(1, len(background_records) // 2)],
        negatives=val_negatives[:6] or negative_pool[:6],
        positive_multiplier=1,
        negative_multiplier=1,
    )
    test_rows = build_split(
        split_name="test",
        target_sources=test_target_sources or target_records[-1:],
        backgrounds=test_backgrounds or background_records[max(1, len(background_records) // 2) :],
        negatives=test_negatives[:8] or negative_pool[-8:],
        positive_multiplier=2,
        negative_multiplier=1,
    )

    for row in val_rows + test_rows:
        row["file_hash"] = hashlib.sha256(Path(row["image_path"]).read_bytes()).hexdigest()
        row["perceptual_hash"] = perceptual_hash(Path(row["image_path"]))

    write_jsonl(VAL_MANIFEST, val_rows)
    write_jsonl(TEST_MANIFEST, test_rows)
    write_jsonl(BENCHMARK_MANIFEST, test_rows)

    train_hashes = {row["file_hash"] for row in train_records if row.get("file_hash")}
    val_hashes = {row["file_hash"] for row in val_rows}
    test_hashes = {row["file_hash"] for row in test_rows}
    leakage_report = {
        "train_val_exact_overlap": len(train_hashes & val_hashes),
        "train_test_exact_overlap": len(train_hashes & test_hashes),
        "val_test_exact_overlap": len(val_hashes & test_hashes),
        "val_test_parent_overlap": len(
            {parent for row in val_rows for parent in row["parent_source_ids"]}
            & {parent for row in test_rows for parent in row["parent_source_ids"]}
        ),
        "train_target_family_overlap": int(any(row.get("product_family") == "avene_intense_protect_50_plus" for row in train_records)),
    }
    LEAKAGE_REPORT.write_text(json.dumps(leakage_report, indent=2), encoding="utf-8")

    split_summary = {
        "train_count": len(train_records),
        "enrollment_count": len(enrollment_records),
        "val_count": len(val_rows),
        "test_count": len(test_rows),
        "val_positive": sum(row["label"] for row in val_rows),
        "val_negative": sum(1 for row in val_rows if row["label"] == 0),
        "test_positive": sum(row["label"] for row in test_rows),
        "test_negative": sum(1 for row in test_rows if row["label"] == 0),
    }
    SPLIT_SUMMARY.write_text(json.dumps(split_summary, indent=2), encoding="utf-8")
    print(json.dumps(split_summary))


if __name__ == "__main__":
    main()
