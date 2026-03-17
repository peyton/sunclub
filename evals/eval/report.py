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
            "- `evals/benchmark/slice_metrics.csv`",
            "- `evals/benchmark/confusion_matrix.png`",
            "- `evals/benchmark/pr_curve.png`",
            "- `evals/benchmark/reliability_curve.png`",
            "- `evals/benchmark/final_report.md`",
        ]
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def plot_enrollment_confusion_matrix(
    enrollment_id: str,
    tp: int,
    tn_cross: int,
    tn_neg: int,
    fp_cross: int,
    fp_neg: int,
    fn: int,
    output_path: Path,
) -> None:
    """Per-enrollment 3-class confusion matrix: matched, cross-bottle, negative."""
    fig, ax = plt.subplots(figsize=(5, 3.5))
    categories = ["Matched", "Cross-bottle", "Negative"]
    accepted = [tp, fp_cross, fp_neg]
    rejected = [fn, tn_cross, tn_neg]
    matrix = [accepted, rejected]
    row_labels = ["Accepted", "Rejected"]

    ax.set_xlim(-0.5, len(categories) - 0.5)
    ax.set_ylim(-0.5, len(row_labels) - 0.5)
    ax.set_xticks(range(len(categories)))
    ax.set_xticklabels(categories)
    ax.set_yticks(range(len(row_labels)))
    ax.set_yticklabels(row_labels)
    ax.invert_yaxis()

    colors = [["#4caf50", "#ef5350", "#ef5350"], ["#ef5350", "#4caf50", "#4caf50"]]
    for row in range(len(row_labels)):
        for col in range(len(categories)):
            ax.add_patch(plt.Rectangle((col - 0.5, row - 0.5), 1, 1, color=colors[row][col], alpha=0.35))
            ax.text(col, row, str(matrix[row][col]), ha="center", va="center", color="black", fontsize=14)

    ax.set_title(f"Enrollment {enrollment_id}")
    fig.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=180)
    plt.close(fig)


def plot_distance_distributions(
    matched_distances: list[float],
    cross_bottle_distances: list[float],
    negative_distances: list[float],
    output_path: Path,
) -> None:
    """Histogram of distance distributions for matched, cross-bottle, and negative pairs."""
    fig, ax = plt.subplots(figsize=(6, 4))
    bins = 40
    if matched_distances:
        ax.hist(matched_distances, bins=bins, alpha=0.5, label="Matched", color="#1f77b4")
    if cross_bottle_distances:
        ax.hist(cross_bottle_distances, bins=bins, alpha=0.5, label="Cross-bottle", color="#ff7f0e")
    if negative_distances:
        ax.hist(negative_distances, bins=bins, alpha=0.5, label="Negative", color="#2ca02c")
    ax.set_xlabel("Distance")
    ax.set_ylabel("Count")
    ax.set_title("Distance distributions by category")
    ax.legend()
    fig.tight_layout()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_path, dpi=180)
    plt.close(fig)


def write_fewshot_report(enrollment_results: list[dict], output_path: Path) -> None:
    """Write per-enrollment few-shot benchmark report to markdown."""
    lines = [
        "# Few-Shot Benchmark Report",
        "",
    ]

    # Per-enrollment sections
    for result in enrollment_results:
        eid = result["id"]
        lines.extend(
            [
                f"## Enrollment: {eid}",
                "",
                f"- Composite score: {result['composite_score']:.3f}",
                f"- Matched recall: {result['matched_recall']:.3f}",
                f"- Cross-bottle precision: {result['cross_bottle_precision']:.3f}",
                f"- Negative precision: {result['negative_precision']:.3f}",
                f"- Confusion matrix: `enrollment_{eid}_confusion.png`",
                "",
            ]
        )

    # Summary table
    lines.extend(
        [
            "## Composite Score Summary",
            "",
            "| Enrollment | Composite | Matched Recall | Cross-bottle Prec | Negative Prec |",
            "|------------|-----------|----------------|-------------------|---------------|",
        ]
    )

    worst_idx = 0
    worst_score = float("inf")
    for i, result in enumerate(enrollment_results):
        if result["composite_score"] < worst_score:
            worst_score = result["composite_score"]
            worst_idx = i
        lines.append(
            f"| {result['id']} | {result['composite_score']:.3f} | {result['matched_recall']:.3f} "
            f"| {result['cross_bottle_precision']:.3f} | {result['negative_precision']:.3f} |"
        )

    # Overall composite score (minimum across enrollments)
    overall_composite = min(r["composite_score"] for r in enrollment_results) if enrollment_results else 0.0
    lines.extend(
        [
            "",
            f"**Overall composite score (worst-case): {overall_composite:.3f}**",
            "",
        ]
    )

    # Worst-case failure analysis
    if enrollment_results:
        worst = enrollment_results[worst_idx]
        lines.extend(
            [
                "## Worst-Case Enrollment: Failure Analysis",
                "",
                f"**Enrollment `{worst['id']}` scored {worst['composite_score']:.3f}**",
                "",
                f"- Matched: {worst['matched_accepted']}/{worst['matched_count']} accepted (recall {worst['matched_recall']:.3f})",
                f"- Cross-bottle: {worst['cross_bottle_accepted']}/{worst['cross_bottle_count']} incorrectly accepted "
                f"(precision {worst['cross_bottle_precision']:.3f})",
                f"- Negative: {worst['negative_accepted']}/{worst['negative_count']} incorrectly accepted "
                f"(precision {worst['negative_precision']:.3f})",
                "",
            ]
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

