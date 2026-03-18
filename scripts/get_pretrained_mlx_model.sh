#!/usr/bin/env bash
#
# Based on Apple's FastVLM sample app download flow:
# https://github.com/apple/ml-fastvlm/tree/main/app

set -euo pipefail

show_help() {
  local exit_code="${1:-1}"
  cat <<'EOF'
Usage: get_pretrained_mlx_model.sh --model <size> --dest <directory>

Required arguments:
  --model   Model size to download: 0.5b, 1.5b, or 7b
  --dest    Directory where the model will be extracted

Options:
  --help    Show this help message
EOF
  exit "$exit_code"
}

model_size=""
dest_dir=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --model)
      model_size="${2:-}"
      shift 2
      ;;
    --dest)
      dest_dir="${2:-}"
      shift 2
      ;;
    --help)
      show_help 0
      ;;
    *)
      echo "Unknown parameter: $1" >&2
      show_help 1
      ;;
  esac
done

if [[ -z "$model_size" ]]; then
  echo "Missing required argument: --model" >&2
  show_help 1
fi

if [[ -z "$dest_dir" ]]; then
  echo "Missing required argument: --dest" >&2
  show_help 1
fi

case "$model_size" in
  0.5b) model_name="llava-fastvithd_0.5b_stage3_llm.fp16" ;;
  1.5b) model_name="llava-fastvithd_1.5b_stage3_llm.int8" ;;
  7b) model_name="llava-fastvithd_7b_stage3_llm.int4" ;;
  *)
    echo "Unsupported model size: $model_size" >&2
    show_help 1
    ;;
esac

base_url="https://ml-site.cdn-apple.com/datasets/fastvlm"
tmp_dir="$(mktemp -d)"
tmp_zip_file="${tmp_dir}/${model_name}.zip"
tmp_extract_dir="${tmp_dir}/${model_name}"

cleanup() {
  rm -rf "$tmp_dir"
}

trap cleanup EXIT INT TERM

mkdir -p "$dest_dir"
if [[ -n "$(find "$dest_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
  echo "Clearing existing contents in '$dest_dir'"
  rm -rf "${dest_dir:?}/"*
fi

mkdir -p "$tmp_extract_dir"

echo "Downloading '${model_name}' model..."
curl --fail --location --progress-bar \
  --output "$tmp_zip_file" \
  "$base_url/$model_name.zip"

echo "Unzipping model..."
unzip -q "$tmp_zip_file" -d "$tmp_extract_dir"

echo "Copying model files to '$dest_dir'..."
cp -R "$tmp_extract_dir/$model_name/." "$dest_dir"

if [[ ! -f "$dest_dir/config.json" ]]; then
  echo "Model download failed: '$dest_dir/config.json' was not created" >&2
  exit 1
fi

echo "Model downloaded to '$dest_dir'"
