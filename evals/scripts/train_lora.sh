#!/usr/bin/env bash
#
# LoRA fine-tune FastVLM 0.5B for sunscreen detection.
#
# Prerequisites:
#   1. Clone apple/ml-fastvlm and install: pip install -e ".[train]"
#   2. Download Stage 3 PyTorch checkpoint: bash get_models.sh (from the FastVLM repo)
#   3. Build dataset: python evals/scripts/collect_data.py --output-dir evals/datasets/sunscreen-v1
#
# Usage:
#   bash evals/scripts/train_lora.sh <fastvlm-repo-path> <checkpoint-path> <dataset-dir> [output-dir]
#
# Example:
#   bash evals/scripts/train_lora.sh \
#     ~/ml-fastvlm \
#     ~/ml-fastvlm/checkpoints/llava-fastvithd-0.5b_stage3 \
#     evals/datasets/sunscreen-v1 \
#     evals/checkpoints/sunscreen-lora-v1

set -euo pipefail

FASTVLM_REPO="${1:?Usage: train_lora.sh <fastvlm-repo> <checkpoint> <dataset-dir> [output-dir]}"
CHECKPOINT="${2:?Missing checkpoint path}"
DATASET_DIR="${3:?Missing dataset directory}"
OUTPUT_DIR="${4:-evals/checkpoints/sunscreen-lora-v1}"

TRAIN_JSON="${DATASET_DIR}/train.json"
IMAGES_DIR="${DATASET_DIR}/images"

if [[ ! -f $TRAIN_JSON ]]; then
	echo "ERROR: $TRAIN_JSON not found. Run collect_data.py first." >&2
	exit 1
fi

if [[ ! -d $IMAGES_DIR ]]; then
	echo "ERROR: $IMAGES_DIR not found." >&2
	exit 1
fi

TRAIN_SCRIPT="${FASTVLM_REPO}/llava/train/train_qwen.py"
if [[ ! -f $TRAIN_SCRIPT ]]; then
	echo "ERROR: $TRAIN_SCRIPT not found. Is FASTVLM_REPO correct?" >&2
	exit 1
fi

NUM_IMAGES=$(find "$IMAGES_DIR" -name '*.jpg' | wc -l | tr -d ' ')
echo "Training with $NUM_IMAGES images from $DATASET_DIR"
echo "Base checkpoint: $CHECKPOINT"
echo "Output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

# The training script must be run from the FastVLM repo root
cd "$FASTVLM_REPO"

python llava/train/train_qwen.py \
	--model_name_or_path "$CHECKPOINT" \
	--data_path "$TRAIN_JSON" \
	--image_folder "$IMAGES_DIR" \
	--vision_tower "$(find "$CHECKPOINT" -name 'fastvithd*' -type d | head -1)" \
	--mm_projector_type linear \
	--mm_patch_merge_type flat \
	--image_aspect_ratio square \
	--lora_enable True \
	--lora_r 64 \
	--lora_alpha 16 \
	--mm_vision_select_layer -2 \
	--mm_vision_select_feature patch \
	--bf16 True \
	--output_dir "$OUTPUT_DIR" \
	--num_train_epochs 5 \
	--per_device_train_batch_size 4 \
	--gradient_accumulation_steps 2 \
	--learning_rate 2e-5 \
	--weight_decay 0.0 \
	--warmup_ratio 0.03 \
	--lr_scheduler_type cosine \
	--model_max_length 128 \
	--logging_steps 1 \
	--save_strategy epoch \
	--save_total_limit 3 \
	--dataloader_num_workers 4 \
	--report_to none

echo ""
echo "Training complete. LoRA adapter saved to: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "  1. Merge LoRA:  python evals/scripts/merge_and_export.py $CHECKPOINT $OUTPUT_DIR"
echo "  2. Run eval:    python evals/benchmark/benchmark.py --dataset evals/datasets/sunscreen-v1/eval.json --model-dir <merged-model>"
