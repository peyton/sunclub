# Few-Shot Bottle Matching: Benchmark & App Implementation Spec

## Context

Sunclub verifies a user's sunscreen bottle using Apple Vision's `VNFeaturePrintObservation`. During onboarding the user captures 5 photos of their bottle. At verification time, each camera frame is compared against those 5 stored feature prints using `FeaturePrintMatcher`.

The current benchmark (in `evals/benchmark/` and `eval/`) evaluates matching accuracy against a fixed enrollment set sourced from OpenBeautyFacts product images. This works for measuring general feature-print quality but doesn't reflect the real usage pattern: a specific user's 5 handheld photos of *their* bottle are the enrollment set, not catalog images.

This spec covers two things:

1. A benchmark structure that models the real few-shot matching scenario and weights user-provided enrollment images appropriately.
2. The app-side implementation details for making the 5 onboarding photos the dominant signal in verification.

---

## 1. Benchmark Structure

### 1.1 Design Principles

The benchmark must answer one question: *given 5 enrollment photos that a user took of their bottle, how reliably does the matcher accept that bottle and reject everything else?*

General-purpose "is this any sunscreen" accuracy matters less than per-enrollment-set accuracy. The benchmark should reflect this by:

- Running evaluation per enrollment set (simulating different users with different bottles).
- Weighting the per-enrollment metric heavily in the composite score.
- Including a general negative set that stays constant across all enrollment sets.

### 1.2 Directory Layout

```
benchmark/
├── enrollments/                 # one subfolder per simulated user
│   ├── avene_protect_50/
│   │   ├── enroll_000.jpg       # 5 enrollment photos (handheld-style)
│   │   ├── enroll_001.jpg
│   │   ├── enroll_002.jpg
│   │   ├── enroll_003.jpg
│   │   └── enroll_004.jpg
│   ├── neutrogena_ultra_sheer/
│   │   └── ...                  # 5 enrollment photos
│   └── ...                      # 3–6 enrollment sets total
├── test/
│   ├── test_positive_000.jpg    # general sunscreen-present images
│   ├── ...
│   ├── test_negative_000.jpg    # general no-sunscreen images
│   └── ...
├── val/
│   ├── val_positive_000.jpg
│   ├── ...
│   ├── val_negative_000.jpg
│   └── ...
├── matched/                     # per-enrollment positive test images
│   ├── avene_protect_50/
│   │   ├── match_000.jpg        # same bottle, different angle/lighting
│   │   ├── ...                  # 10–20 images per enrollment set
│   │   └── match_019.jpg
│   ├── neutrogena_ultra_sheer/
│   │   └── ...
│   └── ...
└── manifest.json                # ties everything together
```

### 1.3 Image Categories

**Enrollment images** (`enrollments/<bottle>/enroll_NNN.jpg`): 5 photos per bottle, shot handheld at slightly different angles and distances. These simulate the onboarding capture. Source these by photographing real bottles or pulling varied product shots from OpenBeautyFacts.

**Matched positives** (`matched/<bottle>/match_NNN.jpg`): 10–20 additional photos of the same bottle, taken in different conditions (lighting, background, partial occlusion, distance). These are the images the matcher *should* accept for that enrollment set. Think of these as "the user pointing their phone at the bottle on different days."

**General positives** (`test/test_positive_NNN.jpg`, `val/val_positive_NNN.jpg`): Sunscreen bottles that are *not* one of the enrolled bottles. These should be *rejected* by the per-enrollment matcher — they test that the matcher doesn't just accept "any sunscreen." These are the images currently in `benchmark/test/` and `benchmark/val/`.

**General negatives** (`test/test_negative_NNN.jpg`, `val/val_negative_NNN.jpg`): No sunscreen present. Bathroom scenes, beach towels, similar-looking bottles (lotion, shampoo), hands, outdoor scenes. Should always be rejected.

### 1.4 Manifest Format

`benchmark/manifest.json`:

```json
{
  "enrollment_sets": [
    {
      "id": "avene_protect_50",
      "enrollment_images": [
        "enrollments/avene_protect_50/enroll_000.jpg",
        "enrollments/avene_protect_50/enroll_001.jpg",
        "enrollments/avene_protect_50/enroll_002.jpg",
        "enrollments/avene_protect_50/enroll_003.jpg",
        "enrollments/avene_protect_50/enroll_004.jpg"
      ],
      "matched_positives": [
        "matched/avene_protect_50/match_000.jpg",
        "matched/avene_protect_50/match_001.jpg"
      ]
    }
  ],
  "general_positives": {
    "test": ["test/test_positive_000.jpg"],
    "val": ["val/val_positive_000.jpg"]
  },
  "general_negatives": {
    "test": ["test/test_negative_000.jpg"],
    "val": ["val/val_negative_000.jpg"]
  }
}
```

