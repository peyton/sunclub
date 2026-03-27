#!/usr/bin/env bash
set -euo pipefail

TOOLING_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$TOOLING_DIR/../.." && pwd)"

set -a
# shellcheck source=/dev/null
source "$TOOLING_DIR/sunclub.env"
set +a

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

setup_local_tooling_env() {
  ensure_local_state

  export UV_CACHE_DIR="$REPO_ROOT/.cache/uv"
  export UV_PROJECT_ENVIRONMENT="$REPO_ROOT/.venv"
  export HK_CACHE_DIR="$REPO_ROOT/.cache/hk"
  export HK_STATE_DIR="$REPO_ROOT/.state/hk"
  export npm_config_cache="$REPO_ROOT/.cache/npm"
}

run_mise() {
  mise "$@"
}

run_mise_exec() {
  run_mise exec -- "$@"
}

run_repo_python_module() {
  run_mise_exec uv run python -m "$@"
}

run_eval_python_module() {
  run_mise_exec uv run --group eval python -m "$@"
}

run_in_app() {
  (
    cd "$REPO_ROOT/app"
    "$@"
  )
}

generate_workspace() {
  run_in_app run_mise_exec tuist install --force-resolved-versions
  run_in_app run_mise_exec tuist generate --no-open
}

workspace_is_generated() {
  [ -d "$REPO_ROOT/$APP_WORKSPACE" ]
}

ensure_workspace_generated() {
  if workspace_is_generated; then
    return 0
  fi

  generate_workspace
}

prepare_ci_workspace() {
  local mode="${1:-github-actions}"

  case "$mode" in
  github-actions)
    if [ "${GITHUB_ACTIONS:-}" != "true" ]; then
      printf 'Skipping GitHub Actions Tuist setup outside GitHub Actions.\n'
      return 0
    fi

    run_in_app run_mise_exec tuist auth login
    run_in_app run_mise_exec tuist setup cache
    ;;
  xcode-cloud)
    run_in_app run_mise_exec tuist setup insights
    run_in_app run_mise_exec tuist setup cache
    ;;
  *)
    printf 'Unknown CI workspace mode: %s\n' "$mode" >&2
    return 2
    ;;
  esac
}

resolve_simulator_udid() {
  run_repo_python_module scripts.resolve_simulator \
    --name "$1" \
    --device-type-name "$2"
}
