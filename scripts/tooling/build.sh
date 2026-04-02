#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

setup_local_tooling_env

configuration="Release"
destination="generic/platform=iOS"
derived_data_path=""
result_bundle_path=""
build_root=""
build_root_explicit=0
code_signing="none"
share_scheme=1
run_generate=1

if [ "${SUNCLUB_TUIST_SHARE:-1}" = "0" ]; then
  share_scheme=0
fi

while [ $# -gt 0 ]; do
  case "$1" in
  --configuration)
    configuration="$2"
    shift 2
    ;;
  --destination)
    destination="$2"
    shift 2
    ;;
  --derived-data-path)
    derived_data_path="$2"
    shift 2
    ;;
  --result-bundle-path)
    result_bundle_path="$2"
    shift 2
    ;;
  --build-root)
    build_root="$2"
    build_root_explicit=1
    shift 2
    ;;
  --signing)
    code_signing="$2"
    shift 2
    ;;
  --skip-share)
    share_scheme=0
    shift
    ;;
  --skip-generate)
    run_generate=0
    shift
    ;;
  *)
    printf 'Unknown argument: %s\n' "$1" >&2
    exit 2
    ;;
  esac
done

if [ -z "$build_root" ]; then
  build_root="$REPO_ROOT/.build"
fi

if [ -z "$derived_data_path" ]; then
  if [ "$build_root_explicit" -eq 1 ]; then
    derived_data_path="$build_root/DerivedData"
  else
    derived_data_path="$REPO_ROOT/$BUILD_DERIVED_DATA"
  fi
fi

if [ -z "$result_bundle_path" ]; then
  result_bundle_path="$build_root/build.xcresult"
fi

mkdir -p "$(dirname "$derived_data_path")" "$(dirname "$result_bundle_path")"
rm -rf "$result_bundle_path"

if [ "$run_generate" -eq 1 ]; then
  ensure_workspace_generated
fi

printf 'BUILD_ROOT=%s\n' "$build_root"
printf 'DERIVED_DATA=%s\n' "$derived_data_path"
printf 'RESULT_BUNDLE=%s\n' "$result_bundle_path"

build_args=(
  -workspace "$REPO_ROOT/$APP_WORKSPACE"
  -scheme "$APP_SCHEME"
  -configuration "$configuration"
  -destination "$destination"
  -derivedDataPath "$derived_data_path"
  -resultBundlePath "$result_bundle_path"
)

if [ "$code_signing" = "none" ]; then
  build_args+=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
fi

xcodebuild "${build_args[@]}" build

if [ "$share_scheme" -eq 1 ]; then
  run_in_app run_mise_exec tuist share \
    "$APP_SCHEME" \
    --configuration "$configuration" \
    --derived-data-path "$derived_data_path" \
    --platforms iOS
fi
