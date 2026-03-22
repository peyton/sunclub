#!/usr/bin/env python3
"""
Automated sunscreen dataset builder.

Pipeline:
  1. Download videos from YouTube (sunscreen ads, tutorials, unrelated content)
  2. Extract frames at regular intervals
  3. Label each frame with Claude Vision (YES/NO sunscreen present)
  4. Output a LLaVA-format JSON dataset for fine-tuning FastVLM

Usage:
  python evals/scripts/collect_data.py --output-dir evals/datasets/sunscreen-v1
  python evals/scripts/collect_data.py --output-dir evals/datasets/sunscreen-v1 --skip-download
  python evals/scripts/collect_data.py --output-dir evals/datasets/sunscreen-v1 --skip-download --skip-extract
"""

import argparse
import base64
import json
import os
import random
import subprocess
import sys
import tempfile
from pathlib import Path

# ---------------------------------------------------------------------------
# Video sources — curated for diversity
# ---------------------------------------------------------------------------

# Sunscreen-positive videos: application tutorials, product reviews, ads
POSITIVE_QUERIES = [
    "how to apply sunscreen tutorial",
    "sunscreen application face body",
    "sunscreen review 2024",
    "SPF sunscreen ad commercial",
    "applying sunscreen at the beach",
    "sunscreen for kids tutorial",
    "sunscreen spray application",
    "mineral sunscreen vs chemical sunscreen review",
    "reapplying sunscreen during the day",
    "sunscreen bottle collection haul",
]

# Negative videos: outdoor activities, skincare (no sunscreen), indoor scenes
NEGATIVE_QUERIES = [
    "morning skincare routine no sunscreen",
    "outdoor hiking vlog no sunscreen",
    "cooking tutorial kitchen",
    "office desk setup tour",
    "beach vacation vlog swimming",
    "yoga in the park outdoor",
    "reading a book in the garden",
    "dog walking park vlog",
    "grocery shopping haul",
    "living room home tour",
]

VIDEOS_PER_QUERY = 2
FRAMES_PER_VIDEO = 10
FRAME_INTERVAL_SECONDS = 3

# The prompt we use for labeling (matches the app's detection prompt closely)
LABELING_PROMPT = """\
Look at this image carefully. Is there sunscreen, a sunscreen bottle, or someone \
actively applying sunscreen visible in this image?

Consider these as YES:
- A sunscreen bottle or tube (any brand, size, or type)
- Someone applying white/clear cream that appears to be sunscreen
- Sunscreen spray being applied
- A sunscreen product clearly visible in the scene

Consider these as NO:
- Regular lotion, moisturizer, or non-sunscreen skincare
- A beach/outdoor scene with no sunscreen visible
- People with shiny/oily skin but no sunscreen product visible
- Any scene where you're unsure

Answer with exactly one word: YES or NO."""


def download_videos(query: str, output_dir: Path, max_results: int) -> list[Path]:
    """Download short videos matching a search query using yt-dlp."""
    videos_dir = output_dir / "videos"
    videos_dir.mkdir(parents=True, exist_ok=True)

    # Sanitize query for filename
    safe_query = query.replace(" ", "_")[:40]

    cmd = [
        "yt-dlp",
        f"ytsearch{max_results}:{query}",
        "--format", "worst[ext=mp4]",  # smallest quality — we only need frames
        "--max-filesize", "50M",
        "--max-downloads", str(max_results),
        "--no-playlist",
        "--output", str(videos_dir / f"{safe_query}_%(autonumber)s.%(ext)s"),
        "--quiet",
        "--no-warnings",
        "--socket-timeout", "30",
        "--retries", "3",
    ]

    print(f"  Downloading videos for: {query}")
    try:
        subprocess.run(cmd, check=False, capture_output=True, timeout=120)
    except subprocess.TimeoutExpired:
        print(f"  Warning: download timed out for '{query}'")

    downloaded = sorted(videos_dir.glob(f"{safe_query}_*.mp4"))
    print(f"  Got {len(downloaded)} videos")
    return downloaded


