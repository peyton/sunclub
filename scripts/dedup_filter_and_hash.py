#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RAW_MANIFEST = ROOT / "manifests" / "raw_candidates.jsonl"
FILTERED_MANIFEST = ROOT / "manifests" / "filtered_candidates.jsonl"
REVIEW_QUEUE = ROOT / "manifests" / "review_queue.jsonl"
DEDUP_LOG = ROOT / "manifests" / "dedup_log.jsonl"


def read_jsonl(path: Path) -> list[dict]:
    items: list[dict] = []
    if not path.exists():
        return items
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                items.append(json.loads(line))
    return items


def write_jsonl(path: Path, rows: list[dict]) -> None:
    def to_builtin(value):
        if isinstance(value, np.generic):
            return value.item()
        if isinstance(value, dict):
            return {key: to_builtin(inner) for key, inner in value.items()}
        if isinstance(value, list):
            return [to_builtin(inner) for inner in value]
        return value

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(to_builtin(row), sort_keys=True) + "\n")


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def dhash(image: Image.Image, hash_size: int = 16) -> str:
    grayscale = image.convert("L").resize((hash_size + 1, hash_size))
    pixels = np.asarray(grayscale, dtype=np.int16)
    diff = pixels[:, 1:] > pixels[:, :-1]
    value = 0
    for bit in diff.flatten():
        value = (value << 1) | int(bit)
    return f"{value:0{hash_size * hash_size // 4}x}"


def hamming_distance(lhs: str, rhs: str) -> int:
    return bin(int(lhs, 16) ^ int(rhs, 16)).count("1")


def tiny_embedding(image: Image.Image) -> np.ndarray:
    small = image.convert("L").resize((32, 32))
    vector = np.asarray(small, dtype=np.float32).flatten()
    vector -= vector.mean()
    norm = np.linalg.norm(vector)
    if norm == 0:
        return vector
    return vector / norm


def cosine_similarity(lhs: np.ndarray, rhs: np.ndarray) -> float:
    denom = float(np.linalg.norm(lhs) * np.linalg.norm(rhs))
    if denom == 0:
        return 0.0
    return float(np.dot(lhs, rhs) / denom)


def watermark_suspected(image: Image.Image) -> bool:
    arr = np.asarray(image.convert("L").resize((96, 96)), dtype=np.float32)
    border = np.concatenate([arr[0], arr[-1], arr[:, 0], arr[:, -1]])
    center = arr[24:72, 24:72].flatten()
    return abs(border.mean() - center.mean()) > 42 and border.std() > 55


def confidence_for(record: dict) -> float:
    if record["collection_role"] == "benchmark_target":
        return 0.99
    if record["source_type"] == "openbeautyfacts_search":
        return 0.86
    if record["source_type"] == "wikimedia_commons_search":
        return 0.67
    return 0.6


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--min-side", type=int, default=180)
    args = parser.parse_args()

    records = read_jsonl(RAW_MANIFEST)
    kept: list[dict] = []
    review: list[dict] = []
    dedup_log: list[dict] = []
    seen_hashes: dict[str, str] = {}
    embeddings: list[tuple[dict, np.ndarray]] = []

    for record in records:
        path = Path(record["local_path"])
        if not path.exists():
            continue
        try:
            with Image.open(path) as image:
                image = image.convert("RGB")
                width, height = image.size
                record["width"] = width
                record["height"] = height
                if min(width, height) < args.min_side:
                    record["discard_reason"] = "tiny_image"
                    dedup_log.append(record)
                    continue
                record["file_hash"] = file_sha256(path)
                record["perceptual_hash"] = dhash(image)
                record["watermark_suspected"] = watermark_suspected(image)
                embedding = tiny_embedding(image)
        except Exception:
            record["discard_reason"] = "corrupt_image"
            dedup_log.append(record)
            continue

        duplicate_of = None
        if record["file_hash"] in seen_hashes:
            duplicate_of = seen_hashes[record["file_hash"]]
            record["discard_reason"] = "exact_hash_duplicate"
        else:
            for existing_record, existing_embedding in embeddings:
                same_group = (
                    existing_record.get("product_family") == record.get("product_family")
                    or existing_record.get("page_url") == record.get("page_url")
                    or (
                        existing_record.get("class_name") == record.get("class_name")
                        and existing_record.get("collection_role") == record.get("collection_role")
                    )
                )
                if not same_group:
                    continue
                if hamming_distance(existing_record["perceptual_hash"], record["perceptual_hash"]) <= 6:
                    duplicate_of = existing_record["sample_id"]
                    record["discard_reason"] = "near_duplicate_phash"
                    break
                if cosine_similarity(existing_embedding, embedding) >= 0.997:
                    duplicate_of = existing_record["sample_id"]
                    record["discard_reason"] = "near_duplicate_embedding"
                    break

        if duplicate_of:
            record["duplicate_of"] = duplicate_of
            dedup_log.append(record)
            continue

        record["label_confidence"] = confidence_for(record)
        if record["watermark_suspected"]:
            record["label_confidence"] = min(record["label_confidence"], 0.55)
        if record["source_type"] == "wikimedia_commons_search":
            record["review_required"] = True
            review.append(record)
        elif record["label_confidence"] < 0.7:
            record["review_required"] = True
            review.append(record)
        else:
            record["review_required"] = False

        seen_hashes[record["file_hash"]] = record["sample_id"]
        embeddings.append((record, embedding))
        kept.append(record)

    write_jsonl(FILTERED_MANIFEST, kept)
    write_jsonl(REVIEW_QUEUE, review)
    write_jsonl(DEDUP_LOG, dedup_log)
    print(
        json.dumps(
            {
                "filtered_candidates": len(kept),
                "review_queue": len(review),
                "dedup_or_filtered": len(dedup_log),
            }
        )
    )


if __name__ == "__main__":
    main()
