#!/usr/bin/env -S just --working-directory . --justfile

app_workspace := "app/Sunclub.xcworkspace"
app_scheme := "Sunclub"
device_name := "iPhone 17 Pro"
test_simulator_name := "Sunclub Test iPhone 17 Pro"
model_dir := "model"
model_marker := "app/Frameworks/FastVLM/Sources/model/config.json"
build_derived_data := ".DerivedData/build"
run_derived_data := ".DerivedData/run"
test_derived_data := ".DerivedData/test"
result_derived_data := ".DerivedData/result"
run_app_path := "Build/Products/Debug-iphonesimulator/Sunclub.app"
app_identifier := "app.peyton.sunclub"
test_xcargs := "-parallel-testing-enabled NO -maximum-parallel-testing-workers 1"

[private]
@default:
    just --list

bootstrap:
    ./bin/mise install

[group('model')]
download-model:
    bash scripts/get_pretrained_mlx_model.sh --model 0.5b --dest "{{ model_dir }}"

[group('app')]
generate-icons:
    bash scripts/generate-app-icons.sh

[group('app')]
appstore-validate:
    python3 scripts/appstore/validate_metadata.py --allow-draft

[group('app')]
appstore-screenshots:
    bash scripts/appstore/capture-screenshots.sh

[group('model')]
check-model:
    if [ -f "{{ model_marker }}" ]; then exit 0; fi; printf '%s\n' "FastVLM model files are missing at {{ model_dir }}. Run 'just download-model' from the repo root and retry." >&2; exit 1

[group('model')]
prepare-model: check-model

[group('app')]
generate:
    cd app && tuist install && tuist generate --no-open

[group('app')]
build: generate
    #!/usr/bin/env sh
    set -euo pipefail
    BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ci-build.XXXXXX")"
    BUILD_ROOT="$BUILD_ROOT" \
      WORKSPACE="{{ app_workspace }}" \
      SCHEME="{{ app_scheme }}" \
      CONFIGURATION="Release" \
      DESTINATION="generic/platform=iOS" \
      bash scripts/app-build.sh

[group('app')]
run: generate
    #!/usr/bin/env bash
    set -euo pipefail
    BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ci-build.XXXXXX")"

    BUILD_ROOT="$BUILD_ROOT" \
    WORKSPACE="{{ app_workspace }}" \
      SCHEME="{{ app_scheme }}" \
      CONFIGURATION="Debug" \
      DESTINATION="platform=iOS Simulator,name={{ device_name }}" \
      bash scripts/app-build.sh
    xcrun simctl boot "{{ device_name }}" || true
    xcrun simctl bootstatus booted -b
    xcrun simctl install booted "$BUILD_ROOT/DerivedData/{{ run_app_path }}"
    xcrun simctl launch booted "{{ app_identifier }}"

test-unit: generate
    #!/usr/bin/env bash
    set -euo pipefail
    BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ci-build.XXXXXX")"
    RESULT_BUNDLE="$BUILD_ROOT/ResultBundle.xcresult"

    SIMULATOR_UDID="$(python3 scripts/resolve_simulator.py --name '{{ test_simulator_name }}' --device-type-name '{{ device_name }}')"; \
    xcrun simctl shutdown "$SIMULATOR_UDID" >/dev/null 2>&1 || true; \
    xcrun simctl erase "$SIMULATOR_UDID" >/dev/null 2>&1 || true; \
    tuist xcodebuild test \
      -workspace "{{ app_workspace }}" \
      -scheme "{{ app_scheme }}" \
      -configuration Debug \
      -destination "id=$SIMULATOR_UDID" \
      -derivedDataPath "{{ test_derived_data }}" \
      -resultBundlePath "$RESULT_BUNDLE" \
      -only-testing:SunclubTests \
      {{ test_xcargs }}

test-ui: generate
    #!/usr/bin/env bash
    set -euo pipefail
    BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ci-build.XXXXXX")"
    RESULT_BUNDLE="$BUILD_ROOT/ResultBundle.xcresult"

    SIMULATOR_UDID="$(python3 scripts/resolve_simulator.py --name '{{ test_simulator_name }}' --device-type-name '{{ device_name }}')"; \
    xcrun simctl shutdown "$SIMULATOR_UDID" >/dev/null 2>&1 || true; \
    xcrun simctl erase "$SIMULATOR_UDID" >/dev/null 2>&1 || true; \
    mise exec -- tuist xcodebuild test \
      -workspace "{{ app_workspace }}" \
      -scheme "{{ app_scheme }}" \
      -configuration Debug \
      -destination "id=$SIMULATOR_UDID" \
      -derivedDataPath "{{ test_derived_data }}" \
      -resultBundlePath "$RESULT_BUNDLE" \
      -only-testing:SunclubUITests/SunclubUITests \
      {{ test_xcargs }}

test-python:
    uv run python -m unittest discover -s tests -p 'test_*.py'

test: test-unit test-ui test-python

lint:
    hk check --all

fmt:
    hk fix --all

ci: lint test build

# --- Eval & Fine-Tuning ---

collect-data output_dir="evals/datasets/sunscreen-v1":
    pip install -q -r evals/requirements.txt
    python3 evals/scripts/collect_data.py --output-dir "{{ output_dir }}"

collect-data-quick output_dir="evals/datasets/sunscreen-v1":
    pip install -q -r evals/requirements.txt
    python3 evals/scripts/collect_data.py --output-dir "{{ output_dir }}" --max-queries 2

benchmark dataset="evals/datasets/sunscreen-v1/eval.json":
    python3 evals/benchmark/benchmark.py --dataset "{{ dataset }}" --model-dir "{{ model_dir }}" --verbose

benchmark-strict dataset="evals/datasets/sunscreen-v1/eval.json":
    python3 evals/benchmark/benchmark.py --dataset "{{ dataset }}" --model-dir "{{ model_dir }}" --strict
