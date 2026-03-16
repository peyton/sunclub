#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
MANIFEST_PATH="$ROOT/dataset_manifest.json"
RAW_DIR="$ROOT/Datasets/raw"

mkdir -p "$RAW_DIR"

python3 - "$MANIFEST_PATH" "$RAW_DIR" <<'PY' | while IFS=$'\t' read -r filename url; do
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
raw_dir = pathlib.Path(sys.argv[2])
manifest = json.loads(manifest_path.read_text())
items = [manifest["target"], *manifest["negatives"]]

for item in items:
    print(f"{item['filename']}\t{item['url']}")
PY
    target_path="$RAW_DIR/$filename"
    if [ -f "$target_path" ]; then
        echo "Cached $filename"
        continue
    fi

    echo "Downloading $filename"
    curl -L --fail --silent --show-error "$url" -o "$target_path"
done
