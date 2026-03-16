from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np


@dataclass
class BinaryMetrics:
    accuracy: float
    precision: float
    recall: float
    f1: float
    true_positives: int
    true_negatives: int
    false_positives: int
    false_negatives: int


def confusion_counts(y_true: list[int], y_pred: list[int]) -> BinaryMetrics:
    tp = sum(1 for truth, pred in zip(y_true, y_pred) if truth == 1 and pred == 1)
    tn = sum(1 for truth, pred in zip(y_true, y_pred) if truth == 0 and pred == 0)
    fp = sum(1 for truth, pred in zip(y_true, y_pred) if truth == 0 and pred == 1)
    fn = sum(1 for truth, pred in zip(y_true, y_pred) if truth == 1 and pred == 0)
    total = max(1, len(y_true))
    precision = tp / max(1, tp + fp)
    recall = tp / max(1, tp + fn)
    f1 = 0.0 if precision + recall == 0 else (2 * precision * recall) / (precision + recall)
    accuracy = (tp + tn) / total
    return BinaryMetrics(
        accuracy=accuracy,
        precision=precision,
        recall=recall,
        f1=f1,
        true_positives=tp,
        true_negatives=tn,
        false_positives=fp,
        false_negatives=fn,
    )


def roc_curve_auc(y_true: list[int], scores: list[float]) -> tuple[list[tuple[float, float]], float]:
    pairs = sorted(zip(scores, y_true), key=lambda item: item[0], reverse=True)
    positives = sum(y_true)
    negatives = len(y_true) - positives
    tp = fp = 0
    curve = [(0.0, 0.0)]
    prev_score = None
    for score, label in pairs:
        if prev_score is not None and score != prev_score:
            curve.append((fp / max(1, negatives), tp / max(1, positives)))
        if label == 1:
            tp += 1
        else:
            fp += 1
        prev_score = score
    curve.append((fp / max(1, negatives), tp / max(1, positives)))
    auc = 0.0
    for (x1, y1), (x2, y2) in zip(curve[:-1], curve[1:]):
        auc += (x2 - x1) * (y1 + y2) / 2
    return curve, auc


def pr_curve_auc(y_true: list[int], scores: list[float]) -> tuple[list[tuple[float, float]], float]:
    pairs = sorted(zip(scores, y_true), key=lambda item: item[0], reverse=True)
    tp = fp = 0
    positives = sum(y_true)
    curve = []
    auc = 0.0
    prev_recall = 0.0
    for score, label in pairs:
        if label == 1:
            tp += 1
        else:
            fp += 1
        precision = tp / max(1, tp + fp)
        recall = tp / max(1, positives)
        curve.append((recall, precision))
        auc += (recall - prev_recall) * precision
        prev_recall = recall
    return curve, auc


def calibration_bins(y_true: list[int], confidences: list[float], bins: int = 10) -> list[dict]:
    edges = np.linspace(0.0, 1.0, bins + 1)
    results: list[dict] = []
    y = np.asarray(y_true, dtype=np.float32)
    c = np.asarray(confidences, dtype=np.float32)
    for start, end in zip(edges[:-1], edges[1:]):
        mask = (c >= start) & (c < end if end < 1.0 else c <= end)
        if not mask.any():
            results.append(
                {"bin_start": float(start), "bin_end": float(end), "count": 0, "confidence_mean": 0.0, "accuracy": 0.0}
            )
            continue
        results.append(
            {
                "bin_start": float(start),
                "bin_end": float(end),
                "count": int(mask.sum()),
                "confidence_mean": float(c[mask].mean()),
                "accuracy": float(y[mask].mean()),
            }
        )
    return results


def threshold_sweep(y_true: list[int], scores: list[float]) -> list[dict]:
    thresholds = sorted(set(scores), reverse=True)
    rows: list[dict] = []
    for threshold in thresholds:
        y_pred = [1 if score >= threshold else 0 for score in scores]
        metrics = confusion_counts(y_true, y_pred)
        rows.append(
            {
                "threshold": threshold,
                "accuracy": metrics.accuracy,
                "precision": metrics.precision,
                "recall": metrics.recall,
                "f1": metrics.f1,
            }
        )
    return rows