def extract_frames(video_path: Path, output_dir: Path, num_frames: int, interval: int) -> list[Path]:
    """Extract frames from a video at regular intervals using ffmpeg."""
    frames_dir = output_dir / "images"
    frames_dir.mkdir(parents=True, exist_ok=True)

    stem = video_path.stem
    output_pattern = str(frames_dir / f"{stem}_frame_%04d.jpg")

    cmd = [
        "ffmpeg",
        "-i", str(video_path),
        "-vf", f"fps=1/{interval},scale=1280:720:force_original_aspect_ratio=decrease",
        "-frames:v", str(num_frames),
        "-q:v", "2",  # high quality JPEG
        output_pattern,
        "-y", "-loglevel", "error",
    ]

    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=60)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return []

    frames = sorted(frames_dir.glob(f"{stem}_frame_*.jpg"))
    return frames


def label_image_with_claude(image_path: Path, client) -> tuple[str, str]:
    """Send an image to Claude Vision for YES/NO labeling.

    Returns (label, reasoning) where label is 'YES' or 'NO'.
    """
    with open(image_path, "rb") as f:
        image_data = base64.standard_b64encode(f.read()).decode("utf-8")

    suffix = image_path.suffix.lower()
    media_types = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png"}
    media_type = media_types.get(suffix, "image/jpeg")

    message = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=50,
        messages=[{
            "role": "user",
            "content": [
                {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": image_data}},
                {"type": "text", "text": LABELING_PROMPT},
            ],
        }],
    )

    raw = message.content[0].text.strip().upper()
    label = "YES" if raw.startswith("YES") else "NO"
    return label, raw


def build_llava_dataset(labeled_items: list[dict], output_path: Path):
    """Write labeled items to LLaVA conversation format JSON."""
    dataset = []
    for item in labeled_items:
        dataset.append({
            "id": item["id"],
            "image": item["image"],
            "conversations": [
                {
                    "from": "human",
                    "value": "<image>\nIs there sunscreen or a sunscreen bottle in this image? Answer ONLY with YES or NO. If unsure, answer NO.",
                },
                {
                    "from": "gpt",
                    "value": item["label"],
                },
            ],
        })
    with open(output_path, "w") as f:
        json.dump(dataset, f, indent=2)
    print(f"Wrote {len(dataset)} items to {output_path}")


