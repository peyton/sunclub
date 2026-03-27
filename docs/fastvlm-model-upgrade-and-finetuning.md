# FastVLM: Model Upgrade & Fine-Tuning Research

Research into two questions: (1) upgrading the base LLM from Qwen2.5 to a newer model, and (2) fine-tuning FastVLM for sunscreen detection.

## Current Setup

| Component      | Value                                                                                                         |
| -------------- | ------------------------------------------------------------------------------------------------------------- |
| Model          | FastVLM 0.5B (Stage 3), fp16                                                                                  |
| Vision encoder | FastViTHD → exported to CoreML `.mlpackage`                                                                   |
| Language model | Qwen2-0.5B → exported via patched mlx-vlm                                                                     |
| Prompt         | `"Is there sunscreen or a sunscreen bottle in this image? Answer ONLY with YES or NO. If unsure, answer NO."` |
| Inference      | MLX on-device, temperature 0.0, max 8 tokens                                                                  |
| Frame sampling | Every 15th frame at 1280×720, 2 consecutive YES required                                                      |
| Source         | Apple CDN: `ml-site.cdn-apple.com/datasets/fastvlm`                                                           |
| Upstream repo  | `apple/ml-fastvlm` (CVPR 2025)                                                                                |

## Architecture Overview

```text
Camera Frame (CVPixelBuffer)
    │
    ▼
FastViTHD Vision Encoder (CoreML .mlpackage)
    │  outputs image token embeddings
    ▼
Multimodal Projector (linear, in MLX)
    │  projects vision tokens into LLM embedding space
    ▼
Qwen2-0.5B Language Model (MLX, fp16)
    │  generates YES/NO text
    ▼
SunscreenResponseParser → SunscreenDetectionAnswer
```

Key architectural property: the vision encoder, projector, and LLM are cleanly decoupled. `llava_arch.py` (the glue layer) only depends on `embed_tokens()` and `hidden_size` — standard HuggingFace APIs any model family exposes.

---

## Question 1: Can We Upgrade from Qwen2 to a Newer Model?

### Short answer

**Yes, but it requires re-training the full FastVLM pipeline (not just swapping weights), and the export toolchain needs updates.** It's a medium-sized engineering project, not a config change.

### What needs to change

| Component                        | Qwen2-specific?                  | Work required                                                                                 |
| -------------------------------- | -------------------------------- | --------------------------------------------------------------------------------------------- |
| `llava_arch.py` (vision mixin)   | No                               | None                                                                                          |
| `llava_qwen.py` (LLM wrapper)    | **Yes, hardcoded**               | Create `llava_qwen3.py` with `Qwen3Config/Model/ForCausalLM` imports (~140 lines, mechanical) |
| `train_qwen.py`                  | Indirectly                       | Register new model type, update conversation template                                         |
| `export_vision_encoder.py`       | No (vision only)                 | Update `conv_mode` default                                                                    |
| MLX export (patched mlx-vlm)     | **Yes**                          | Patch must be updated for Qwen3 architecture in mlx-vlm                                       |
| `pyproject.toml`                 | **Yes** (`transformers==4.48.3`) | Bump to `transformers>=4.52` (Qwen3 support)                                                  |
| iOS app (`FastVLMService.swift`) | No                               | None — loads whatever MLX model is in the bundle                                              |

### Why you can't just swap weights

FastVLM's multimodal projector is **trained** to bridge FastViTHD's vision token embeddings into a _specific_ LLM's embedding space. If you change the LLM from Qwen2-0.5B to Qwen3-Xb:

- The embedding dimensions may differ
- The token vocabulary is different
- The projector weights are meaningless for the new LLM

You must re-train at minimum Stage 2 (visual instruction tuning) and Stage 3 (fine-tuning) with the new LLM backbone. Stage 1 (vision encoder pre-training) can likely be reused since FastViTHD is LLM-agnostic.

### Practical considerations

