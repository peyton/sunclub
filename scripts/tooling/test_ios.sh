#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

prepare_xcode_env

suite=""
test_filter=""

while [ $# -gt 0 ]; do
  case "$1" in
  --filter)
    test_filter="$2"
    shift 2
    ;;
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
ui-smoke)
  only_testing="SunclubUITests/SunclubSmokeUITests"
  ;;
ui)
  only_testing="SunclubUITests"
  ;;
*)
  printf 'Missing or invalid --suite. Use unit, ui-smoke or ui.\n' >&2
  exit 2
  ;;
esac

if [ -n "$test_filter" ]; then
  only_testing="$only_testing/$test_filter"
fi
ensure_workspace_generated

result_bundle_path="$REPO_ROOT/.build/test-$suite.xcresult"
xcodebuild_log_path="$REPO_ROOT/.build/test-$suite.xcodebuild.log"
test_xcodebuild_args=()
if [ -n "${TEST_XCODEBUILD_ARGS:-}" ]; then
  read -r -a test_xcodebuild_args <<<"$TEST_XCODEBUILD_ARGS"
fi

test_scheme="${TEST_APP_SCHEME:-$RELEASE_APP_SCHEME}"

simulator_udid="$(resolve_simulator_udid "$TEST_SIMULATOR_NAME" "$DEFAULT_SIMULATOR_DEVICE")"

reset_test_simulator() {
  xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
  xcrun simctl erase "$simulator_udid" >/dev/null 2>&1 || true
}

is_simulator_launch_error() {
  grep -Eq \
    'CoreSimulatorService|Mach error -308|Invalid device state|Failed to install or launch the test runner|Test crashed with signal (kill|term)|Simulator device failed to launch|FBSOpenApplicationServiceErrorDomain|Application info provider .* returned nil' \
    "$xcodebuild_log_path"
}

has_xctest_failure() {
  grep -Eq ':[0-9]+: error: -\[|XCTAssert|Test Case .+ failed' "$xcodebuild_log_path"
}

reset_test_simulator

xcodebuild_args=(
  test
  -workspace "$REPO_ROOT/$APP_WORKSPACE"
  -scheme "$test_scheme"
  -configuration Debug
  -destination "id=$simulator_udid"
  -derivedDataPath "$REPO_ROOT/$TEST_DERIVED_DATA"
  -resultBundlePath "$result_bundle_path"
  "-only-testing:$only_testing"
)

if [ "${#test_xcodebuild_args[@]}" -gt 0 ]; then
  xcodebuild_args+=("${test_xcodebuild_args[@]}")
fi

mkdir -p "$REPO_ROOT/.build"
max_attempts="${TEST_XCODEBUILD_MAX_ATTEMPTS:-3}"
attempt=1

while true; do
  rm -rf "$result_bundle_path"

  set +e
  run_tuist_xcodebuild "${xcodebuild_args[@]}" 2>&1 | tee "$xcodebuild_log_path"
  status=${PIPESTATUS[0]}
  set -e

  if [ "$status" -eq 0 ]; then
    break
  fi

  if [ "$attempt" -ge "$max_attempts" ] || has_xctest_failure || ! is_simulator_launch_error; then
    exit "$status"
  fi

  attempt=$((attempt + 1))
  printf 'xcodebuild hit a simulator launch error; resetting simulator and retrying (%s/%s).\n' \
    "$attempt" \
    "$max_attempts"
  reset_test_simulator
  killall -9 com.apple.CoreSimulator.CoreSimulatorService >/dev/null 2>&1 || true
  sleep 2
done
