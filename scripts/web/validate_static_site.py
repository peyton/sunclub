#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse

CONTACT_EMAIL = "contact@mail.sunclub.peyton.app"
SUPPORT_EMAIL = "support@mail.sunclub.peyton.app"
PRIVACY_EMAIL = "privacy@mail.sunclub.peyton.app"
SECURITY_EMAIL = "security@mail.sunclub.peyton.app"
EMAIL_LABELS = {
    CONTACT_EMAIL: "contact",
    SUPPORT_EMAIL: "support",
    PRIVACY_EMAIL: "privacy",
    SECURITY_EMAIL: "security",
}
REQUIRED_EMAILS_BY_FILE = {
    Path("index.html"): (CONTACT_EMAIL,),
    Path("docs/index.html"): (CONTACT_EMAIL,),
    Path("docs/automation/index.html"): (
        CONTACT_EMAIL,
        SUPPORT_EMAIL,
        PRIVACY_EMAIL,
        SECURITY_EMAIL,
    ),
    Path("support/index.html"): (
        CONTACT_EMAIL,
        SUPPORT_EMAIL,
        PRIVACY_EMAIL,
        SECURITY_EMAIL,
    ),
    Path("privacy/index.html"): (
        CONTACT_EMAIL,
        SUPPORT_EMAIL,
        PRIVACY_EMAIL,
        SECURITY_EMAIL,
    ),
    Path("404.html"): (CONTACT_EMAIL, SUPPORT_EMAIL),
}
REQUIRED_FILES = (
    "index.html",
    "docs/index.html",
    "docs/automation/index.html",
    "support/index.html",
    "privacy/index.html",
    "404.html",
    "config/weatherkit.json",
    "schemas/weatherkit-config.v1.json",
    "robots.txt",
    "sitemap.xml",
)
HTML_FILE_GLOBS = ("*.html",)
ALLOWED_EXTERNAL_SCHEMES = ("https", "mailto", "tel")
FORBIDDEN_PHRASES = (
    "camera verify",
    "ai confirms",
    "ai validation",
    "no cloud",
    "download on the app store",
    'href="#"',
    "href='#'",
    "premium",
    "subscription",
    "subscriptions",
    "sunclub@peyton.app",
    "@sunclub.peyton.app",
)
WEATHERKIT_SCHEMA_URL = "https://sunclub.peyton.app/schemas/weatherkit-config.v1.json"
WEATHERKIT_CONFIG_EXPECTED_VALUES = {
    "$schema": WEATHERKIT_SCHEMA_URL,
    "version": 1,
    "weatherkit_enabled": True,
    "min_fetch_interval_seconds": 10800,
    "max_daily_fetches_per_device": 4,
    "max_monthly_fetches_per_device": 90,
    "reason": "",
}


@dataclass
class LinkReference:
    attribute: str
    target: str
    line: int


@dataclass
class ParsedHtml:
    title: str = ""
    meta_description: str = ""
    links: list[LinkReference] = field(default_factory=list)


class StaticSiteParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parsed = ParsedHtml()
        self._in_title = False
        self._title_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        normalized = dict(attrs)
        if tag == "title":
            self._in_title = True
        if tag == "meta" and normalized.get("name", "").lower() == "description":
            self.parsed.meta_description = (normalized.get("content") or "").strip()

        for attribute in ("href", "src"):
            value = normalized.get(attribute)
            if value:
                self.parsed.links.append(
                    LinkReference(
                        attribute=attribute, target=value.strip(), line=self.getpos()[0]
                    )
                )

    def handle_endtag(self, tag: str) -> None:
        if tag == "title":
            self._in_title = False
            self.parsed.title = " ".join("".join(self._title_parts).split())

    def handle_data(self, data: str) -> None:
        if self._in_title:
            self._title_parts.append(data)


def parse_html(value: str) -> ParsedHtml:
    parser = StaticSiteParser()
    parser.feed(value)
    parser.close()
    return parser.parsed


def html_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for pattern in HTML_FILE_GLOBS:
        files.extend(root.rglob(pattern))
    return sorted(path for path in files if path.is_file())


def resolve_internal_target(root: Path, source: Path, raw_target: str) -> Path | None:
    target = raw_target.split("#", 1)[0].split("?", 1)[0]
    if not target:
        return None

    parsed = urlparse(target)
    if parsed.scheme:
        return None

    if target.startswith("/"):
        candidate = root / unquote(target.lstrip("/"))
    else:
        candidate = source.parent / unquote(target)

    if target.endswith("/") or candidate.is_dir():
        candidate = candidate / "index.html"

    return candidate.resolve()


def validate_internal_link(root: Path, source: Path, link: LinkReference) -> str | None:
    target = link.target
    parsed = urlparse(target)
    if parsed.scheme:
        if parsed.scheme not in ALLOWED_EXTERNAL_SCHEMES:
            return (
                f"{source.relative_to(root)}:{link.line}: unsupported URL scheme "
                f"{parsed.scheme!r} in {link.attribute}={target!r}."
            )
        if parsed.scheme == "http":
            return f"{source.relative_to(root)}:{link.line}: insecure URL {target!r}."
        return None

    if target == "#":
        return f'{source.relative_to(root)}:{link.line}: placeholder link href="#" is not allowed.'

    candidate = resolve_internal_target(root, source, target)
    if candidate is None:
        return None

    try:
        candidate.relative_to(root.resolve())
    except ValueError:
        return f"{source.relative_to(root)}:{link.line}: link escapes web root: {target!r}."

    if not candidate.exists():
        return (
            f"{source.relative_to(root)}:{link.line}: broken internal "
            f"{link.attribute}={target!r}; expected {candidate.relative_to(root.resolve())}."
        )

    return None


