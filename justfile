app_workspace := "app/Sunclub.xcworkspace"
app_scheme := "Sunclub"
device_name := "iPhone 17 Pro"
test_simulator_name := "Sunclub Test iPhone 17 Pro"
model_dir := "app/Generated/FastVLMODR/model"
model_marker := "app/Generated/FastVLMODR/model/config.json"
build_derived_data := ".DerivedData/build"
run_derived_data := ".DerivedData/run"
test_derived_data := ".DerivedData/test"
run_app_path := ".DerivedData/run/Build/Products/Debug-iphonesimulator/Sunclub.app"
app_identifier := "app.peyton.sunclub"
test_xcargs := "-parallel-testing-enabled NO -maximum-parallel-testing-workers 1"

download-model:
    bash scripts/get_pretrained_mlx_model.sh --model 0.5b --dest "{{model_dir}}"

icons:
    bash scripts/generate-app-icons.sh

appstore-validate:
    python3 scripts/appstore/validate_metadata.py --allow-draft

appstore-screenshots:
    bash scripts/appstore/capture-screenshots.sh

check-model:
    if [ -f "{{model_marker}}" ]; then exit 0; fi; printf '%s\n' "FastVLM model files are missing at {{model_dir}}. Run 'just download-model' from the repo root and retry." >&2; exit 1

prepare-model: check-model

generate:
    cd app && tuist install && tuist generate --no-open

build: generate
    xcodebuild clean build \
      -workspace "{{app_workspace}}" \
      -scheme "{{app_scheme}}" \
      -configuration Release \
      -destination 'generic/platform=iOS' \
      -derivedDataPath "{{build_derived_data}}" \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO

run: generate
    xcodebuild clean build \
      -workspace "{{app_workspace}}" \
      -scheme "{{app_scheme}}" \
      -configuration Debug \
      -sdk iphonesimulator \
      -destination "platform=iOS Simulator,name={{device_name}}" \
      -derivedDataPath "{{run_derived_data}}"
    xcrun simctl boot "{{device_name}}" || true
    xcrun simctl bootstatus booted -b
    xcrun simctl install booted "{{run_app_path}}"
    xcrun simctl launch booted "{{app_identifier}}"

test-unit: generate
    SIMULATOR_UDID="$(python3 scripts/resolve_simulator.py --name '{{test_simulator_name}}' --device-type-name '{{device_name}}')"; \
    xcrun simctl shutdown "$SIMULATOR_UDID" >/dev/null 2>&1 || true; \
    xcrun simctl erase "$SIMULATOR_UDID" >/dev/null 2>&1 || true; \
    xcodebuild test \
      -workspace "{{app_workspace}}" \
      -scheme "{{app_scheme}}" \
      -configuration Debug \
      -destination "id=$SIMULATOR_UDID" \
      -derivedDataPath "{{test_derived_data}}" \
      -only-testing:SunclubTests \
      {{test_xcargs}}

test-ui: generate
    SIMULATOR_UDID="$(python3 scripts/resolve_simulator.py --name '{{test_simulator_name}}' --device-type-name '{{device_name}}')"; \
    xcrun simctl shutdown "$SIMULATOR_UDID" >/dev/null 2>&1 || true; \
    xcrun simctl erase "$SIMULATOR_UDID" >/dev/null 2>&1 || true; \
    xcodebuild test \
      -workspace "{{app_workspace}}" \
      -scheme "{{app_scheme}}" \
      -configuration Debug \
      -destination "id=$SIMULATOR_UDID" \
      -derivedDataPath "{{test_derived_data}}" \
      -only-testing:SunclubUITests/SunclubUITests \
      {{test_xcargs}}

test-python:
    uv run python -m unittest discover -s tests -p 'test_*.py'

test: test-unit test-ui test-python

ci: test build
