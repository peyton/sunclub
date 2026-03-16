# Sunscreen object-recognition verification report

## Model discovery

- Task: instance retrieval / same-bottle verification using Vision feature prints, not generic classification or detection.
- Inference entrypoints in app: `SelfieCaptureCoordinator` and `VideoVerificationCoordinator` through `VisionFeaturePrintService`.
- Preprocessing: no explicit fixed resize in app code; raw photo/frame is passed into `VNGenerateImageFeaturePrintRequest`, which performs its own internal preprocessing.
- Current operating points mirrored in evaluation: selfie direct<=0.56 or consensus<=0.59 with support>=2; video direct<=0.58 or consensus<=0.60 with support>=2.
- Baseline comparison: legacy min-distance<=18.5 rule.

## Dataset summary

- Seed training corpus size: 21
- Enrollment images: 3
- Validation benchmark size: 63
- Test benchmark size: 90

## Leakage checks

- Train/test exact hash overlap: 0
- Val/test exact hash overlap: 0
- Val/test parent-source overlap: 0
- Benchmark target family leaked into seed train corpus: 0

## Headline metrics (test split)

- legacy: accuracy=0.200, precision=0.200, recall=1.000, f1=0.333, pr_auc=0.147, roc_auc=0.310
- current_selfie: accuracy=0.800, precision=0.000, recall=0.000, f1=0.000, pr_auc=0.149, roc_auc=0.319
- current_video: accuracy=0.800, precision=0.000, recall=0.000, f1=0.000, pr_auc=0.149, roc_auc=0.319

## Manual benchmark review

- Random samples inspected: 20
- Findings: manual review log present

## Largest error modes

- current_video rejected all 18 positives on the held-out test split.
- bright_sunlight: recall 0.00 on 2 positives (2 false negatives).
- clean_products: recall 0.00 on 2 positives (2 false negatives).
- cluttered_scenes: recall 0.00 on 2 positives (2 false negatives).
- in_the_wild: recall 0.00 on 2 positives (2 false negatives).
- low_light: recall 0.00 on 2 positives (2 false negatives).
- motion_blur: recall 0.00 on 2 positives (2 false negatives).
- multi_object_scenes: recall 0.00 on 2 positives (2 false negatives).
- non_english_packaging: recall 0.00 on 2 positives (2 false negatives).
- partial_occlusion: recall 0.00 on 2 positives (2 false negatives).

## Risks and limitations

- Disjointness is guaranteed only across the web data collected in this pipeline and the checked repo contents, not against any unknown historical data used before this repo state.
- Benchmark positives and many hard slices are generated from held-out public web images plus deterministic transforms, so they are better for regression checking than for absolute real-world performance claims.
- Confidence calibration uses a derived distance-margin score because the current model does not emit a native calibrated probability.
- No zero-shot vision baseline was added because the repo and local environment do not already ship one, and downloading a separate external model would materially change the evaluation stack.

## Artifacts

- `manifests/train_manifest.jsonl`
- `manifests/val_manifest.jsonl`
- `manifests/test_manifest.jsonl`
- `manifests/benchmark_manifest.jsonl`
- `evals/benchmark/slice_metrics.csv`
- `evals/benchmark/confusion_matrix.png`
- `evals/benchmark/pr_curve.png`
- `evals/benchmark/reliability_curve.png`
- `evals/benchmark/final_report.md`
