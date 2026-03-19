app_workspace := "app/Sunclub.xcworkspace"
app_scheme := "Sunclub"
device_name := "iPhone 17 Pro"
model_dir := "app/FastVLM/model"
model_marker := "app/FastVLM/model/config.json"
build_derived_data := ".DerivedData/build"
run_derived_data := ".DerivedData/run"
test_derived_data := ".DerivedData/test"
run_app_path := ".DerivedData/run/Build/Products/Debug-iphonesimulator/Sunclub.app"
app_identifier := "app.peyton.sunclub"
test_xcargs := "-parallel-testing-enabled NO -maximum-parallel-testing-workers 1"

download-model:
    bash scripts/get_pretrained_mlx_model.sh --model 0.5b --dest "{{model_dir}}"

check-model:
    if [ -f "{{model_marker}}" ]; then exit 0; fi; printf '%s\n' "FastVLM model files are missing at {{model_dir}}. Run 'just download-model' from the repo root and retry." >&2; exit 1

prepare-model: check-model

generate:
    cd app && tuist install && tuist generate --no-open

build: check-model generate
    xcodebuild clean build \
      -workspace "{{app_workspace}}" \
      -scheme "{{app_scheme}}" \
      -configuration Release \
      -destination 'generic/platform=iOS' \
      -derivedDataPath "{{build_derived_data}}" \
      CODE_SIGNING_ALLOWED=NO \
      CODE_SIGNING_REQUIRED=NO

run: check-model generate
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

test-unit: check-model generate
    xcodebuild test \
      -workspace "{{app_workspace}}" \
      -scheme "{{app_scheme}}" \
      -configuration Debug \
      -destination "platform=iOS Simulator,name={{device_name}}" \
      -derivedDataPath "{{test_derived_data}}" \
      -only-testing:SunclubTests \
      {{test_xcargs}}

test-ui: check-model generate
    xcodebuild test \
      -workspace "{{app_workspace}}" \
      -scheme "{{app_scheme}}" \
      -configuration Debug \
      -destination "platform=iOS Simulator,name={{device_name}}" \
      -derivedDataPath "{{test_derived_data}}" \
      -only-testing:SunclubUITests/SunclubUITests \
      {{test_xcargs}}

test: test-unit test-ui

ci: test build
