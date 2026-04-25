#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"

export SUNCLUB_SKIP_LOCAL_TUIST_CACHE="${SUNCLUB_SKIP_LOCAL_TUIST_CACHE:-1}"
setup_local_tooling_env

hk_steps=(
  markdown
  pkl
  pkl-format
  shellcheck
  shfmt
  actionlint
  zizmor
  prettier
  ruff
  ruff_format
)

hk_args=(check --all)
for step in "${hk_steps[@]}"; do
  hk_args+=(--step "$step")
done

run_mise_exec hk "${hk_args[@]}"

if [ "$(uname -s)" = "Darwin" ]; then
  (
    cd "$REPO_ROOT/app"
    run_mise_exec swiftlint lint \
      --config .swiftlint.yml \
      --cache-path "$REPO_ROOT/.cache/swiftlint" \
      Workspace.swift \
      Tuist.swift \
      Tuist/Package.swift \
      Sunclub
  )
fi
