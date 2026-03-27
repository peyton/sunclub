#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env

suite=""

while [ $# -gt 0 ]; do
  case "$1" in
  --suite)
    suite="$2"
    shift 2
    ;;
  *)
    printf 'Unknown argument: %s\n' "$1" >&2
    exit 2
    ;;
  esac
done

case "$suite" in
unit)
  only_testing="SunclubTests"
  ;;
ui)
  only_testing="SunclubUITests/SunclubUITests"
  ;;
*)
  printf 'Missing or invalid --suite. Use unit or ui.\n' >&2
  exit 2
  ;;
esac

ensure_workspace_generated

result_bundle_path="$REPO_ROOT/.build/test-$suite.xcresult"
test_xcodebuild_args=()
read -r -a test_xcodebuild_args <<<"${TEST_XCODEBUILD_ARGS:-}"

simulator_udid="$(resolve_simulator_udid "$TEST_SIMULATOR_NAME" "$DEFAULT_SIMULATOR_DEVICE")"
xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
xcrun simctl erase "$simulator_udid" >/dev/null 2>&1 || true
rm -rf "$result_bundle_path"

xcodebuild \
  test \
  -workspace "$REPO_ROOT/$APP_WORKSPACE" \
  -scheme "$APP_SCHEME" \
  -configuration Debug \
  -destination "id=$simulator_udid" \
  -derivedDataPath "$REPO_ROOT/$TEST_DERIVED_DATA" \
  -resultBundlePath "$result_bundle_path" \
  "-only-testing:$only_testing" \
  "${test_xcodebuild_args[@]}"
