#!/usr/bin/env -S just --justfile

download-model:
    bash scripts/get_pretrained_mlx_model.sh --model 0.5b --dest app/Sunclub/FastVLM/model

prepare-model:
    cd app && mise exec -- fastlane prepare_model

build:
    cd app && mise exec -- fastlane build

run:
    cd app && mise exec -- fastlane launch

test:
    cd app && mise exec -- fastlane tests

test-unit:
    cd app && mise exec -- fastlane unit_tests

test-ui:
    cd app && mise exec -- fastlane ui_tests

ci:
    cd app && mise exec -- fastlane ci
