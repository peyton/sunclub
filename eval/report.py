from __future__ import annotations

import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


def plot_confusion_matrix(tp: int, tn: int, fp: int, fn: int, output_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(4, 4))
    matrix = [[tp, fn], [fp, tn]]
    ax.imshow(matrix, cmap="YlOrBr")
    ax.set_xticks([0, 1], ["Pred +", "Pred -"])
    ax.set_yticks([0, 1], ["True +", "True -"])
    for row in range(2):
        for col in range(2):
            ax.text(col, row, str(matrix[row][col]), ha="center", va="center", color="black", fontsize=14)
    ax.set_title("Current video matcher confusion matrix")
    fig.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=180)
    plt.close(fig)


def plot_pr_curves(curves: dict[str, tuple[list[tuple[float, float]], float]], output_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(6, 4))
    for label, (curve, auc) in curves.items():
        if not curve:
            continue
        xs = [point[0] for point in curve]
        ys = [point[1] for point in curve]
        ax.plot(xs, ys, label=f"{label} (AUC={auc:.3f})")
    ax.set_xlabel("Recall")
    ax.set_ylabel("Precision")
    ax.set_title("Precision-recall curves")
    ax.legend()
    fig.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=180)
    plt.close(fig)


def plot_reliability_curve(calibration_rows: list[dict], output_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(6, 4))
    xs = [row["confidence_mean"] for row in calibration_rows if row["count"] > 0]
    ys = [row["accuracy"] for row in calibration_rows if row["count"] > 0]
    ax.plot([0, 1], [0, 1], linestyle="--", color="#8e8e8e")
    ax.plot(xs, ys, marker="o", color="#1f5b62")
    ax.set_xlabel("Derived confidence")
    ax.set_ylabel("Empirical accuracy")
    ax.set_title("Reliability curve")
    fig.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=180)
    plt.close(fig)


def write_final_report(summary: dict, output_path: Path) -> None:
    lines = [
        "# Sunscreen object-recognition verification report",
        "",
        "## Model discovery",
        "",
        "- Task: instance retrieval / same-bottle verification using Vision feature prints, not generic classification or detection.",
        "- Inference entrypoints in app: `SelfieCaptureCoordinator` and `VideoVerificationCoordinator` through `VisionFeaturePrintService`.",
        "- Preprocessing: no explicit fixed resize in app code; raw photo/frame is passed into `VNGenerateImageFeaturePrintRequest`, which performs its own internal preprocessing.",
        "- Current operating points mirrored in evaluation: selfie direct<=0.56 or consensus<=0.59 with support>=2; video direct<=0.58 or consensus<=0.60 with support>=2.",
        "- Baseline comparison: legacy min-distance<=18.5 rule.",
        "",
        "## Dataset summary",
        "",
        f"- Seed training corpus size: {summary['counts']['train_count']}",
        f"- Enrollment images: {summary['counts']['enrollment_count']}",
        f"- Validation benchmark size: {summary['counts']['val_count']}",
        f"- Test benchmark size: {summary['counts']['test_count']}",
        "",
        "## Leakage checks",
        "",
        f"- Train/test exact hash overlap: {summary['leakage']['train_test_exact_overlap']}",
        f"- Val/test exact hash overlap: {summary['leakage']['val_test_exact_overlap']}",
        f"- Val/test parent-source overlap: {summary['leakage']['val_test_parent_overlap']}",
        f"- Benchmark target family leaked into seed train corpus: {summary['leakage']['train_target_family_overlap']}",
        "",
        "## Headline metrics (test split)",
        "",
    ]

    for model_name, metrics in summary["headline_metrics"].items():
        lines.append(
            f"- {model_name}: accuracy={metrics['accuracy']:.3f}, precision={metrics['precision']:.3f}, recall={metrics['recall']:.3f}, f1={metrics['f1']:.3f}, pr_auc={metrics['pr_auc']:.3f}, roc_auc={metrics['roc_auc']:.3f}"
        )
    lines.extend(
        [
            "",
            "## Manual benchmark review",
            "",
            f"- Random samples inspected: {summary['manual_review']['checked_count']}",
            f"- Findings: {summary['manual_review']['summary']}",
            "",
            "## Largest error modes",
            "",
        ]
    )

    for item in summary["failure_modes"][:10]:
        lines.append(f"- {item}")

    lines.extend(
        [
            "",
            "## Risks and limitations",
            "",
            "- Disjointness is guaranteed only across the web data collected in this pipeline and the checked repo contents, not against any unknown historical data used before this repo state.",
            "- Benchmark positives and many hard slices are generated from held-out public web images plus deterministic transforms, so they are better for regression checking than for absolute real-world performance claims.",
            "- Confidence calibration uses a derived distance-margin score because the current model does not emit a native calibrated probability.",
            "- No zero-shot vision baseline was added because the repo and local environment do not already ship one, and downloading a separate external model would materially change the evaluation stack.",
            "",
            "## Artifacts",
            "",
            "- `manifests/train_manifest.jsonl`",
            "- `manifests/val_manifest.jsonl`",
            "- `manifests/test_manifest.jsonl`",
            "- `manifests/benchmark_manifest.jsonl`",
            "- `benchmarks/slice_metrics.csv`",
            "- `benchmarks/confusion_matrix.png`",
            "- `benchmarks/pr_curve.png`",
            "- `benchmarks/reliability_curve.png`",
            "- `benchmarks/final_report.md`",
        ]
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

