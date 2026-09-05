#!/usr/bin/env bash
set -euo pipefail

TOOLING_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TOOLING_DIR/../.." && pwd)"

set -a
# shellcheck source=/dev/null
source "$TOOLING_DIR/sunclub.env"
set +a

normalize_flavor() {
  case "${1:-dev}" in
  prod) printf 'prod' ;;
  *) printf 'dev' ;;
  esac
}

apply_flavor_defaults() {
  SUNCLUB_FLAVOR="$(normalize_flavor "${SUNCLUB_FLAVOR:-dev}")"

  if [ -z "${APP_SCHEME:-}" ]; then
    if [ "$SUNCLUB_FLAVOR" = "prod" ]; then
      APP_SCHEME="$RELEASE_APP_SCHEME"
    else
      APP_SCHEME="$DEV_APP_SCHEME"
    fi
  fi

  if [ -z "${APP_IDENTIFIER:-}" ]; then
    if [ "$SUNCLUB_FLAVOR" = "prod" ]; then
      APP_IDENTIFIER="$RELEASE_APP_IDENTIFIER"
    else
      APP_IDENTIFIER="$DEV_APP_IDENTIFIER"
    fi
  fi

  if [ -z "${RUN_APP_PATH:-}" ]; then
    if [ "$APP_SCHEME" = "$RELEASE_APP_SCHEME" ]; then
      RUN_APP_PATH="Build/Products/Debug-iphonesimulator/$RELEASE_APP_PRODUCT_NAME.app"
    else
      RUN_APP_PATH="Build/Products/Debug-iphonesimulator/$DEV_APP_PRODUCT_NAME.app"
    fi
  fi

  export SUNCLUB_FLAVOR APP_SCHEME APP_IDENTIFIER RUN_APP_PATH
}

resolve_version_metadata() {
  if [ "${SUNCLUB_SKIP_VERSION_RESOLUTION:-0}" = "1" ]; then
    return 0
  fi

  local exports
  if [ "${1:-development}" = "release" ]; then
    set --
  else
    set -- --development
  fi
  if ! exports="$(run_repo_python_module scripts.tooling.resolve_versions --format shell "$@")"; then
    printf 'Error: version resolution failed\n' >&2
    return 1
  fi
  eval "$exports"
  export SUNCLUB_MARKETING_VERSION SUNCLUB_BUILD_NUMBER
}

export_tuist_manifest_env() {
  export TUIST_SUNCLUB_FLAVOR="$SUNCLUB_FLAVOR"
  export TUIST_SUNCLUB_MARKETING_VERSION="${SUNCLUB_MARKETING_VERSION:-}"
  export TUIST_SUNCLUB_BUILD_NUMBER="${SUNCLUB_BUILD_NUMBER:-}"
  export TUIST_SUNCLUB_APS_ENVIRONMENT="${SUNCLUB_APS_ENVIRONMENT:-development}"
  export TUIST_TEAM_ID="${TEAM_ID:-}"
}

# Local cache service installation is an explicit, optional operation.
setup_local_tuist_cache() {
  setup_local_tooling_env
  run_in_app run_mise_exec tuist setup cache
}

prepare_xcode_env() {
  if [ "${sunclub_xcode_env_ready:-0}" = "1" ]; then
    return 0
  fi
  setup_local_tooling_env
  apply_flavor_defaults
  resolve_version_metadata "${1:-development}"
  export_tuist_manifest_env
  export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
  sunclub_xcode_env_ready=1
}

run_tuist_xcodebuild() {
  local log_file exit_code
  # GitHub setup starts the cache service. Local commands must work without it.
  local default_cache_disabled=1
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    default_cache_disabled=0
  fi
  if [ "${SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE:-$default_cache_disabled}" = "1" ]; then
    set -- COMPILATION_CACHE_ENABLE_CACHING=NO COMPILATION_CACHE_ENABLE_PLUGIN=NO COMPILATION_CACHE_ENABLE_DIAGNOSTIC_REMARKS=NO "$@"
  fi

  log_file="$(mktemp "${TMPDIR:-/tmp}/sunclub-tuist-xcodebuild.XXXXXX")"

  set +e
  run_in_app run_mise_exec tuist xcodebuild "$@" 2>&1 | tee "$log_file"
  exit_code="${PIPESTATUS[0]}"
  set -e

  if [ "$exit_code" -eq 0 ]; then
    rm -f "$log_file"
    return 0
  fi

  if [ "$exit_code" -eq 133 ] &&
    grep -Eq '(^|[[:space:]])Build Succeeded($|[[:space:]])|(^|[[:space:]])Test Succeeded($|[[:space:]])|\*\* TEST SUCCEEDED \*\*|Test Suite .+ passed' "$log_file" &&
    ! grep -Eq '\*\* (BUILD|TEST) FAILED \*\*|Test Suite .+ failed|with [1-9][0-9]* failures|:[0-9]+: error: -\[' "$log_file"; then
    printf 'Warning: tuist xcodebuild exited with Trace/BPT trap after a successful Xcode result; treating as success.\n' >&2
    rm -f "$log_file"
    return 0
  fi

  rm -f "$log_file"
  return "$exit_code"
}

