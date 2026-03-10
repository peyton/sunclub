#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from metrics import calibration_bins, confusion_counts, pr_curve_auc, roc_curve_auc, threshold_sweep
from report import plot_confusion_matrix, plot_pr_curves, plot_reliability_curve, write_final_report

BENCHMARK_DIR = ROOT / "benchmarks"
MANIFESTS_DIR = ROOT / "manifests"
VAL_MANIFEST = MANIFESTS_DIR / "val_manifest.jsonl"
TEST_MANIFEST = MANIFESTS_DIR / "test_manifest.jsonl"
ENROLLMENT_MANIFEST = MANIFESTS_DIR / "enrollment_manifest.jsonl"
LEAKAGE_REPORT = MANIFESTS_DIR / "leakage_report.json"
SPLIT_SUMMARY = MANIFESTS_DIR / "split_summary.json"
MANUAL_REVIEW_LOG = BENCHMARK_DIR / "manual_review_log.jsonl"
CURRENT_VAL_SCORES = BENCHMARK_DIR / "val_scores.jsonl"
CURRENT_TEST_SCORES = BENCHMARK_DIR / "test_scores.jsonl"
SLICE_METRICS_CSV = BENCHMARK_DIR / "slice_metrics.csv"
THRESHOLD_SWEEP_CSV = BENCHMARK_DIR / "threshold_sweep.csv"
FAILURES_DIR = BENCHMARK_DIR / "failures_topk"
FINAL_REPORT = BENCHMARK_DIR / "final_report.md"

MODELS = {
    "legacy": {
        "direct_hit_threshold": 18.5,
        "support_threshold": 18.5,
        "required_support_count": 1,
        "consensus_top_k": 1,
        "consensus_threshold": 18.5,
    },
    "current_selfie": {
        "direct_hit_threshold": 0.56,
        "support_threshold": 0.60,
        "required_support_count": 2,
        "consensus_top_k": 4,
        "consensus_threshold": 0.59,
    },
    "current_video": {
        "direct_hit_threshold": 0.58,
        "support_threshold": 0.62,
        "required_support_count": 2,
        "consensus_top_k": 4,
        "consensus_threshold": 0.60,
    },
}


def read_jsonl(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def decide(distances: list[float], config: dict) -> tuple[int, float, float, int, float]:
    best = min(distances)
    top_k = sorted(distances)[: max(1, min(config["consensus_top_k"], len(distances)))]
    consensus = sum(top_k) / len(top_k)
    support = sum(1 for distance in distances if distance <= config["support_threshold"])
    required_support = min(max(1, config["required_support_count"]), len(distances))
    accepted = int(best <= config["direct_hit_threshold"] or (support >= required_support and consensus <= config["consensus_threshold"]))
    raw_score = -((0.65 * best) + (0.35 * consensus))
    margin = max(config["direct_hit_threshold"] - best, config["consensus_threshold"] - consensus)
    confidence = 1.0 / (1.0 + math.exp(-(margin / 0.04)))
    return accepted, best, consensus, support, confidence if config["direct_hit_threshold"] < 5 else 1.0 / (1.0 + best)


def score_manifest(input_manifest: Path, output_scores: Path) -> None:
    output_scores.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "swift",
            str(SCRIPT_DIR / "featureprint_cli.swift"),
            "--enrollment-manifest",
            str(ENROLLMENT_MANIFEST),
            "--test-manifest",
            str(input_manifest),
            "--output",
            str(output_scores),
        ],
        cwd=str(ROOT),
        check=True,
    )


def enrich_rows(manifest_rows: list[dict], score_rows: list[dict]) -> list[dict]:
    score_by_id = {row["sample_id"]: row for row in score_rows}
    enriched: list[dict] = []
    for row in manifest_rows:
        merged = dict(row)
        merged.update(score_by_id[row["sample_id"]])
        for model_name, config in MODELS.items():
            accepted, best, consensus, support, confidence = decide(merged["distances"], config)
            merged[f"{model_name}_accepted"] = accepted
            merged[f"{model_name}_best_distance"] = best
            merged[f"{model_name}_consensus_distance"] = consensus
            merged[f"{model_name}_support_count"] = support
            merged[f"{model_name}_confidence"] = confidence
            merged[f"{model_name}_score"] = -(0.65 * best + 0.35 * consensus)
        enriched.append(merged)
    return enriched


