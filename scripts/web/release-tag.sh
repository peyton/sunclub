#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'web-release-tag: VERSION must be semver, for example 1.2.3\n' >&2
}

fail() {
  printf 'web-release-tag: %s\n' "$1" >&2
  exit 1
}

ROOT_DIR="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$ROOT_DIR"

version="${VERSION:-${1:-}}"
[ -n "$version" ] || {
  usage
  exit 2
}

version="${version#web/v}"
version="${version#v}"

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  usage
  exit 2
}

[ -z "$(git status --short)" ] ||
  fail "working tree must be clean before tagging"

tag="web/v$version"

git rev-parse --verify --quiet "refs/tags/$tag" >/dev/null &&
  fail "tag $tag already exists"

git tag -a "$tag" -m "Web release $tag"
git push origin "$tag"

printf 'Created and pushed %s\n' "$tag"