- **Is Qwen3 even better for this task?** For a binary YES/NO classification from a 0.5B model at temperature 0.0, the LLM is barely doing "reasoning." The bottleneck is almost certainly the vision encoder's ability to recognize sunscreen in varied conditions, not the language model's capability. Upgrading the LLM is unlikely to meaningfully improve detection accuracy.
- **Training cost**: Full Stage 2 + Stage 3 training requires multi-GPU setup with DeepSpeed and the LLaVA training data (665K instruction-tuning samples). This is a multi-day training run.
- **Export risk**: The MLX export path uses a specific patched commit of mlx-vlm (`1884b551`). A new LLM architecture needs this patch updated — this is the least-documented part of the pipeline.

### Recommendation

**Don't upgrade the base LLM.** The cost-benefit is poor for a YES/NO classification task. Fine-tuning the existing model (Question 2) is a much higher-leverage investment.

---

## Question 2: Can We Fine-Tune FastVLM for Sunscreen Detection?

### Short answer

**Yes, and this is the high-leverage path.** The FastVLM training pipeline supports fine-tuning with LoRA, and the data format is well-documented (LLaVA conversation format).

### Training infrastructure

| Requirement        | Details                                                                    |
| ------------------ | -------------------------------------------------------------------------- |
| Framework          | LLaVA training codebase (included in `apple/ml-fastvlm`)                   |
| Script             | `llava/train/train_qwen.py`                                                |
| Distributed        | DeepSpeed ZeRO (required for 1.5B+, optional for 0.5B)                     |
| LoRA support       | Yes — `peft>=0.10.0` with `lora_r=64, lora_alpha=16`                       |
| GPU requirement    | 0.5B with LoRA: single A100/H100 (or even A10G). Full fine-tune: 2-4x A100 |
| Quantized training | Supported via `bitsandbytes` (4-bit, 8-bit)                                |

### Data format (LLaVA conversation format)

```json
[
  {
    "id": "sunscreen_001",
    "image": "images/sunscreen_001.jpg",
    "conversations": [
      {
        "from": "human",
        "value": "<image>\nIs there sunscreen or a sunscreen bottle in this image? Answer ONLY with YES or NO. If unsure, answer NO."
      },
      {
        "from": "gpt",
        "value": "YES"
      }
    ]
  }
]
```

### Dataset strategy

To fine-tune effectively, we need labeled images covering the failure modes:

| Category                                | Examples                                           | Label |
| --------------------------------------- | -------------------------------------------------- | ----- |
| Clear positive                          | Sunscreen bottle in hand, applying to skin         | YES   |
| Clear negative                          | Empty room, person without sunscreen               | NO    |
| Hard positive — partial occlusion       | Bottle partially visible, hand covering label      | YES   |
| Hard positive — varied lighting         | Backlit, low light, harsh shadows                  | YES   |
| Hard positive — unusual containers      | Spray bottles, stick sunscreen, travel size        | YES   |
| Hard positive — application in progress | White cream on skin, rubbing motion                | YES   |
| Hard negative — similar objects         | Lotion (not sunscreen), white bottles, moisturizer | NO    |
| Hard negative — skin reflections        | Shiny/oily skin without sunscreen                  | NO    |
| Environmental variety                   | Outdoors, bathroom, beach, car, pool               | Both  |

**Recommended dataset size**: 500–2,000 labeled images. For LoRA fine-tuning of a 0.5B model, even 500 well-curated examples can meaningfully shift behavior.

### Fine-tuning approach (recommended)

**LoRA fine-tune of Stage 3 checkpoint** — this preserves the model's general vision-language understanding while specializing it for sunscreen detection.

```bash
# Pseudocode — actual command uses the FastVLM training args
python llava/train/train_qwen.py \
  --model_name_or_path <path-to-stage3-0.5b-checkpoint> \
  --data_path sunscreen_train.json \
  --image_folder ./images/ \
  --lora_enable True \
  --lora_r 64 \
  --lora_alpha 16 \
  --num_train_epochs 3 \
  --per_device_train_batch_size 4 \
  --learning_rate 2e-5 \
  --model_max_length 128 \
  --bf16 True \
  --output_dir ./checkpoints/sunscreen-lora
```

After training, merge LoRA weights back into the base model, then run the MLX export pipeline.

### Export back to iOS

