from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

JsonObject = dict[str, Any]

API_BASE_URL = "https://api.cloudflare.com/client/v4"
REPO_ROOT = Path(__file__).resolve().parents[2]
CLOUDFLARE_CONFIG_DIR = REPO_ROOT / "infra" / "cloudflare"
PAGES_CONFIG_PATH = CLOUDFLARE_CONFIG_DIR / "pages-project.json"
EMAIL_CONFIG_PATH = CLOUDFLARE_CONFIG_DIR / "email-routing.json"
LOCAL_ENV_PATH = CLOUDFLARE_CONFIG_DIR / ".env"


class ConfigError(RuntimeError):
    """Raised when repo-local Cloudflare configuration is invalid."""


class MissingEnvironmentError(ConfigError):
    """Raised when a required environment variable is not set."""

    def __init__(self, name: str, purpose: str) -> None:
        super().__init__(f"Missing {name}. {purpose}")
        self.name = name
        self.purpose = purpose


@dataclass
class CloudflareAPIError(RuntimeError):
    method: str
    path: str
    status: int
    errors: list[JsonObject]
    messages: list[JsonObject]

    def __str__(self) -> str:
        details = "; ".join(
            str(item.get("message") or item.get("code") or item)
            for item in self.errors or self.messages
        )
        if not details:
            details = "Unknown Cloudflare API error"
        return f"{self.method} {self.path} failed with HTTP {self.status}: {details}"

    def has_code(self, code: str | int) -> bool:
        expected = str(code)
        return any(str(error.get("code")) == expected for error in self.errors)

    def joined_messages(self) -> str:
        values: list[str] = []
        for item in self.errors + self.messages:
            message = item.get("message")
            if message:
                values.append(str(message))
        return " ".join(values)


class CloudflareClient:
    def __init__(self, token: str, api_base_url: str = API_BASE_URL) -> None:
        self.token = token
        self.api_base_url = api_base_url.rstrip("/")

    def request(
        self,
        method: str,
        path: str,
        body: JsonObject | None = None,
        query: JsonObject | None = None,
    ) -> Any:
        method = method.upper()
        target = f"{self.api_base_url}{path}"
        if query:
            clean_query = {
                key: value for key, value in query.items() if value is not None
            }
            if clean_query:
                target = f"{target}?{urlencode(clean_query)}"

        data = None
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/json",
        }
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"

        request = Request(target, data=data, headers=headers, method=method)
        try:
            with urlopen(request, timeout=30) as response:
                status = response.status
                raw = response.read().decode("utf-8")
        except HTTPError as error:
            status = error.code
            raw = error.read().decode("utf-8")
            parsed = _parse_json(raw)
            raise _api_error(method, path, status, parsed) from error
        except URLError as error:
            raise ConfigError(f"Could not reach Cloudflare API: {error}") from error

        parsed = _parse_json(raw)
        if isinstance(parsed, dict) and parsed.get("success") is False:
            raise _api_error(method, path, status, parsed)
        if isinstance(parsed, dict) and "result" in parsed:
            return parsed["result"]
        return parsed


def _parse_json(raw: str) -> Any:
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {"success": False, "errors": [{"message": raw}]}


def _api_error(method: str, path: str, status: int, parsed: Any) -> CloudflareAPIError:
    errors: list[JsonObject] = []
    messages: list[JsonObject] = []
    if isinstance(parsed, dict):
        raw_errors = parsed.get("errors")
        raw_messages = parsed.get("messages")
        if isinstance(raw_errors, list):
            errors = [item for item in raw_errors if isinstance(item, dict)]
        if isinstance(raw_messages, list):
            messages = [item for item in raw_messages if isinstance(item, dict)]
    return CloudflareAPIError(method, path, status, errors, messages)


def load_env_file(path: Path | None = None) -> None:
    path = path or LOCAL_ENV_PATH
    if not path.is_file():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, value = line.split("=", 1)
        name = name.strip()
        value = value.strip().strip('"').strip("'")
        if name:
            os.environ.setdefault(name, value)


def optional_env(name: str) -> str | None:
    load_env_file()
    value = os.environ.get(name, "").strip()
    return value or None


def require_env(name: str, purpose: str) -> str:
    value = optional_env(name)
    if value is None:
        raise MissingEnvironmentError(name, purpose)
    return value


def cloudflare_client_from_env(required: bool) -> CloudflareClient | None:
    token = optional_env("CLOUDFLARE_API_TOKEN")
    if token is None:
        if required:
            raise MissingEnvironmentError(
                "CLOUDFLARE_API_TOKEN",
                "Set it to a Cloudflare API token before running setup.",
            )
        return None
    return CloudflareClient(token)


def load_json_config(path: Path) -> JsonObject:
    try:
        raw = path.read_text(encoding="utf-8")
    except FileNotFoundError as error:
        raise ConfigError(f"Missing Cloudflare config file: {path}") from error

    try:
        value = json.loads(raw)
    except json.JSONDecodeError as error:
        raise ConfigError(f"Invalid JSON in {path}: {error}") from error

    if not isinstance(value, dict):
        raise ConfigError(f"{path} must contain a JSON object.")
    return value


