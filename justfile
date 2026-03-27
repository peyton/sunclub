#!/usr/bin/env -S just --working-directory . --justfile

model_dir := "model"
model_marker := "app/Frameworks/FastVLM/Sources/model/config.json"
staged_model_dir := "app/Generated/FastVLMODR/model"

[private]
@default:
    just --list

bootstrap:
    bash scripts/tooling/bootstrap.sh

[group('model')]
download-model:
    bash scripts/get_pretrained_mlx_model.sh --model 0.5b --dest "{{ model_dir }}"

[group('app')]
icons:
    bash scripts/generate-app-icons.sh

[group('app')]
generate-icons: icons

[group('app')]
appstore-validate:
    ./bin/mise exec -- uv run python -m scripts.appstore.validate_metadata --allow-draft

[group('app')]
appstore-screenshots:
    bash scripts/appstore/capture-screenshots.sh

[group('app')]
appstore-archive:
    bash scripts/appstore/archive-and-upload.sh

[group('model')]
check-model:
    if [ -f "{{ model_marker }}" ]; then exit 0; fi; printf '%s\n' "FastVLM model files are missing at {{ model_dir }}. Run 'just download-model' from the repo root and retry." >&2; exit 1

[group('model')]
prepare-model: check-model

[group('app')]
generate:
    bash scripts/tooling/generate.sh

[group('app')]
build:
    bash scripts/tooling/build.sh

[group('app')]
run:
    bash scripts/tooling/run.sh

[group('maintenance')]
clean-build:
    rm -rf .build .DerivedData app/build app/Sunclub.xcworkspace

[group('maintenance')]
clean-generated: clean-build
    rm -rf evals/datasets evals/export .state .venv .ruff_cache .rumdl_cache .pytest_cache .cache .mise .config
    find . -type d -name '__pycache__' -prune -exec rm -rf {} +

[group('maintenance')]
clean-model: clean-generated
    if [ -d "{{ staged_model_dir }}" ]; then find "{{ staged_model_dir }}" -mindepth 1 ! -name '.keep' -exec rm -rf {} +; fi

[group('maintenance')]
clean: clean-model

test-unit:
    bash scripts/tooling/test_ios.sh --suite unit

test-ui:
    bash scripts/tooling/test_ios.sh --suite ui

test-python:
    ./bin/mise exec -- uv run pytest tests -v

test: test-unit test-ui test-python

lint:
    bash scripts/tooling/lint.sh

fmt:
    bash scripts/tooling/fmt.sh

ci-lint: lint

ci-python: test-python

ci-build:
    bash scripts/tooling/ci_build.sh

ci: ci-lint ci-python test-unit test-ui ci-build

# --- Eval & Fine-Tuning ---

collect-data output_dir="evals/datasets/sunscreen-v1":
    ./bin/mise exec -- uv run --group eval python -m evals.scripts.collect_data --output-dir "{{ output_dir }}"

collect-data-quick output_dir="evals/datasets/sunscreen-v1":
    ./bin/mise exec -- uv run --group eval python -m evals.scripts.collect_data --output-dir "{{ output_dir }}" --max-queries 2

benchmark dataset="evals/datasets/sunscreen-v1/eval.json":
    ./bin/mise exec -- uv run --group eval --with mlx-vlm python -m evals.benchmark.benchmark --dataset "{{ dataset }}" --model-dir "{{ model_dir }}" --verbose

benchmark-strict dataset="evals/datasets/sunscreen-v1/eval.json":
    ./bin/mise exec -- uv run --group eval --with mlx-vlm python -m evals.benchmark.benchmark --dataset "{{ dataset }}" --model-dir "{{ model_dir }}" --strict