def slice_rows(rows: list[dict], model_name: str, split_name: str) -> list[dict]:
    output: list[dict] = []
    slices = sorted({slice_name for row in rows for slice_name in row["slice_names"]})
    for slice_name in slices:
        subset = [row for row in rows if slice_name in row["slice_names"]]
        if not subset:
            continue
        metrics = confusion_counts([row["label"] for row in subset], [row[f"{model_name}_accepted"] for row in subset])
        output.append(
            {
                "split": split_name,
                "model": model_name,
                "slice": slice_name,
                "count": len(subset),
                "accuracy": metrics.accuracy,
                "precision": metrics.precision,
                "recall": metrics.recall,
                "f1": metrics.f1,
            }
        )
    return output


def copy_failures(rows: list[dict], model_name: str) -> list[dict]:
    if FAILURES_DIR.exists():
        shutil.rmtree(FAILURES_DIR)
    FAILURES_DIR.mkdir(parents=True, exist_ok=True)
    false_positives = sorted(
        [row for row in rows if row["label"] == 0 and row[f"{model_name}_accepted"] == 1],
        key=lambda row: row[f"{model_name}_best_distance"],
    )[:5]
    false_negatives = sorted(
        [row for row in rows if row["label"] == 1 and row[f"{model_name}_accepted"] == 0],
        key=lambda row: row[f"{model_name}_best_distance"],
    )[:5]
    manifest: list[dict] = []
    for prefix, examples in [("fp", false_positives), ("fn", false_negatives)]:
        for index, row in enumerate(examples, start=1):
            target = FAILURES_DIR / f"{prefix}_{index:02d}_{row['sample_id']}.jpg"
            shutil.copy(row["image_path"], target)
            manifest.append(
                {
                    "kind": prefix,
                    "sample_id": row["sample_id"],
                    "target_path": str(target),
                    "slice_names": row["slice_names"],
                    "best_distance": row[f"{model_name}_best_distance"],
                    "consensus_distance": row[f"{model_name}_consensus_distance"],
                    "label": row["label"],
                }
            )
    with (FAILURES_DIR / "failures_manifest.jsonl").open("w", encoding="utf-8") as handle:
        for row in manifest:
            handle.write(json.dumps(row, sort_keys=True) + "\n")
    return manifest