def validate_html_file(root: Path, path: Path) -> list[str]:
    errors: list[str] = []
    raw = path.read_text(encoding="utf-8")
    lowered = raw.lower()
    relative = path.relative_to(root)
    parsed = parse_html(raw)

    if "noindex" in lowered:
        errors.append(f"{relative}: must not contain noindex.")
    if "http://" in lowered:
        errors.append(f"{relative}: must not contain insecure http:// URLs.")
    for email in REQUIRED_EMAILS_BY_FILE.get(relative, (CONTACT_EMAIL,)):
        if email not in raw:
            label = EMAIL_LABELS[email]
            errors.append(f"{relative}: missing public {label} email {email}.")
    if not parsed.title:
        errors.append(f"{relative}: missing non-empty <title>.")
    if not parsed.meta_description:
        errors.append(f"{relative}: missing non-empty meta description.")

    for phrase in FORBIDDEN_PHRASES:
        if phrase in lowered:
            errors.append(
                f"{relative}: contains forbidden stale or placeholder copy {phrase!r}."
            )

    for link in parsed.links:
        link_error = validate_internal_link(root, path, link)
        if link_error:
            errors.append(link_error)

    return errors


def read_json_file(
    root: Path, relative_path: Path
) -> tuple[dict[str, object] | None, list[str]]:
    path = root / relative_path
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except OSError as error:
        return None, [f"{relative_path}: could not read JSON: {error}."]
    except json.JSONDecodeError as error:
        return None, [f"{relative_path}: invalid JSON: {error.msg}."]

    if not isinstance(payload, dict):
        return None, [f"{relative_path}: top-level JSON value must be an object."]

    return payload, []


def validate_weatherkit_config(root: Path) -> list[str]:
    errors: list[str] = []
    config_path = Path("config/weatherkit.json")
    schema_path = Path("schemas/weatherkit-config.v1.json")
    config, config_errors = read_json_file(root, config_path)
    schema, schema_errors = read_json_file(root, schema_path)
    errors.extend(config_errors)
    errors.extend(schema_errors)

    if config is not None:
        unexpected_keys = set(config) - set(WEATHERKIT_CONFIG_EXPECTED_VALUES)
        missing_keys = set(WEATHERKIT_CONFIG_EXPECTED_VALUES) - set(config)
        if unexpected_keys:
            errors.append(f"{config_path}: unexpected keys {sorted(unexpected_keys)}.")
        if missing_keys:
            errors.append(f"{config_path}: missing keys {sorted(missing_keys)}.")

        for key, expected in WEATHERKIT_CONFIG_EXPECTED_VALUES.items():
            if config.get(key) != expected:
                errors.append(
                    f"{config_path}: {key} must be {expected!r}; got {config.get(key)!r}."
                )

    if schema is not None:
        if schema.get("$id") != WEATHERKIT_SCHEMA_URL:
            errors.append(f"{schema_path}: $id must be {WEATHERKIT_SCHEMA_URL}.")
        if schema.get("type") != "object":
            errors.append(f"{schema_path}: type must be 'object'.")
        if schema.get("additionalProperties") is not False:
            errors.append(f"{schema_path}: additionalProperties must be false.")
        required = schema.get("required")
        if required != list(WEATHERKIT_CONFIG_EXPECTED_VALUES):
            errors.append(
                f"{schema_path}: required keys must match config keys in order."
            )

    return errors


def validate_site(root: Path) -> list[str]:
    resolved_root = root.resolve()
    errors: list[str] = []

    if not resolved_root.is_dir():
        return [f"Static site root not found: {root}"]

    for required_file in REQUIRED_FILES:
        path = resolved_root / required_file
        if not path.is_file():
            errors.append(f"Missing required static site file: {required_file}")

    robots = resolved_root / "robots.txt"
    if (
        robots.is_file()
        and "Sitemap: https://sunclub.peyton.app/sitemap.xml"
        not in robots.read_text(encoding="utf-8")
    ):
        errors.append(
            "robots.txt must reference https://sunclub.peyton.app/sitemap.xml."
        )

    sitemap = resolved_root / "sitemap.xml"
    if sitemap.is_file():
        sitemap_text = sitemap.read_text(encoding="utf-8")
        for path in ("/", "/docs/", "/docs/automation/", "/support/", "/privacy/"):
            expected = f"https://sunclub.peyton.app{path}"
            if expected not in sitemap_text:
                errors.append(f"sitemap.xml missing {expected}.")
        sitemap_urls = sitemap_text.replace(
            'xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"', ""
        )
        if "http://" in sitemap_urls:
            errors.append("sitemap.xml must not contain insecure http:// URLs.")

    for path in html_files(resolved_root):
        errors.extend(validate_html_file(resolved_root, path))

    errors.extend(validate_weatherkit_config(resolved_root))

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate the Sunclub static web site."
    )
    parser.add_argument(
        "root", nargs="?", default="web", help="Static site root to validate."
    )
    args = parser.parse_args()

    errors = validate_site(Path(args.root))
    if errors:
        print(f"Static site validation failed for {args.root}:")
        for error in errors:
            print(f"- ERROR: {error}")
        return 1

    print(f"Static site validation passed for {args.root}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
