#!/usr/bin/env python3
"""Per-enrollment few-shot evaluation (SPEC §1.5–1.6).

For each enrollment set in the benchmark manifest, computes feature prints for
the enrollment images, scores matched positives / general positives / general
negatives, and produces a composite score.  The overall benchmark score is the
*minimum* composite across all enrollment sets (worst-case user experience).
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from metrics import confusion_counts
from run_eval import MODELS, decide, read_jsonl

BENCHMARK_DIR = ROOT / "evals" / "benchmark"
MANIFEST_PATH = BENCHMARK_DIR / "manifest.json"
RESULTS_PATH = BENCHMARK_DIR / "fewshot_results.json"
FEATUREPRINT_CLI = SCRIPT_DIR / "featureprint_cli.swift"

CONFIG = MODELS["current_video"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _write_jsonl(path: Path, rows: list[dict]) -> None:
    """Write a list of dicts as newline-delimited JSON."""
    with path.open("w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, sort_keys=True) + "\n")


def _score_enrollment(
    enrollment_manifest_path: Path,
    test_manifest_path: Path,
    output_scores_path: Path,
) -> None:
    """Call featureprint_cli.swift to produce scored JSONL."""
    output_scores_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "swift",
            str(FEATUREPRINT_CLI),
            "--enrollment-manifest",
            str(enrollment_manifest_path),
            "--test-manifest",
            str(test_manifest_path),
            "--output",
            str(output_scores_path),
        ],
        cwd=str(ROOT),
        check=True,
    )


# ---------------------------------------------------------------------------
# Per-enrollment evaluation
# ---------------------------------------------------------------------------

def evaluate_enrollment_set(
    enrollment_set: dict,
    general_positives: list[str],
    general_negatives: list[str],
    tmpdir: Path,
) -> dict:
    """Evaluate a single enrollment set and return per-image results + metrics."""

    set_id: str = enrollment_set["id"]

    # -- build enrollment manifest JSONL --
    enrollment_rows = [
        {"sample_id": f"{set_id}_enroll_{i:03d}", "image_path": img}
        for i, img in enumerate(enrollment_set["enrollment_images"])
    ]
    enrollment_manifest = tmpdir / f"{set_id}_enrollment.jsonl"
    _write_jsonl(enrollment_manifest, enrollment_rows)

    # -- build test manifest JSONL --
    test_rows: list[dict] = []
    labels: dict[str, int] = {}

    for i, img in enumerate(enrollment_set["matched_positives"]):
        sid = f"{set_id}_matched_{i:03d}"
        test_rows.append({"sample_id": sid, "image_path": img})
        labels[sid] = 1  # matched positives → expect accept

    for i, img in enumerate(general_positives):
        sid = f"general_pos_{i:03d}"
        test_rows.append({"sample_id": sid, "image_path": img})
        labels[sid] = 0  # general positives → expect reject (cross-bottle)

    for i, img in enumerate(general_negatives):
        sid = f"general_neg_{i:03d}"
        test_rows.append({"sample_id": sid, "image_path": img})
        labels[sid] = 0  # general negatives → expect reject

    test_manifest = tmpdir / f"{set_id}_test.jsonl"
    _write_jsonl(test_manifest, test_rows)

    # -- score --
    scores_path = tmpdir / f"{set_id}_scores.jsonl"
    _score_enrollment(enrollment_manifest, test_manifest, scores_path)
    score_rows = read_jsonl(scores_path)
    score_by_id = {row["sample_id"]: row for row in score_rows}

    # -- per-image results --
    per_image: list[dict] = []
    for row in test_rows:
        sid = row["sample_id"]
        distances = score_by_id[sid]["distances"]
        accepted, best, consensus, support, confidence = decide(distances, CONFIG)
        label = labels[sid]
        per_image.append(
            {
                "enrollment_set": set_id,
                "sample_id": sid,
                "distances": distances,
                "accepted": accepted,
                "label": label,
                "best_distance": best,
                "consensus_distance": consensus,
                "confidence": confidence,
            }
        )

    # -- compute sub-metrics --
    matched = [r for r in per_image if r["sample_id"].startswith(f"{set_id}_matched_")]
    gen_pos = [r for r in per_image if r["sample_id"].startswith("general_pos_")]
    gen_neg = [r for r in per_image if r["sample_id"].startswith("general_neg_")]

    matched_recall = _recall(matched)
    cross_bottle_precision = _precision_as_rejection(gen_pos)
    negative_precision = _precision_as_rejection(gen_neg)

    composite = (
        0.50 * matched_recall
        + 0.25 * cross_bottle_precision
        + 0.25 * negative_precision
    )

    return {
        "enrollment_set": set_id,
        "matched_recall": matched_recall,
        "cross_bottle_precision": cross_bottle_precision,
        "negative_precision": negative_precision,
        "composite_score": composite,
        "per_image": per_image,
    }


def _recall(rows: list[dict]) -> float:
    """Recall among matched positives (label=1, expect accepted=1)."""
    if not rows:
        return 0.0
    m = confusion_counts(
        [r["label"] for r in rows],
        [r["accepted"] for r in rows],
    )
    return m.recall


def _precision_as_rejection(rows: list[dict]) -> float:
    """Precision defined as 1 - false_accept_rate.

    All rows have label=0 (expect reject), so false accepts are rows where
    accepted=1.  Returns 1 - (false_accepts / total).
    """
    if not rows:
        return 1.0
    false_accepts = sum(1 for r in rows if r["accepted"] == 1)
    return 1.0 - (false_accepts / len(rows))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    if not MANIFEST_PATH.exists():
        print(
            f"Error: manifest not found at {MANIFEST_PATH}\n"
            "Run the benchmark data pipeline first to generate manifest.json.",
            file=sys.stderr,
        )
        sys.exit(1)

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    enrollment_sets: list[dict] = manifest["enrollment_sets"]
    general_positives: list[str] = manifest["general_positives"].get("test", [])
    general_negatives: list[str] = manifest["general_negatives"].get("test", [])

    if not enrollment_sets:
        print("Error: no enrollment sets in manifest.", file=sys.stderr)
        sys.exit(1)

    results: list[dict] = []

    with tempfile.TemporaryDirectory(prefix="fewshot_eval_") as tmpdir:
        tmpdir_path = Path(tmpdir)
        for eset in enrollment_sets:
            print(f"Evaluating enrollment set: {eset['id']} ...")
            result = evaluate_enrollment_set(
                eset, general_positives, general_negatives, tmpdir_path
            )
            results.append(result)
            print(
                f"  matched_recall={result['matched_recall']:.3f}  "
                f"cross_bottle_precision={result['cross_bottle_precision']:.3f}  "
                f"negative_precision={result['negative_precision']:.3f}  "
                f"composite={result['composite_score']:.3f}"
            )

    # -- aggregate --
    composites = [r["composite_score"] for r in results]
    min_score = min(composites)
    min_set = results[composites.index(min_score)]["enrollment_set"]

    summary = {
        "overall_score": min_score,
        "worst_enrollment_set": min_set,
        "enrollment_results": [
            {k: v for k, v in r.items() if k != "per_image"} for r in results
        ],
        "per_image_results": [img for r in results for img in r["per_image"]],
    }

    RESULTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    RESULTS_PATH.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    print("\n=== Few-Shot Evaluation Summary ===")
    print(f"Enrollment sets evaluated: {len(results)}")
    for r in results:
        print(f"  {r['enrollment_set']}: composite={r['composite_score']:.3f}")
    print(f"\nOverall score (min composite): {min_score:.3f}  (worst set: {min_set})")
    print(f"Results saved to {RESULTS_PATH}")


if __name__ == "__main__":
    main()