def main() -> None:
    score_manifest(VAL_MANIFEST, CURRENT_VAL_SCORES)
    score_manifest(TEST_MANIFEST, CURRENT_TEST_SCORES)

    val_rows = enrich_rows(read_jsonl(VAL_MANIFEST), read_jsonl(CURRENT_VAL_SCORES))
    test_rows = enrich_rows(read_jsonl(TEST_MANIFEST), read_jsonl(CURRENT_TEST_SCORES))

    slice_metrics = []
    for model_name in MODELS:
        slice_metrics.extend(slice_rows(val_rows, model_name, "val"))
        slice_metrics.extend(slice_rows(test_rows, model_name, "test"))
    with SLICE_METRICS_CSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["split", "model", "slice", "count", "accuracy", "precision", "recall", "f1"])
        writer.writeheader()
        writer.writerows(slice_metrics)

    primary_model = "current_video"
    baseline_model = "legacy"
    y_true = [row["label"] for row in test_rows]
    y_pred = [row[f"{primary_model}_accepted"] for row in test_rows]
    primary_metrics = confusion_counts(y_true, y_pred)
    roc_curve, roc_auc = roc_curve_auc(y_true, [row[f"{primary_model}_score"] for row in test_rows])
    pr_curve, pr_auc = pr_curve_auc(y_true, [row[f"{primary_model}_score"] for row in test_rows])
    baseline_pr_curve, baseline_pr_auc = pr_curve_auc(y_true, [row[f"{baseline_model}_score"] for row in test_rows])
    calibration = calibration_bins(y_true, [row[f"{primary_model}_confidence"] for row in test_rows], bins=10)
    sweep = threshold_sweep(y_true, [row[f"{primary_model}_score"] for row in test_rows])
    with THRESHOLD_SWEEP_CSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["threshold", "accuracy", "precision", "recall", "f1"])
        writer.writeheader()
        writer.writerows(sweep)

    plot_confusion_matrix(
        tp=primary_metrics.true_positives,
        tn=primary_metrics.true_negatives,
        fp=primary_metrics.false_positives,
        fn=primary_metrics.false_negatives,
        output_path=BENCHMARK_DIR / "confusion_matrix.png",
    )
    plot_pr_curves(
        curves={
            "current_video": (pr_curve, pr_auc),
            "legacy": (baseline_pr_curve, baseline_pr_auc),
        },
        output_path=BENCHMARK_DIR / "pr_curve.png",
    )
    plot_reliability_curve(calibration, BENCHMARK_DIR / "reliability_curve.png")
    failure_manifest = copy_failures(test_rows, primary_model)

    leakage = json.loads(LEAKAGE_REPORT.read_text(encoding="utf-8"))
    counts = json.loads(SPLIT_SUMMARY.read_text(encoding="utf-8"))
    headline_metrics = {}
    for model_name in ["legacy", "current_selfie", "current_video"]:
        metrics = confusion_counts(y_true, [row[f"{model_name}_accepted"] for row in test_rows])
        _, model_roc_auc = roc_curve_auc(y_true, [row[f"{model_name}_score"] for row in test_rows])
        _, model_pr_auc = pr_curve_auc(y_true, [row[f"{model_name}_score"] for row in test_rows])
        headline_metrics[model_name] = {
            "accuracy": metrics.accuracy,
            "precision": metrics.precision,
            "recall": metrics.recall,
            "f1": metrics.f1,
            "roc_auc": model_roc_auc,
            "pr_auc": model_pr_auc,
        }

    manual_review_rows = read_jsonl(MANUAL_REVIEW_LOG) if MANUAL_REVIEW_LOG.exists() else []
    failure_modes: list[str] = []
    overall_recall = headline_metrics[primary_model]["recall"]
    if overall_recall == 0:
        failure_modes.append(
            f"{primary_model} rejected all {sum(y_true)} positives on the held-out test split."
        )
    slice_positive_counts = {}
    slice_fn_counts = {}
    for row in test_rows:
        for slice_name in row["slice_names"]:
            if row["label"] == 1:
                slice_positive_counts[slice_name] = slice_positive_counts.get(slice_name, 0) + 1
                if row[f"{primary_model}_accepted"] == 0:
                    slice_fn_counts[slice_name] = slice_fn_counts.get(slice_name, 0) + 1
    for slice_name, positive_count in sorted(slice_positive_counts.items(), key=lambda item: (-slice_fn_counts.get(item[0], 0), item[0])):
        fn_count = slice_fn_counts.get(slice_name, 0)
        recall = 0.0 if positive_count == 0 else (positive_count - fn_count) / positive_count
        failure_modes.append(f"{slice_name}: recall {recall:.2f} on {positive_count} positives ({fn_count} false negatives).")
    if failure_manifest:
        fn_distances = [row["best_distance"] for row in failure_manifest if row["kind"] == "fn"]
        if fn_distances:
            failure_modes.append(
                f"Top false negatives had best-distance range {min(fn_distances):.2f} to {max(fn_distances):.2f}, far above the current video acceptance region."
            )
    legacy_fp = sum(1 for row in test_rows if row["label"] == 0 and row["legacy_accepted"] == 1)
    failure_modes.append(f"Legacy baseline produced {legacy_fp} false positives out of {sum(1 for row in test_rows if row['label'] == 0)} negatives.")
    summary = {
        "counts": counts,
        "leakage": leakage,
        "headline_metrics": headline_metrics,
        "manual_review": {
            "checked_count": len(manual_review_rows),
            "summary": "manual review log present" if manual_review_rows else "manual review log not written yet",
        },
        "failure_modes": failure_modes[:10],
    }
    write_final_report(summary, FINAL_REPORT)
    (BENCHMARK_DIR / "eval_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({"test_examples": len(test_rows), "headline_metrics": headline_metrics["current_video"]}))


if __name__ == "__main__":
    main()
