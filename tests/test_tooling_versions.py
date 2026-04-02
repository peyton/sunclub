from __future__ import annotations

from datetime import UTC, datetime

import pytest

from scripts.tooling.resolve_versions import (
    VersionResolutionError,
    github_release_tag,
    parse_release_tag,
    resolve_build_number,
    resolve_marketing_version,
    resolve_versions,
)


def test_parse_release_tag_returns_semver_version() -> None:
    assert parse_release_tag("v1.2.3") == "1.2.3"


def test_parse_release_tag_rejects_non_semver_tags() -> None:
    with pytest.raises(VersionResolutionError):
        parse_release_tag("release-1.2.3")


def test_github_release_tag_prefers_explicit_override() -> None:
    env = {
        "SUNCLUB_RELEASE_TAG": "v2.0.0",
        "GITHUB_REF_TYPE": "tag",
        "GITHUB_REF_NAME": "v1.0.0",
    }

    assert github_release_tag(env) == "v2.0.0"


def test_resolve_marketing_version_uses_explicit_override(tmp_path) -> None:
    env = {"SUNCLUB_MARKETING_VERSION": "3.4.5"}

    assert resolve_marketing_version(env, tmp_path) == "3.4.5"


def test_resolve_marketing_version_uses_tag_when_present(tmp_path) -> None:
    env = {"GITHUB_REF_TYPE": "tag", "GITHUB_REF_NAME": "v4.5.6"}

    assert resolve_marketing_version(env, tmp_path) == "4.5.6"


def test_resolve_marketing_version_falls_back_to_default_when_no_tag(tmp_path) -> None:
    assert resolve_marketing_version({}, tmp_path) == "1.0.0"


def test_resolve_build_number_uses_ci_shape_for_release_tags() -> None:
    env = {
        "GITHUB_REF_TYPE": "tag",
        "GITHUB_REF_NAME": "v1.2.3",
        "GITHUB_RUN_NUMBER": "42",
        "GITHUB_RUN_ATTEMPT": "3",
    }
    now = datetime(2026, 4, 2, 19, 55, 1, tzinfo=UTC)

    assert resolve_build_number(env, now=now) == "20260402.42.3"


def test_resolve_build_number_uses_local_timestamp_shape_without_ci() -> None:
    now = datetime(2026, 4, 2, 19, 55, 1, tzinfo=UTC)

    assert resolve_build_number({}, now=now) == "20260402.195501.0"


def test_resolve_versions_respects_explicit_build_number(tmp_path) -> None:
    env = {
        "SUNCLUB_MARKETING_VERSION": "1.9.0",
        "SUNCLUB_BUILD_NUMBER": "20260402.99.1",
    }

    resolved = resolve_versions(env, tmp_path)

    assert resolved.marketing_version == "1.9.0"
    assert resolved.build_number == "20260402.99.1"
