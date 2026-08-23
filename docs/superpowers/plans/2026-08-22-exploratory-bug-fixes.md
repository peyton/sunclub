# Exploratory Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix ten reproducible defects found in Sunclub release tooling, web validation/packaging, Cloudflare setup, and the watch target without changing user data behavior.

**Architecture:** Keep fixes at the narrow helper seams where each defect originates. Add one focused regression test per defect, run it red before production changes, then run the affected test module and the complete Python/lint/build verification.

**Tech Stack:** Python 3.14, pytest, Swift/Xcode asset catalogs, Cloudflare/App Store Connect REST helpers, deterministic tar/gzip packaging.

**Spec:** Exploratory audit authorized by the user in the current task; repository contract in `AGENTS.md`.

## Global Constraints

- Use TDD: each production-code change follows a failing regression test.
- Do not add dependencies.
- Preserve user data, SwiftData schemas, CloudKit behavior, signing inputs, and existing public-site copy.
- Use `apply_patch` for source/test/config edits.
- Run the closest repository verification after each affected group and `UV_CACHE_DIR=/tmp/sunclub-uv just test-python` plus `UV_CACHE_DIR=/tmp/sunclub-uv just ci-lint` before completion.
- The watch asset fix must use a valid Xcode color asset and preserve existing icon resources.

---

### Task 1: Isolate Explicit Environment Mappings

**Files:**

- Modify: `scripts/appstore/connect_api.py:AppStoreConnectCredentials.from_env`
- Modify: `scripts/appstore/manifest.py:merged_review_environment`
- Modify: `scripts/appstore/testflight_groups.py:build_context`
- Modify: `scripts/appstore/submit_review.py:resolve_submission_context`
- Test: `tests/test_appstore_connect_api.py`, `tests/test_appstore_metadata_validator.py`, `tests/test_testflight_groups.py`, `tests/test_appstore_submit_review.py`

**Behavior:** Passing `environment={}` must use no ambient process variables. Passing `None` retains the current process-environment behavior. This prevents credentials, release versions, and review metadata from changing based on unrelated shell state.

- [x] Write focused failing tests using `monkeypatch` to set a sentinel process variable, then pass an explicit empty mapping and assert the sentinel is ignored.
- [x] Run the focused tests and confirm they fail because the current `or os.environ` expressions leak the sentinel.
- [x] Replace each `environment or os.environ` expression with an explicit `is None` check.
- [x] Run all four affected test modules and confirm they pass.

### Task 2: Reject Network-Path Site Links

**Files:**

- Modify: `scripts/web/validate_static_site.py:validate_internal_link`
- Test: `tests/test_web_static_site.py`

**Behavior:** A URL beginning with `//` is an external network-path reference and must be rejected, rather than resolved beneath the local web root.

- [x] Add a minimal temporary page containing `<a href="//evil.example/path">...`.
- [x] Run the validator test and confirm the current implementation reports no error.
- [x] Reject parsed URLs with a non-empty `netloc` before local-path resolution, with a clear unsupported URL error.
- [x] Run the web validator tests.

### Task 3: Make Manifest Reference Discovery Match Resolution

**Files:**

- Modify: `scripts/appstore/manifest.py:collect_env_reference_names`
- Test: `tests/test_appstore_metadata_validator.py`

**Behavior:** Only dictionaries consisting solely of the supported `env`/`equals` keys and containing a string `env` value count as references. Ordinary objects with an unrelated `env` field must not be reported as missing environment variables.

- [x] Add a failing test with an ordinary object such as `{"env": "display", "value": "literal"}`.
- [x] Run the test and confirm discovery reports `display` while resolution leaves the object unchanged.
- [x] Share the same reference-shape predicate between discovery and resolution.
- [x] Run metadata validator tests.

### Task 4: Reject Placeholders Introduced by Entitlement Replacements

**Files:**

- Modify: `scripts/appstore/resolve_entitlements.py:resolve_entitlements`
- Test: `tests/test_ios_metadata.py`

**Behavior:** Replacement values must not leave a new `$(...)` token in the resolved plist. The command must fail before writing output if substitution introduces an unresolved placeholder.

