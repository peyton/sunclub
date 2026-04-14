from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import shlex
from typing import Any

from scripts.tooling.resolve_versions import REPO_ROOT


DEFAULT_MANIFEST_PATH = REPO_ROOT / "scripts" / "appstore" / "metadata.json"
DEFAULT_REVIEW_ENV_PATH = REPO_ROOT / ".state" / "appstore" / "review.env"
ENV_REFERENCE_KEY = "env"
ENV_EQUALS_KEY = "equals"


class ReviewEnvError(ValueError):
    pass


@dataclass(frozen=True)
class ResolvedManifest:
    raw: dict[str, Any]
    value: dict[str, Any]
    missing_env_vars: tuple[str, ...]
    env_file: Path
    env_file_loaded: bool


def load_raw_manifest(path: Path = DEFAULT_MANIFEST_PATH) -> dict[str, Any]:
    return json.loads(path.read_text())


def parse_review_env_file(path: Path = DEFAULT_REVIEW_ENV_PATH) -> dict[str, str]:
    if not path.is_file():
        return {}

    values: dict[str, str] = {}
    for line_number, raw_line in enumerate(path.read_text().splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        try:
            parts = shlex.split(line, comments=True, posix=True)
        except ValueError as error:
            raise ReviewEnvError(
                f"{path}:{line_number}: could not parse review env line: {error}"
            ) from error

        if parts and parts[0] == "export":
            parts = parts[1:]
        for part in parts:
            if "=" not in part:
                raise ReviewEnvError(
                    f"{path}:{line_number}: expected export KEY=VALUE syntax."
                )
            key, value = part.split("=", 1)
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
                raise ReviewEnvError(f"{path}:{line_number}: invalid env key {key!r}.")
            values[key] = value
    return values


def merged_review_environment(
    environment: Mapping[str, str] | None = None,
    *,
    env_file: Path = DEFAULT_REVIEW_ENV_PATH,
    load_env_file: bool = True,
) -> tuple[dict[str, str], bool]:
    merged: dict[str, str] = {}
    loaded = False
    if load_env_file and env_file.is_file():
        merged.update(parse_review_env_file(env_file))
        loaded = True
    merged.update(dict(environment or os.environ))
    return merged, loaded


def load_resolved_manifest(
    path: Path = DEFAULT_MANIFEST_PATH,
    *,
    environment: Mapping[str, str] | None = None,
    env_file: Path = DEFAULT_REVIEW_ENV_PATH,
    load_env_file: bool = True,
) -> dict[str, Any]:
    return load_resolved_manifest_report(
        path,
        environment=environment,
        env_file=env_file,
        load_env_file=load_env_file,
    ).value


def load_resolved_manifest_report(
    path: Path = DEFAULT_MANIFEST_PATH,
    *,
    environment: Mapping[str, str] | None = None,
    env_file: Path = DEFAULT_REVIEW_ENV_PATH,
    load_env_file: bool = True,
) -> ResolvedManifest:
    raw = load_raw_manifest(path)
    merged_env, loaded = merged_review_environment(
        environment,
        env_file=env_file,
        load_env_file=load_env_file,
    )
    missing: set[str] = set()
    value = resolve_env_references(raw, merged_env, missing)
    if not isinstance(value, dict):
        raise ReviewEnvError("Resolved App Store manifest must be a JSON object.")
    return ResolvedManifest(
        raw=raw,
        value=value,
        missing_env_vars=tuple(sorted(missing)),
        env_file=env_file,
        env_file_loaded=loaded,
    )


def resolve_env_references(
    value: Any,
    environment: Mapping[str, str],
    missing_env_vars: set[str],
) -> Any:
    if isinstance(value, dict):
        if set(value).issubset({ENV_REFERENCE_KEY, ENV_EQUALS_KEY}) and isinstance(
            value.get(ENV_REFERENCE_KEY), str
        ):
            env_name = value[ENV_REFERENCE_KEY]
            raw_value = environment.get(env_name)
            if raw_value is None:
                missing_env_vars.add(env_name)
                raw_value = ""
            expected = value.get(ENV_EQUALS_KEY)
            if isinstance(expected, str):
                return raw_value == expected
            return raw_value
        return {
            key: resolve_env_references(child, environment, missing_env_vars)
            for key, child in value.items()
        }
    if isinstance(value, list):
        return [
            resolve_env_references(child, environment, missing_env_vars)
            for child in value
        ]
    return value


def env_reference_names(value: Any) -> tuple[str, ...]:
    names: set[str] = set()
    collect_env_reference_names(value, names)
    return tuple(sorted(names))


def collect_env_reference_names(value: Any, names: set[str]) -> None:
    if isinstance(value, dict):
        env_name = value.get(ENV_REFERENCE_KEY)
        if isinstance(env_name, str):
            names.add(env_name)
        for child in value.values():
            collect_env_reference_names(child, names)
    elif isinstance(value, list):
        for child in value:
            collect_env_reference_names(child, names)


def redacted_summary_lines(
    manifest: Mapping[str, Any],
    *,
    missing_env_vars: Sequence[str] = (),
    env_file: Path = DEFAULT_REVIEW_ENV_PATH,
    env_file_loaded: bool = False,
    warnings: Sequence[str] = (),
) -> list[str]:
    app = manifest.get("app", {})
    review = manifest.get("review", {})
    contact = review.get("contact", {}) if isinstance(review, Mapping) else {}
    privacy = manifest.get("privacy", {})
    regulatory = manifest.get("regulatory", {})
    medical = (
        regulatory.get("regulated_medical_device", {})
        if isinstance(regulatory, Mapping)
        else {}
    )
    accessibility = manifest.get("accessibility", {})
    iphone_accessibility = (
        accessibility.get("iphone", {}) if isinstance(accessibility, Mapping) else {}
    )

    lines = [
        "App Store Review Checkpoint",
        f"- App: {app.get('name', 'unknown')}",
        f"- Bundle ID: {app.get('bundle_id', 'unknown')}",
        (
            "- Categories: "
            f"{app.get('primary_category', 'unknown')} primary, "
            f"{app.get('secondary_category', 'none')} secondary"
        ),
        f"- Device family: {app.get('device_family', 'unknown')}",
        f"- Pricing: {app.get('pricing_model', 'unknown')}",
        f"- Review contact: {redacted_contact(contact)}",
        (
            "- App Privacy completed: "
            f"{format_bool(privacy.get('app_store_connect_completed'))}"
        ),
        (
            "- Public CloudKit accountability transport: "
            f"{format_bool(privacy.get('public_cloudkit_accountability_transport'))}"
        ),
        (
            "- Regulated medical device status: "
            f"{medical.get('app_store_connect_value') or medical.get('status', 'unknown')}"
        ),
        (
            "- Accessibility declaration ready: "
            f"{format_bool(iphone_accessibility.get('ready'))}"
        ),
        f"- Review env file: {env_file} ({'loaded' if env_file_loaded else 'not loaded'})",
    ]
    if missing_env_vars:
        lines.append("- Missing env vars: " + ", ".join(missing_env_vars))
    if warnings:
        lines.append("- Validation warnings:")
        lines.extend(f"  - {warning}" for warning in warnings)
    return lines


def redacted_contact(contact: Mapping[str, Any]) -> str:
    first_name = str(contact.get("first_name", "")).strip()
    last_name = str(contact.get("last_name", "")).strip()
    email = str(contact.get("email", "")).strip()
    phone = str(contact.get("phone", "")).strip()
    name = " ".join(part for part in (first_name, last_name) if part)
    if not name:
        name = "missing"
    return f"{name}; {redact_email(email)}; {redact_phone(phone)}"


def redact_email(value: str) -> str:
    if not value or "@" not in value:
        return "missing"
    local, domain = value.split("@", 1)
    local_prefix = local[:1] if local else "*"
    return f"{local_prefix}***@{domain}"


def redact_phone(value: str) -> str:
    digits = re.sub(r"\D", "", value)
    if not digits:
        return "missing"
    return f"***{digits[-4:]}"


def format_bool(value: Any) -> str:
    if value is True:
        return "yes"
    if value is False:
        return "no"
    return "unknown"
