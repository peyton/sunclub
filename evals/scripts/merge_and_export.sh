#!/usr/bin/env bash
#
# Merge LoRA adapter back into base model, then export to MLX for iOS.
#
# Prerequisites:
#   1. Completed LoRA training (train_lora.sh)
#   2. apple/ml-fastvlm repo with coremltools and mlx-vlm installed
#
# Usage:
#   bash evals/scripts/merge_and_export.sh <fastvlm-repo> <base-checkpoint> <lora-dir> [output-dir]
#
# Example:
#   bash evals/scripts/merge_and_export.sh \
#     ~/ml-fastvlm \
#     ~/ml-fastvlm/checkpoints/llava-fastvithd-0.5b_stage3 \
#     evals/checkpoints/sunscreen-lora-v1 \
#     evals/export/sunscreen-mlx-v1

set -euo pipefail

FASTVLM_REPO="${1:?Usage: merge_and_export.sh <fastvlm-repo> <base-checkpoint> <lora-dir> [output-dir]}"
BASE_CHECKPOINT="${2:?Missing base checkpoint path}"
LORA_DIR="${3:?Missing LoRA directory}"
OUTPUT_DIR="${4:-evals/export/sunscreen-mlx-v1}"

MERGED_DIR="${OUTPUT_DIR}/merged-pytorch"
MLX_DIR="${OUTPUT_DIR}/mlx"

mkdir -p "$MERGED_DIR" "$MLX_DIR"

echo "=== Step 1: Merging LoRA adapter into base model ==="

python3 -c "
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

print('Loading base model...')
base = AutoModelForCausalLM.from_pretrained('$BASE_CHECKPOINT', torch_dtype=torch.bfloat16)
tokenizer = AutoTokenizer.from_pretrained('$BASE_CHECKPOINT')

print('Loading LoRA adapter...')
model = PeftModel.from_pretrained(base, '$LORA_DIR')

print('Merging weights...')
merged = model.merge_and_unload()

print('Saving merged model...')
merged.save_pretrained('$MERGED_DIR')
tokenizer.save_pretrained('$MERGED_DIR')
print('Merged model saved to: $MERGED_DIR')
"

echo ""
echo "=== Step 2: Exporting vision encoder to CoreML ==="

cd "$FASTVLM_REPO"
python model_export/export_vision_encoder.py \
    --model-path "$MERGED_DIR" \
    --output-dir "$MLX_DIR"

echo ""
echo "=== Step 3: Exporting LLM to MLX format ==="

# Uses the patched mlx-vlm (see FastVLM model_export/README.md)
python -m mlx_vlm.convert \
    --hf-path "$MERGED_DIR" \
    --mlx-path "$MLX_DIR" \
    --q-bits 16

echo ""
echo "=== Export complete ==="
echo "MLX model ready at: $MLX_DIR"
echo ""
echo "To use in the app:"
echo "  cp -R $MLX_DIR/* app/FastVLM/model/"
echo "  just build"