1. Merge LoRA adapter into base model weights
2. Export vision encoder to CoreML (unchanged — `export_vision_encoder.py`)
3. Export LLM to MLX format using patched mlx-vlm (quantize as needed)
4. Replace model files in the app bundle
5. No Swift code changes needed — `FastVLMService` loads whatever model is at the model directory

### Tooling (implemented)

All scripts live in `evals/`:

| Tool             | Command                                                             | What it does                                                                                       |
| ---------------- | ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Data collection  | `just collect-data`                                                 | Downloads YouTube videos, extracts frames, labels with Claude Vision, outputs LLaVA-format dataset |
| Quick test       | `just collect-data-quick`                                           | Same but only 2 queries (for testing the pipeline)                                                 |
| LoRA training    | `bash evals/scripts/train_lora.sh <repo> <ckpt> <dataset>`          | Runs LoRA fine-tune on FastVLM Stage 3 checkpoint                                                  |
| Merge + export   | `bash evals/scripts/merge_and_export.sh <repo> <ckpt> <lora> [out]` | Merges LoRA, exports to CoreML + MLX                                                               |
| Benchmark        | `just benchmark`                                                    | Runs eval dataset through model, reports accuracy/precision/recall/F1                              |
| Strict benchmark | `just benchmark-strict`                                             | Same but exits non-zero if F1 < 80%                                                                |

**Data collection pipeline** (`evals/scripts/collect_data.py`):

1. Searches YouTube for sunscreen-positive and negative queries (20 queries total)
2. Downloads 2 videos per query via `yt-dlp`
3. Extracts 10 frames per video via `ffmpeg` (every 3s, scaled to 1280x720)
4. Labels each frame with Claude Vision (Sonnet) — resumable, saves progress after each label
5. Splits 80/20 into `train.json` (LLaVA format) + `eval.json` (benchmark format)

**Requirements**: `ANTHROPIC_API_KEY` env var, `yt-dlp`, `ffmpeg`. Install deps: `pip install -r evals/requirements.txt`

### Risk: catastrophic forgetting

LoRA mitigates this well for small models. However, since our task is extremely narrow (YES/NO), there's a risk the model becomes _too_ specialized and starts answering YES/NO to unrelated prompts. This is acceptable for Sunclub since the prompt is fixed, but worth noting.

---

## Recommendation

| Path                                      | Effort                                                 | Impact                                                           | Recommendation                           |
| ----------------------------------------- | ------------------------------------------------------ | ---------------------------------------------------------------- | ---------------------------------------- |
| Upgrade Qwen2 → Qwen3                     | High (re-train full pipeline, update export toolchain) | Low (YES/NO task doesn't benefit from better LLM)                | **Skip**                                 |
| Fine-tune existing 0.5B on sunscreen data | Medium (data collection + LoRA training + export)      | **High** (directly improves detection accuracy in failure cases) | **Do this**                              |
| Fine-tune larger model (1.5B/7B)          | High (bigger dataset, more compute, worse latency)     | Medium (diminishing returns for binary classification)           | Consider only if 0.5B fine-tune plateaus |

### End-to-end workflow

```bash
# 1. Collect and label training data (requires ANTHROPIC_API_KEY)
just collect-data

# 2. Baseline benchmark (requires mlx-vlm)
just benchmark

# 3. Clone FastVLM repo and download PyTorch checkpoint
git clone https://github.com/apple/ml-fastvlm.git ~/ml-fastvlm
cd ~/ml-fastvlm && pip install -e ".[train]" && bash get_models.sh

# 4. LoRA fine-tune
bash evals/scripts/train_lora.sh ~/ml-fastvlm ~/ml-fastvlm/checkpoints/llava-fastvithd-0.5b_stage3 evals/datasets/sunscreen-v1

# 5. Merge LoRA + export to MLX
bash evals/scripts/merge_and_export.sh ~/ml-fastvlm ~/ml-fastvlm/checkpoints/llava-fastvithd-0.5b_stage3 evals/checkpoints/sunscreen-lora-v1

# 6. Post-training benchmark (compare to baseline)
just benchmark

# 7. Deploy to app
cp -R evals/export/sunscreen-mlx-v1/mlx/* app/FastVLM/model/
just build
```