### 1.5 Evaluation Protocol

For each enrollment set `E`:

1. Compute feature prints for the 5 enrollment images. These become the "stored payloads" — exactly as `TrainingAsset.featurePrintData` works in the app.
2. Score every image in `matched/<E>/` against the 5 enrollment prints. Expected label: **accept** (1).
3. Score every image in `test/test_positive_*` against the 5 enrollment prints. Expected label: **reject** (0). These are sunscreen, but not *this* bottle.
4. Score every image in `test/test_negative_*` against the 5 enrollment prints. Expected label: **reject** (0).
5. Record per-image: `{enrollment_set, sample_id, distances[], accepted, label, best_distance, consensus_distance, confidence}`.

### 1.6 Composite Scoring

Three metrics are computed per enrollment set:

| Metric | What It Measures | Source Images |
|---|---|---|
| **Matched recall** | Does it accept the enrolled bottle? | `matched/<E>/*` (label=1) |
| **Cross-bottle rejection** | Does it reject other sunscreen? | `test/test_positive_*` (label=0) |
| **Negative rejection** | Does it reject non-sunscreen? | `test/test_negative_*` (label=0) |

The composite score for each enrollment set:

```
enrollment_score = 0.50 * matched_recall
                 + 0.25 * cross_bottle_precision
                 + 0.25 * negative_precision
```

The overall benchmark score is the *minimum* enrollment score across all enrollment sets (worst-case user experience), not the average. This penalizes configurations that work well for some bottles but fail for others.

### 1.7 Threshold Sweep

Run the existing `threshold_sweep` logic from `eval/metrics.py` but scoped to per-enrollment data. The goal is to find the operating point that maximizes matched recall while keeping cross-bottle false-accept rate below 5%.

### 1.8 Reporting

Extend the existing `eval/report.py` to produce:

- Per-enrollment confusion matrix (matched vs. cross-bottle vs. negative).
- Composite score table across all enrollment sets.
- Worst-case enrollment set highlighted with failure analysis.
- Distance distribution histograms: matched positives vs. cross-bottle positives vs. negatives.

Output to `evals/benchmark/fewshot_report.md`.

---

## 2. App Implementation Details

### 2.1 Current Architecture (No Changes Needed)

The app's verification pipeline already implements few-shot matching correctly:

1. **Onboarding** (`TrainingCoordinator`): Captures 5 photos → extracts `VNFeaturePrintObservation` per photo → serializes and stores as `TrainingAsset` in SwiftData.
2. **Verification** (`VideoVerificationCoordinator`): Samples every 5th camera frame → extracts feature print → calls `FeaturePrintMatcher.evaluate()` against the 5 stored payloads → requires 12 consecutive positive frames to confirm.
3. **Matching** (`FeaturePrintMatcher`): Computes distances to all 5 enrollment prints. Accepts if `bestDistance <= 0.58` (direct hit) OR if `supportCount >= 2` and `consensusDistance <= 0.60`.

This is already a few-shot matcher by design. The 5 enrollment photos *are* the model. No changes to the core pipeline are needed.

### 2.2 Enrollment Quality Gate (New)

Add a quality check after the 5th onboarding photo is captured. The goal is to catch bad enrollment sets before the user starts using the app.

**Implementation in `TrainingView` / `TrainingCoordinator`:**

After all 5 captures are stored, compute pairwise distances between the 5 enrollment feature prints. If the enrollment set is good (photos of the same bottle from slightly different angles), the intra-set distances should be low and consistent.

```swift
// In TrainingCoordinator, after 5th capture:
func validateEnrollmentQuality(payloads: [Data]) -> EnrollmentQuality {
    let prints = payloads.compactMap {
        VisionFeaturePrintService.shared.deserialize($0)
    }
    guard prints.count >= 5 else { return .insufficient }

    var distances: [Float] = []
    for i in 0..<prints.count {
        for j in (i+1)..<prints.count {
            var d: Float = 0
            try? prints[i].computeDistance(&d, to: prints[j])
            distances.append(d)
        }
    }

    let mean = distances.reduce(0, +) / Float(distances.count)
    let maxDist = distances.max() ?? 0

    // Thresholds derived from benchmark enrollment sets
    if mean > 0.65 || maxDist > 0.80 {
        return .poor       // likely different objects or blurry
    } else if mean > 0.50 {
        return .marginal   // warn but allow
    } else {
        return .good
    }
}

enum EnrollmentQuality {
    case insufficient, poor, marginal, good
}
```

