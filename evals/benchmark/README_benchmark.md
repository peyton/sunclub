# Benchmark pipeline

This repo now includes a provenance-aware web-image benchmark pipeline for the current sunscreen object-verification system.

Task discovered from the repo:

- current model task: same-bottle verification / instance retrieval using Vision feature prints
- benchmark target family: `Avene Intense Protect 50+`
- baselines:
  - legacy min-distance threshold
  - current selfie operating point
  - current video operating point

Pipeline steps:

```sh
cd /Users/peyton/Projects/sun-day
source .venv-eval/bin/activate
python scripts/fetch_web_images.py
python scripts/dedup_filter_and_hash.py
python scripts/build_manifests.py
python scripts/review_labels.py
python eval/run_eval.py
python -m unittest tests/test_benchmark_metrics.py
```

Key outputs:

- `manifests/raw_candidates.jsonl`
- `manifests/filtered_candidates.jsonl`
- `manifests/train_manifest.jsonl`
- `manifests/val_manifest.jsonl`
- `manifests/test_manifest.jsonl`
- `manifests/benchmark_manifest.jsonl`
- `evals/benchmark/confusion_matrix.png`
- `evals/benchmark/pr_curve.png`
- `evals/benchmark/reliability_curve.png`
- `evals/benchmark/final_report.md`
