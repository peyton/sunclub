# Independent recognition benchmark

This folder contains a standalone benchmark for the Vision feature-print matcher used by the app.

What it does:

- pulls a small public sunscreen/toiletry image set from Open Beauty Facts
- generates deterministic train, positive-test, and negative-test variants
- runs the legacy min-distance matcher and the app's current selfie/video consensus matchers
- prints precision/recall/F1 so the matcher can be checked outside the iOS app

Run it:

```sh
cd /Users/peyton/Projects/sun-day
./Benchmarks/benchmark.sh --strict
```

Artifacts:

- raw source images: `Benchmarks/Datasets/raw`
- generated benchmark images: `Benchmarks/Datasets/generated`
- manifest: `Benchmarks/dataset_manifest.json`

Notes:

- The raw images come from Open Beauty Facts.
- The benchmark uses deterministic augmentations of the raw product shots because the app's real training data is captured by the user in-app.
- The `video` benchmark is single-frame only. The app adds an additional consecutive-frame debounce on top of that.