**UX behavior:**

- `.good`: Proceed to notification prompt normally.
- `.marginal`: Show a soft warning ("Your photos look a bit different from each other — try keeping the bottle centered and well-lit") with options to retake or continue anyway.
- `.poor`: Show a stronger prompt ("We couldn't get a consistent read on your bottle — let's try again") and reset the capture flow.
- `.insufficient`: Should not happen (captures are gated to 5), but handle as `.poor`.

### 2.3 Confidence Signal During Verification (New)

Currently `LiveVerifyView` shows a binary detecting/not-detecting state. Add a confidence signal so the user gets feedback on how close the match is.

**Implementation in `VideoVerificationCoordinator`:**

The `FeaturePrintMatchResult` already contains `bestDistance` and `consensusDistance`. Compute a 0–1 confidence from the margin to the threshold:

```swift
extension FeaturePrintMatchResult {
    var confidence: Float {
        guard let best = bestDistance, let consensus = consensusDistance else { return 0 }
        let cfg = FeaturePrintMatchConfiguration.video
        let margin = max(
            cfg.directHitThreshold - best,
            cfg.consensusThreshold - consensus
        )
        // Sigmoid centered at the threshold boundary
        return 1.0 / (1.0 + exp(-(margin / 0.04)))
    }
}
```

Expose this in `VideoVerificationResult` and use it to drive a visual indicator (ring fill, color gradient) in `LiveVerifyView`.

### 2.4 Adaptive Threshold (Future Consideration)

Not for this version, but worth noting: once the benchmark has data from multiple enrollment sets, we can explore per-enrollment threshold adaptation. The idea is to tighten thresholds for enrollment sets with very low intra-set distances (highly consistent captures) and loosen them for noisier sets. This would live in `FeaturePrintMatcher` as an optional config override.

---

## 3. Benchmark ↔ App Alignment Checklist

The benchmark must use the same code paths as the app wherever possible to avoid train/serve skew:

| Component | App | Benchmark | Aligned? |
|---|---|---|---|
| Feature extraction | `VNGenerateImageFeaturePrintRequest` via `VisionFeaturePrintService` | `VNGenerateImageFeaturePrintRequest` via `featureprint_cli.swift` | Yes — same Vision API |
| Distance computation | `VNFeaturePrintObservation.computeDistance(_:to:)` | Same | Yes |
| Match decision | `FeaturePrintMatcher.evaluate()` with `.video` config | `decide()` in `run_eval.py` with `current_video` config | Yes — thresholds match |
| Enrollment count | 5 photos (`TrainingCoordinator`) | 5 images per enrollment set | Yes |
| Image preprocessing | Camera frame → `CVPixelBuffer` → Vision | `CGImage` from file → Vision | Close — camera frames have compression artifacts and motion blur that static images don't. Benchmark `matched/` images should include some of this. |
| Consecutive-frame logic | 12 consecutive accepts required | Not modeled (single-frame eval) | Intentional gap — benchmark tests per-frame accuracy. Consecutive logic is a UX smoothing layer. |

---

## 4. Migration Plan

### Phase 1: Benchmark Data (Now)

- [x] General test/val negatives and positives populated from Unsplash (300 images in `benchmark/test/` and `benchmark/val/`).
- [ ] Create `benchmark/enrollments/` with 3–6 enrollment sets. Source from OpenBeautyFacts product images or photograph real bottles.
- [ ] Create `benchmark/matched/` with 10–20 varied photos per enrollment set.
- [ ] Write `benchmark/manifest.json`.

### Phase 2: Evaluation Pipeline

- [ ] Extend `eval/featureprint_cli.swift` to accept per-enrollment scoring (loop over enrollment sets instead of a single enrollment manifest).
- [ ] Add `eval/fewshot_eval.py` that implements the composite scoring from §1.6.
- [ ] Extend `eval/report.py` with per-enrollment reporting.

### Phase 3: App Changes

- [ ] Add `EnrollmentQuality` validation to `TrainingCoordinator` (§2.2).
- [ ] Add `confidence` computed property to `FeaturePrintMatchResult` (§2.3).
- [ ] Wire confidence signal into `LiveVerifyView`.

### Phase 4: Tuning

- [ ] Run threshold sweep per enrollment set.
- [ ] Determine if current `.video` thresholds are optimal or if per-enrollment adaptation is needed.
- [ ] Set pass/fail criteria for CI: composite score ≥ 0.85, worst-case enrollment score ≥ 0.75.