ensure_local_state() {
  mkdir -p \
    "$REPO_ROOT/.build" \
    "$REPO_ROOT/.cache/hk" \
    "$REPO_ROOT/.cache/npm" \
    "$REPO_ROOT/.cache/swiftlint" \
    "$REPO_ROOT/.cache/uv" \
    "$REPO_ROOT/.config" \
    "$REPO_ROOT/.config/mise" \
    "$REPO_ROOT/.state/hk"
}

source_appstore_review_env() {
  local review_env="$REPO_ROOT/.state/appstore/review.env"
  if [ ! -f "$review_env" ]; then
    return 0
  fi

  set -a
  # shellcheck source=/dev/null
  source "$review_env"
  set +a
}

setup_local_tooling_env() {
  ensure_local_state

  export MISE_CONFIG_DIR="$REPO_ROOT/.config/mise"
  export MISE_TRUSTED_CONFIG_PATHS="$REPO_ROOT"
  export MISE_YES="${MISE_YES:-1}"
  export UV_CACHE_DIR="$REPO_ROOT/.cache/uv"
  export UV_PROJECT_ENVIRONMENT="$REPO_ROOT/.venv"
  export HK_CACHE_DIR="$REPO_ROOT/.cache/hk"
  export HK_STATE_DIR="$REPO_ROOT/.state/hk"
  export npm_config_cache="$REPO_ROOT/.cache/npm"

  export MISE_LOCKED=1
  export UV_FROZEN=true
}

run_mise() {
  MISE_CONFIG_DIR="${MISE_CONFIG_DIR:-$REPO_ROOT/.config/mise}" \
    MISE_TRUSTED_CONFIG_PATHS="${MISE_TRUSTED_CONFIG_PATHS:-$REPO_ROOT}" \
    MISE_YES="${MISE_YES:-1}" \
    mise "$@"
}

run_mise_exec() {
  run_mise exec -- "$@"
}

run_repo_python_module() {
  (cd "$REPO_ROOT" && run_mise_exec uv run python -m "$@")
}

run_in_app() {
  (
    cd "$REPO_ROOT/app"
    "$@"
  )
}

generation_fingerprint() {
  run_repo_python_module scripts.tooling.workspace_fingerprint
}

generate_workspace() {
  prepare_xcode_env
  local fingerprint
  fingerprint="${1:-$(generation_fingerprint)}"
  if [ -f "$REPO_ROOT/app/Tuist/Package.resolved" ]; then
    run_in_app run_mise_exec tuist install --force-resolved-versions
  fi
  run_in_app run_mise_exec tuist generate --no-open
  printf '%s\n' "$fingerprint" >"$REPO_ROOT/$APP_WORKSPACE/.sunclub-fingerprint"
}

ensure_workspace_generated() {
  prepare_xcode_env
  local fingerprint marker
  fingerprint="$(generation_fingerprint)"
  marker="$REPO_ROOT/$APP_WORKSPACE/.sunclub-fingerprint"
  if [ -f "$marker" ] && [ "$(cat "$marker")" = "$fingerprint" ] &&
    [ -f "$REPO_ROOT/app/Sunclub/Sunclub.xcodeproj/xcshareddata/xcschemes/$APP_SCHEME.xcscheme" ]; then
    return 0
  fi
  generate_workspace "$fingerprint"
}

prepare_ci_workspace() {
  setup_local_tooling_env
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    run_in_app run_mise_exec tuist auth login
  fi
  setup_local_tuist_cache
}

resolve_simulator_udid() {
  run_repo_python_module scripts.resolve_simulator \
    --name "$1" \
    --device-type-name "$2"
}

has_app_store_connect_auth() {
  [ -n "${ASC_KEY_FILE:-}" ] &&
    [ -n "${ASC_KEY_ID:-}" ] &&
    [ -n "${ASC_ISSUER_ID:-}" ]
}
