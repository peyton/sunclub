#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

"$ROOT/fetch_openbeautyfacts_dataset.sh"
swift "$ROOT/run_feature_print_benchmark.swift" "$@"