def load_cloudflare_configs() -> tuple[JsonObject, JsonObject]:
    return load_pages_config(), load_email_config()


def load_pages_config() -> JsonObject:
    return load_json_config(PAGES_CONFIG_PATH)


def load_email_config() -> JsonObject:
    return load_json_config(EMAIL_CONFIG_PATH)


def validate_pages_config(config: JsonObject) -> list[str]:
    errors: list[str] = []
    required_strings = (
        "account_id",
        "zone_id",
        "project_name",
        "production_branch",
        "custom_domain",
    )
    for key in required_strings:
        if not isinstance(config.get(key), str) or not config[key].strip():
            errors.append(f"pages-project.json missing non-empty string {key!r}.")

    build_config = config.get("build_config")
    if not isinstance(build_config, dict):
        errors.append("pages-project.json missing object 'build_config'.")
    else:
        for key in ("build_command", "destination_dir", "root_dir"):
            if not isinstance(build_config.get(key), str):
                errors.append(
                    f"pages-project.json build_config.{key} must be a string."
                )

    deployment = config.get("deployment")
    if not isinstance(deployment, dict):
        errors.append("pages-project.json missing object 'deployment'.")
    else:
        if deployment.get("mode") != "github_actions_direct_upload":
            errors.append(
                "pages-project.json deployment.mode must be "
                "'github_actions_direct_upload'."
            )
        for key in ("workflow", "build_output"):
            if not isinstance(deployment.get(key), str) or not deployment[key].strip():
                errors.append(f"pages-project.json deployment.{key} must be a string.")
        if not _is_string_list(deployment.get("required_secrets")):
            errors.append(
                "pages-project.json deployment.required_secrets must be a string list."
            )

    source_control = config.get("source_control")
    if not isinstance(source_control, dict):
        errors.append("pages-project.json missing object 'source_control'.")
    else:
        for key in ("type", "owner", "repo_name"):
            if (
                not isinstance(source_control.get(key), str)
                or not source_control[key].strip()
            ):
                errors.append(
                    f"pages-project.json source_control.{key} must be a string."
                )
        if source_control.get("production_deployments_enabled") is not False:
            errors.append(
                "pages-project.json source_control.production_deployments_enabled "
                "must be false."
            )
        if source_control.get("preview_deployment_setting") != "none":
            errors.append(
                "pages-project.json source_control.preview_deployment_setting "
                "must be 'none'."
            )
        if source_control.get("pr_comments_enabled") is not False:
            errors.append(
                "pages-project.json source_control.pr_comments_enabled must be false."
            )
        for key in ("path_includes", "path_excludes"):
            if not _is_string_list(source_control.get(key)):
                errors.append(
                    f"pages-project.json source_control.{key} must be a string list."
                )

    return errors


def validate_email_config(config: JsonObject) -> list[str]:
    errors: list[str] = []
    for key in ("account_id", "zone_id", "zone_name", "destination_env"):
        if not isinstance(config.get(key), str) or not config[key].strip():
            errors.append(f"email-routing.json missing non-empty string {key!r}.")

    catch_all = config.get("catch_all")
    if not isinstance(catch_all, dict):
        errors.append("email-routing.json missing object 'catch_all'.")
    else:
        for key in ("name", "action", "matcher"):
            if not isinstance(catch_all.get(key), str) or not catch_all[key].strip():
                errors.append(f"email-routing.json catch_all.{key} must be a string.")
        if not isinstance(catch_all.get("enabled"), bool):
            errors.append("email-routing.json catch_all.enabled must be a boolean.")

    return errors


def validate_config_files() -> list[str]:
    pages_config, email_config = load_cloudflare_configs()
    return validate_pages_config(pages_config) + validate_email_config(email_config)


def _is_string_list(value: Any) -> bool:
    return isinstance(value, list) and all(isinstance(item, str) for item in value)


def print_lines(lines: list[str]) -> None:
    for line in lines:
        print(line)


def direct_upload_help(account_id: str) -> str:
    return (
        "Create or keep the Pages project as a Direct Upload project. GitHub "
        "Actions deploys the built web artifact with Wrangler, so Cloudflare-side "
        "Git automatic builds should stay disabled. Open "
        f"https://dash.cloudflare.com/{account_id}/workers-and-pages/create/pages "
        "only if the Pages project must be created manually."
    )


def run_check() -> int:
    errors = validate_config_files()
    if errors:
        print("Cloudflare local config validation failed:")
        for error in errors:
            print(f"- ERROR: {error}")
        return 1

    print("Cloudflare local config validation passed.")
    if optional_env("CLOUDFLARE_API_TOKEN") is None:
        print(
            "Remote Cloudflare checks skipped: set CLOUDFLARE_API_TOKEN to query Cloudflare."
        )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate Sunclub Cloudflare config.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("check", help="Validate repo-local Cloudflare config.")
    args = parser.parse_args(argv)

    if args.command == "check":
        return run_check()

    parser.error(f"Unknown command: {args.command}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
