#!/usr/bin/env python3
"""
Sunscreen detection benchmark.

Measures accuracy, precision, recall, and F1 of the FastVLM model
against a labeled eval dataset.

Can run in two modes:
  1. Python-only (uses transformers + torch to load the PyTorch checkpoint)
  2. MLX mode (uses mlx-vlm to load the exported MLX model — matches on-device behavior)

Usage:
  python evals/benchmark/benchmark.py --dataset evals/datasets/sunscreen-v1/eval.json --model-dir app/FastVLM/model
  python evals/benchmark/benchmark.py --dataset evals/datasets/sunscreen-v1/eval.json --model-dir app/FastVLM/model --verbose
  python evals/benchmark/benchmark.py --dataset evals/datasets/sunscreen-v1/eval.json --model-dir app/FastVLM/model --strict
"""

import argparse
import json
import sys
import time
from pathlib import Path


def load_dataset(dataset_path: str) -> list[dict]:
    with open(dataset_path) as f:
        return json.load(f)


def run_mlx_inference(model_dir: str, image_path: str, prompt: str) -> tuple[str, float]:
    """Run inference using MLX (same runtime as the iOS app)."""
    from mlx_vlm import load, generate
    from mlx_vlm.utils import load_image

    # Lazy-load model (cached across calls via module-level state)
    global _mlx_model, _mlx_processor
    if "_mlx_model" not in globals():
        _mlx_model, _mlx_processor = load(model_dir)

    image = load_image(image_path)

    start = time.time()
    output = generate(
        _mlx_model,
        _mlx_processor,
        image,
        prompt,
        max_tokens=8,
        temp=0.0,
    )
    latency = time.time() - start

    return output.strip(), latency


def parse_answer(raw: str) -> str:
    """Parse model output to YES/NO, matching SunscreenResponseParser logic."""
    token = raw.strip().split()[0].upper() if raw.strip() else ""
    if token.startswith("YES"):
        return "YES"
    return "NO"


def compute_metrics(results: list[dict]) -> dict:
    """Compute accuracy, precision, recall, F1 from results."""
    tp = sum(1 for r in results if r["expected"] == "YES" and r["predicted"] == "YES")
    tn = sum(1 for r in results if r["expected"] == "NO" and r["predicted"] == "NO")
    fp = sum(1 for r in results if r["expected"] == "NO" and r["predicted"] == "YES")
    fn = sum(1 for r in results if r["expected"] == "YES" and r["predicted"] == "NO")

    total = len(results)
    accuracy = (tp + tn) / total if total > 0 else 0
    precision = tp / (tp + fp) if (tp + fp) > 0 else 0
    recall = tp / (tp + fn) if (tp + fn) > 0 else 0
    f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0

    latencies = [r["latency_ms"] for r in results if r["latency_ms"] is not None]
    avg_latency = sum(latencies) / len(latencies) if latencies else 0
    p95_latency = sorted(latencies)[int(len(latencies) * 0.95)] if latencies else 0

    return {
        "total": total,
        "accuracy": accuracy,
        "precision": precision,
        "recall": recall,
        "f1": f1,
        "tp": tp,
        "tn": tn,
        "fp": fp,
        "fn": fn,
        "avg_latency_ms": avg_latency,
        "p95_latency_ms": p95_latency,
    }


def main():
    parser = argparse.ArgumentParser(description="Sunscreen detection benchmark")
    parser.add_argument("--dataset", required=True, help="Path to eval.json")
    parser.add_argument("--model-dir", required=True, help="Path to MLX model directory")
    parser.add_argument("--verbose", action="store_true", help="Print per-image results")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero if F1 < 0.8")
    parser.add_argument("--output", help="Write results JSON to this path")
    args = parser.parse_args()

    dataset_path = Path(args.dataset)
    if not dataset_path.exists():
        print(f"ERROR: Dataset not found: {dataset_path}", file=sys.stderr)
        sys.exit(1)

    dataset = load_dataset(args.dataset)
    dataset_dir = dataset_path.parent

    prompt = "Is there sunscreen or a sunscreen bottle in this image? Answer ONLY with YES or NO. If unsure, answer NO."

    print(f"Benchmark: {len(dataset)} images from {dataset_path}")
    print(f"Model: {args.model_dir}")
    print()

    results = []
    for i, item in enumerate(dataset):
        image_path = str(dataset_dir / item["image"])

        if not Path(image_path).exists():
            print(f"  SKIP: {item['image']} (file not found)")
            continue

        try:
            raw_output, latency = run_mlx_inference(args.model_dir, image_path, prompt)
            predicted = parse_answer(raw_output)
        except Exception as e:
            print(f"  ERROR: {item['image']}: {e}")
            predicted = "NO"
            raw_output = f"ERROR: {e}"
            latency = None

        expected = item["expected"]
        correct = predicted == expected

        result = {
            "id": item["id"],
            "image": item["image"],
            "expected": expected,
            "predicted": predicted,
            "raw_output": raw_output,
            "correct": correct,
            "latency_ms": int(latency * 1000) if latency else None,
        }
        results.append(result)

        if args.verbose:
            mark = "OK" if correct else "FAIL"
            print(f"  [{i+1}/{len(dataset)}] {mark}  expected={expected} got={predicted}  ({item['image']})")

    metrics = compute_metrics(results)

    print()
    print("=" * 50)
    print(f"  Accuracy:  {metrics['accuracy']:.1%}  ({metrics['tp']+metrics['tn']}/{metrics['total']})")
    print(f"  Precision: {metrics['precision']:.1%}")
    print(f"  Recall:    {metrics['recall']:.1%}")
    print(f"  F1 Score:  {metrics['f1']:.1%}")
    print(f"  TP={metrics['tp']} TN={metrics['tn']} FP={metrics['fp']} FN={metrics['fn']}")
    if metrics["avg_latency_ms"]:
        print(f"  Avg latency: {metrics['avg_latency_ms']:.0f}ms  P95: {metrics['p95_latency_ms']:.0f}ms")
    print("=" * 50)

    if args.output:
        output = {"metrics": metrics, "results": results}
        with open(args.output, "w") as f:
            json.dump(output, f, indent=2)
        print(f"\nDetailed results written to {args.output}")

    if args.strict and metrics["f1"] < 0.8:
        print(f"\nSTRICT MODE: F1 {metrics['f1']:.1%} < 80% threshold. FAIL.")
        sys.exit(1)


if __name__ == "__main__":
    main()
