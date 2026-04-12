from __future__ import annotations

import argparse
from typing import Any
from urllib.parse import quote

from scripts.cloudflare.common import (
    CloudflareAPIError,
    CloudflareClient,
    ConfigError,
    cloudflare_client_from_env,
    git_integration_help,
    load_pages_config,
    optional_env,
    print_lines,
    validate_pages_config,
)

JsonObject = dict[str, Any]


def build_pages_project_payload(
    config: JsonObject,
    github_repo_id: str | None = None,
) -> JsonObject:
    source = config["source"]
    source_config: JsonObject = {
        "owner": source["owner"],
        "repo_name": source["repo_name"],
        "production_branch": config["production_branch"],
        "production_deployments_enabled": source.get(
            "production_deployments_enabled", True
        ),
        "preview_deployment_setting": source.get("preview_deployment_setting", "all"),
        "pr_comments_enabled": source.get("pr_comments_enabled", True),
        "path_includes": source.get("path_includes", []),
        "path_excludes": source.get("path_excludes", []),
    }
    if github_repo_id:
        source_config["repo_id"] = github_repo_id

    return {
        "name": config["project_name"],
        "production_branch": config["production_branch"],
        "build_config": dict(config["build_config"]),
        "source": {
            "type": source.get("type", "github"),
            "config": source_config,
        },
    }


def build_pages_project_update_payload(
    config: JsonObject,
    github_repo_id: str | None = None,
) -> JsonObject:
    payload = build_pages_project_payload(config, github_repo_id)
    payload.pop("name", None)
    return payload


def ensure_pages_project(
    client: CloudflareClient,
    config: JsonObject,
    github_repo_id: str | None = None,
) -> JsonObject:
    project = get_pages_project(client, config)
    if project is None:
        try:
            created = client.request(
                "POST",
                f"/accounts/{config['account_id']}/pages/projects",
                body=build_pages_project_payload(config, github_repo_id),
            )
        except CloudflareAPIError as error:
            raise ConfigError(
                f"{error}\n{git_integration_help(str(config['account_id']))}"
            ) from error
        return {"action": "created", "project": created}

    updated = client.request(
        "PATCH",
        (
            f"/accounts/{config['account_id']}/pages/projects/"
            f"{quote(config['project_name'], safe='')}"
        ),
        body=build_pages_project_update_payload(config, github_repo_id),
    )
    return {"action": "updated", "project": updated}


def get_pages_project(
    client: CloudflareClient, config: JsonObject
) -> JsonObject | None:
    try:
        result = client.request(
            "GET",
            (
                f"/accounts/{config['account_id']}/pages/projects/"
                f"{quote(config['project_name'], safe='')}"
            ),
        )
    except CloudflareAPIError as error:
        if error.status == 404 or error.has_code("8000007"):
            return None
        raise
    if isinstance(result, dict):
        return result
    return None


def ensure_pages_domain(client: CloudflareClient, config: JsonObject) -> JsonObject:
    domains = list_pages_domains(client, config)
    wanted = config["custom_domain"].lower()
    for domain in domains:
        name = str(domain.get("name", "")).lower()
        if name == wanted:
            return {"action": "exists", "domain": domain}

    created = client.request(
        "POST",
        (
            f"/accounts/{config['account_id']}/pages/projects/"
            f"{quote(config['project_name'], safe='')}/domains"
        ),
        body={"name": config["custom_domain"]},
    )
    return {"action": "created", "domain": created}


def list_pages_domains(
    client: CloudflareClient, config: JsonObject
) -> list[JsonObject]:
    result = client.request(
        "GET",
        (
            f"/accounts/{config['account_id']}/pages/projects/"
            f"{quote(config['project_name'], safe='')}/domains"
        ),
    )
    if isinstance(result, list):
        return [item for item in result if isinstance(item, dict)]
    return []


def pages_status_lines(
    client: CloudflareClient | None, config: JsonObject
) -> list[str]:
    lines = [
        f"Pages project: {config['project_name']}",
        f"Production branch: {config['production_branch']}",
        f"Build command: {config['build_config']['build_command']}",
        f"Build output: {config['build_config']['destination_dir']}",
        f"Custom domain: {config['custom_domain']}",
    ]

    if client is None:
        lines.append(
            "Remote Pages status skipped: set CLOUDFLARE_API_TOKEN to query Cloudflare."
        )
        return lines

    project = get_pages_project(client, config)
    if project is None:
        lines.append("Remote Pages project: missing")
        lines.append(git_integration_help(str(config["account_id"])))
        return lines

    lines.append("Remote Pages project: present")
    domains = list_pages_domains(client, config)
    domain_names = sorted(str(domain.get("name", "")) for domain in domains)
    if config["custom_domain"] in domain_names:
        lines.append(f"Remote custom domain: present ({config['custom_domain']})")
    else:
        lines.append(f"Remote custom domain: missing ({config['custom_domain']})")
    return lines


def run_status() -> int:
    config = load_pages_config()
    errors = validate_pages_config(config)
    if errors:
        print("Cloudflare Pages config validation failed:")
        for error in errors:
            print(f"- ERROR: {error}")
        return 1

    client = cloudflare_client_from_env(required=False)
    print_lines(pages_status_lines(client, config))
    return 0


def run_setup() -> int:
    config = load_pages_config()
    errors = validate_pages_config(config)
    if errors:
        print("Cloudflare Pages config validation failed:")
        for error in errors:
            print(f"- ERROR: {error}")
        return 1

    client = cloudflare_client_from_env(required=True)
    assert client is not None
    github_repo_id = optional_env("GITHUB_REPO_ID")
    project_result = ensure_pages_project(client, config, github_repo_id)
    domain_result = ensure_pages_domain(client, config)
    print(f"Pages project {project_result['action']}: {config['project_name']}")
    print(f"Pages custom domain {domain_result['action']}: {config['custom_domain']}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Manage Sunclub Cloudflare Pages.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("status", help="Show local and optional remote Pages status.")
    subparsers.add_parser(
        "setup", help="Create or update the Pages project and domain."
    )
    args = parser.parse_args(argv)

    try:
        if args.command == "status":
            return run_status()
        if args.command == "setup":
            return run_setup()
    except ConfigError as error:
        print(f"ERROR: {error}")
        return 2

    parser.error(f"Unknown command: {args.command}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