- [x] Add a failing subprocess test where `A` resolves to `$(B)` and assert a nonzero exit with `B` named.
- [x] Run the test and confirm the current command succeeds and writes the unresolved token.
- [x] Scan resolved string values for remaining placeholders and fail with their names.
- [x] Run the entitlement tests.

### Task 5: Make Web Packaging Permission-Independent

**Files:**

- Modify: `scripts/web/package_static_site.py:add_file_to_tar`
- Test: `tests/test_web_static_site.py`

**Behavior:** Identical site bytes produce identical archives even when source file mode bits differ.

- [x] Add two equivalent source trees with different file permissions and assert their package digests currently differ.
- [x] Run the test and confirm the red failure.
- [x] Set a normalized regular-file mode in tar metadata before adding files.
- [x] Run packaging tests and inspect archive metadata.

### Task 6: Reject Escaping Symlinks During Web Packaging

**Files:**

- Modify: `scripts/web/package_static_site.py:iter_package_files`
- Test: `tests/test_web_static_site.py`

**Behavior:** The release package must reject symlinks instead of publishing a link that resolves outside the web artifact.

- [x] Add a symlink from the source root to a file outside it and assert packaging currently succeeds.
- [x] Run the test and confirm the red failure.
- [x] Detect symlink entries while walking the source tree and raise `PackageError` with the relative path.
- [x] Run packaging tests.

### Task 7: Preserve Absolute App Store Connect URLs

**Files:**

- Modify: `scripts/appstore/connect_api.py:api_url`
- Test: `tests/test_appstore_connect_api.py`

**Behavior:** Any absolute HTTP(S) URL passed to `api_url` remains unchanged; relative API paths still resolve against `base_url`.

- [x] Add a failing assertion for an absolute `http://` URL.
- [x] Run the test and confirm the current implementation prefixes the ASC base URL.
- [x] Detect both `http` and `https` absolute URLs with `urlparse` and return them unchanged.
- [x] Run the API tests.

### Task 8: Serialize Cloudflare Query Sequences Correctly

**Files:**

- Modify: `scripts/cloudflare/common.py:CloudflareClient.request`
- Test: `tests/test_cloudflare_config.py`

**Behavior:** Sequence query values are encoded as repeated query parameters, not a Python list representation.

- [x] Add a fake opener test passing `{"status": ["active", "pending"]}` and assert the current request URL contains the list-literal bug.
- [x] Run the test and confirm red.
- [x] Use `urlencode(..., doseq=True)` after filtering `None`.
- [x] Run Cloudflare tests.

### Task 9: Detect Cloudflare DNS TTL Drift

**Files:**

- Modify: `scripts/cloudflare/pages.py:_dns_record_matches`
- Test: `tests/test_cloudflare_config.py`

**Behavior:** A record with matching type/name/content/proxy state but a different configured TTL must be patched.

- [x] Add an existing CNAME with a mismatched TTL and assert the current implementation returns `exists`.
- [x] Run the test and confirm red.
- [x] Compare normalized TTL values in the match predicate; missing or invalid TTL data is treated as drift.
- [x] Run Cloudflare tests.

### Task 10: Add the Missing Watch Accent Color Asset

**Files:**

- Create: `app/Sunclub/WatchApp/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`
- Modify: `tests/test_ios_metadata.py`

**Behavior:** The watch target’s asset catalog contains the `AccentColor` named color referenced by Xcode, eliminating the build warning.

- [x] Add a failing metadata test requiring the named color set and valid universal color entries.
- [x] Run the test and confirm red.
- [x] Add a system-compatible light/dark color asset with explicit sRGB components.
- [x] Run iOS metadata tests and a generated/build validation that no longer emits the missing-AccentColor warning.

---

## Final Verification

- [x] Run `UV_CACHE_DIR=/tmp/sunclub-uv just test-python`.
- [x] Run `UV_CACHE_DIR=/tmp/sunclub-uv just ci-lint`.
- [x] Run `SUNCLUB_DISABLE_SWIFT_COMPILE_CACHE=1 TEST_XCODEBUILD_MAX_ATTEMPTS=1 just test-unit`.
- [x] Run `git diff --check` and inspect `git status --short`.
- [x] Report each defect, regression test, and verification result with no unverified completion claims.
