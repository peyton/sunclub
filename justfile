#!/usr/bin/env -S just --justfile

download-model:
    bash scripts/get_pretrained_mlx_model.sh --model 0.5b --dest app/Sunclub/FastVLMModel/model