def build_eval_dataset(labeled_items: list[dict], output_path: Path):
    """Write a simpler eval-format JSON for the benchmark harness."""
    dataset = []
    for item in labeled_items:
        dataset.append({
            "id": item["id"],
            "image": item["image"],
            "expected": item["label"],
            "source_query": item.get("source_query", ""),
            "labeler_raw": item.get("labeler_raw", ""),
        })
    with open(output_path, "w") as f:
        json.dump(dataset, f, indent=2)
    print(f"Wrote {len(dataset)} eval items to {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Build sunscreen detection dataset")
    parser.add_argument("--output-dir", required=True, help="Output directory for dataset")
    parser.add_argument("--skip-download", action="store_true", help="Skip video download, use existing videos")
    parser.add_argument("--skip-extract", action="store_true", help="Skip frame extraction, use existing images")
    parser.add_argument("--skip-label", action="store_true", help="Skip labeling, use existing labels")
    parser.add_argument("--max-queries", type=int, default=None, help="Limit number of queries (for testing)")
    parser.add_argument("--videos-per-query", type=int, default=VIDEOS_PER_QUERY)
    parser.add_argument("--frames-per-video", type=int, default=FRAMES_PER_VIDEO)
    args = parser.parse_args()

    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    labels_path = output_dir / "labels.json"
    train_path = output_dir / "train.json"
    eval_path = output_dir / "eval.json"

    # ---- Step 1: Download videos ----
    if not args.skip_download:
        print("\n=== Step 1: Downloading videos ===")

        pos_queries = POSITIVE_QUERIES[: args.max_queries] if args.max_queries else POSITIVE_QUERIES
        neg_queries = NEGATIVE_QUERIES[: args.max_queries] if args.max_queries else NEGATIVE_QUERIES

        for query in pos_queries + neg_queries:
            download_videos(query, output_dir, args.videos_per_query)
    else:
        print("\n=== Step 1: Skipping download (--skip-download) ===")

    # ---- Step 2: Extract frames ----
    if not args.skip_extract:
        print("\n=== Step 2: Extracting frames ===")
        videos = sorted((output_dir / "videos").glob("*.mp4")) if (output_dir / "videos").exists() else []
        print(f"Found {len(videos)} videos")

        for video in videos:
            frames = extract_frames(video, output_dir, args.frames_per_video, FRAME_INTERVAL_SECONDS)
            print(f"  {video.name}: {len(frames)} frames")
    else:
        print("\n=== Step 2: Skipping extraction (--skip-extract) ===")

    # ---- Step 3: Label with Claude ----
    if not args.skip_label:
        print("\n=== Step 3: Labeling images with Claude ===")

        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            print("ERROR: ANTHROPIC_API_KEY not set. Export it and re-run.", file=sys.stderr)
            sys.exit(1)

        import anthropic
        client = anthropic.Anthropic(api_key=api_key)

        images_dir = output_dir / "images"
        if not images_dir.exists():
            print("ERROR: No images directory found. Run without --skip-extract first.", file=sys.stderr)
            sys.exit(1)

        images = sorted(images_dir.glob("*.jpg"))
        print(f"Found {len(images)} images to label")

        # Load existing labels to allow resuming
        existing_labels = {}
        if labels_path.exists():
            with open(labels_path) as f:
                for item in json.load(f):
                    existing_labels[item["id"]] = item

        labeled_items = list(existing_labels.values())
        labeled_ids = set(existing_labels.keys())

        for i, img in enumerate(images):
            item_id = img.stem
            if item_id in labeled_ids:
                continue

            print(f"  [{i+1}/{len(images)}] {img.name}...", end=" ", flush=True)
            try:
                label, raw = label_image_with_claude(img, client)
                print(label)

                # Infer source query from filename
                source_query = ""
                for q in POSITIVE_QUERIES + NEGATIVE_QUERIES:
                    safe_q = q.replace(" ", "_")[:40]
                    if img.name.startswith(safe_q):
                        source_query = q
                        break

                item = {
                    "id": item_id,
                    "image": f"images/{img.name}",
                    "label": label,
                    "labeler_raw": raw,
                    "source_query": source_query,
                }
                labeled_items.append(item)
                labeled_ids.add(item_id)

                # Save progress after each label (resumable)
                with open(labels_path, "w") as f:
                    json.dump(labeled_items, f, indent=2)

            except Exception as e:
                print(f"ERROR: {e}")
                continue
    else:
        print("\n=== Step 3: Skipping labeling (--skip-label) ===")
        if labels_path.exists():
            with open(labels_path) as f:
                labeled_items = json.load(f)
        else:
            print("ERROR: No labels.json found. Run without --skip-label first.", file=sys.stderr)
            sys.exit(1)

    # ---- Step 4: Build datasets ----
    print("\n=== Step 4: Building datasets ===")

    # Shuffle and split 80/20 into train/eval
    random.seed(42)
    random.shuffle(labeled_items)

    split_idx = int(len(labeled_items) * 0.8)
    train_items = labeled_items[:split_idx]
    eval_items = labeled_items[split_idx:]

    build_llava_dataset(train_items, train_path)
    build_eval_dataset(eval_items, eval_path)

    # Print stats
    yes_count = sum(1 for item in labeled_items if item["label"] == "YES")
    no_count = len(labeled_items) - yes_count
    print(f"\nDataset summary:")
    print(f"  Total:  {len(labeled_items)} images")
    print(f"  YES:    {yes_count} ({100*yes_count/max(len(labeled_items),1):.0f}%)")
    print(f"  NO:     {no_count} ({100*no_count/max(len(labeled_items),1):.0f}%)")
    print(f"  Train:  {len(train_items)} items → {train_path}")
    print(f"  Eval:   {len(eval_items)} items → {eval_path}")


if __name__ == "__main__":
    main()
