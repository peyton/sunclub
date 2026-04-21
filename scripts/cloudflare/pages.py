from __future__ import annotations

import argparse
from typing import Any
from urllib.parse import quote

from scripts.cloudflare.common import (
    CloudflareAPIError,
    CloudflareClient,
    ConfigError,
    cloudflare_client_from_env,
    direct_upload_help,
    load_pages_config,
    optional_env,
    print_lines,
    validate_pages_config,
)

JsonObject = dict[str, Any]
PAGES_WEB_DNS_RECORD_TYPES = {"A", "AAAA", "CNAME"}


def build_pages_project_payload(
    config: JsonObject,
    github_repo_id: str | None = None,
) -> JsonObject:
    del github_repo_id
    return {
        "name": config["project_name"],
        "production_branch": config["production_branch"],
        "build_config": dict(config["build_config"]),
    }


def project_has_git_source(project: JsonObject | None) -> bool:
    if not isinstance(project, dict):
        return False
    source = project.get("source")
    if not isinstance(source, dict):
        return False
    return source.get("type") in {"github", "gitlab"}


def build_disabled_source_control_payload(
    config: JsonObject,
    github_repo_id: str | None = None,
) -> JsonObject:
    source = config["source_control"]
    source_config: JsonObject = {
        "owner": source["owner"],
        "repo_name": source["repo_name"],
        "production_branch": config["production_branch"],
        "production_deployments_enabled": False,
        "preview_deployment_setting": "none",
        "pr_comments_enabled": False,
        "path_includes": source.get("path_includes", []),
        "path_excludes": source.get("path_excludes", []),
    }
    if github_repo_id:
        source_config["repo_id"] = github_repo_id

    return {
        "type": source.get("type", "github"),
        "config": source_config,
    }


def build_pages_project_update_payload(
    config: JsonObject,
    project: JsonObject | None = None,
    github_repo_id: str | None = None,
) -> JsonObject:
    payload = build_pages_project_payload(config, github_repo_id)
    payload.pop("name", None)
    if project_has_git_source(project):
        payload["source"] = build_disabled_source_control_payload(
            config,
            github_repo_id=github_repo_id,
        )
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
                f"{error}\n{direct_upload_help(str(config['account_id']))}"
            ) from error
        return {"action": "created", "project": created}

    updated = client.request(
        "PATCH",
        (
            f"/accounts/{config['account_id']}/pages/projects/"
            f"{quote(config['project_name'], safe='')}"
        ),
        body=build_pages_project_update_payload(config, project, github_repo_id),
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


def pages_dns_permissions_help(config: JsonObject) -> str:
    zone_name = _zone_name_for_dns(config)
    return "\n".join(
        [
            "Cloudflare Pages DNS setup needs a token with:",
            "- Account permission: Cloudflare Pages Edit",
            f"- Zone {zone_name} permission: DNS Write",
            "The deploy-only Pages token may not be enough for this setup command.",
        ]
    )


def pages_status_permissions_help(config: JsonObject) -> str:
    zone_name = _zone_name_for_dns(config)
    return "\n".join(
        [
            "Cloudflare Pages remote status needs a token with:",
            "- Account permission: Pages Read/Write",
            f"- Zone {zone_name} permission: DNS Read/Write",
            "An email-routing-only token is enough for email checks, but not full Pages status.",
        ]
    )


def build_pages_dns_record_payload(config: JsonObject) -> JsonObject:
    dns = config["dns"]
    return {
        "type": dns["type"],
        "name": dns["name"],
        "content": dns["content"],
        "proxied": dns["proxied"],
        "ttl": dns["ttl"],
        "comment": "Sunclub Cloudflare Pages custom domain",
    }


def list_pages_dns_records(
    client: CloudflareClient,
    config: JsonObject,
) -> list[JsonObject]:
    result = client.request(
        "GET",
        f"/zones/{config['zone_id']}/dns_records",
        query={"name.exact": config["dns"]["name"], "per_page": 100},
    )
    if isinstance(result, list):
        return [
            item
            for item in result
            if isinstance(item, dict) and _is_pages_web_dns_record(item)
        ]
    return []


def ensure_pages_dns_record(
    client: CloudflareClient,
    config: JsonObject,
) -> JsonObject:
    records = list_pages_dns_records(client, config)
    payload = build_pages_dns_record_payload(config)
    if not records:
        created = client.request(
            "POST",
            f"/zones/{config['zone_id']}/dns_records",
            body=payload,
        )
        return {"action": "created", "record": created}

    if len(records) > 1:
        raise ConfigError(
            f"Found multiple A, AAAA, or CNAME records for {config['dns']['name']}; "
            "resolve the conflict in Cloudflare before rerunning setup."
        )

    record = records[0]
    if str(record.get("type", "")).upper() != payload["type"]:
        raise ConfigError(
            f"Found {record.get('type', 'unknown')} record for {config['dns']['name']}; "
            f"expected {payload['type']} to {payload['content']}."
        )

    if _dns_record_matches(record, payload):
        return {"action": "exists", "record": record}

    record_id = record.get("id")
    if not isinstance(record_id, str) or not record_id:
        raise ConfigError(
            f"Cloudflare DNS record for {config['dns']['name']} has no id."
        )

    updated = client.request(
        "PATCH",
        f"/zones/{config['zone_id']}/dns_records/{quote(record_id, safe='')}",
        body=payload,
    )
    return {"action": "updated", "record": updated}


def _dns_record_matches(record: JsonObject, payload: JsonObject) -> bool:
    return (
        str(record.get("type", "")).upper() == str(payload["type"]).upper()
        and _normalize_hostname(str(record.get("name", "")))
        == _normalize_hostname(str(payload["name"]))
        and _normalize_hostname(str(record.get("content", "")))
        == _normalize_hostname(str(payload["content"]))
        and bool(record.get("proxied")) == bool(payload["proxied"])
    )


def _is_pages_web_dns_record(record: JsonObject) -> bool:
    return str(record.get("type", "")).upper() in PAGES_WEB_DNS_RECORD_TYPES


def _normalize_hostname(value: str) -> str:
    return value.strip().rstrip(".").lower()


def _zone_name_for_dns(config: JsonObject) -> str:
    domain = str(config["custom_domain"])
    parts = domain.split(".", 1)
    return parts[1] if len(parts) == 2 else domain


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
        f"Deployment mode: {config['deployment']['mode']}",
        f"Production branch: {config['production_branch']}",
        f"GitHub deployment environment: {config['deployment']['github_environment']}",
        f"Build command: {config['build_config']['build_command']}",
        f"Build output: {config['build_config']['destination_dir']}",
        "GitHub Actions secrets: "
        + ", ".join(config["deployment"]["required_secrets"]),
        f"Custom domain: {config['custom_domain']}",
        (
            "DNS target: "
            f"{config['dns']['type']} {config['dns']['name']} -> "
            f"{config['dns']['content']}"
        ),
    ]

    if client is None:
        lines.append(
            "Remote Pages status skipped: set CLOUDFLARE_API_TOKEN to query Cloudflare."
        )
        return lines

    try:
        project = get_pages_project(client, config)
    except CloudflareAPIError as error:
        if error.status in {401, 403}:
            lines.append("Remote Pages project: unavailable with current token")
            lines.append(pages_status_permissions_help(config))
            return lines
        raise
    if project is None:
        lines.append("Remote Pages project: missing")
        lines.append(direct_upload_help(str(config["account_id"])))
        return lines

    lines.append("Remote Pages project: present")
    if project_has_git_source(project):
        source_config = project.get("source", {}).get("config", {})
        if (
            source_config.get("production_deployments_enabled") is False
            and source_config.get("preview_deployment_setting") == "none"
        ):
            lines.append("Remote Git integration: automatic deployments disabled")
        else:
            lines.append("Remote Git integration: automatic deployments still enabled")
    else:
        lines.append("Remote deployment source: Direct Upload")

    try:
        domains = list_pages_domains(client, config)
    except CloudflareAPIError as error:
        if error.status in {401, 403}:
            lines.append("Remote custom domain: unavailable with current token")
            lines.append(pages_status_permissions_help(config))
            return lines
        raise
    domain_names = sorted(str(domain.get("name", "")) for domain in domains)
    if config["custom_domain"] in domain_names:
        matching_domain = next(
            domain
            for domain in domains
            if str(domain.get("name", "")) == config["custom_domain"]
        )
        status = matching_domain.get("status", "unknown")
        lines.append(
            f"Remote custom domain: present ({config['custom_domain']}, {status})"
        )
    else:
        lines.append(f"Remote custom domain: missing ({config['custom_domain']})")

    try:
        dns_records = list_pages_dns_records(client, config)
    except CloudflareAPIError as error:
        if error.status in {401, 403}:
            lines.append("Remote DNS record: unavailable with current token")
            lines.append(pages_status_permissions_help(config))
            return lines
        raise

    payload = build_pages_dns_record_payload(config)
    matching_record = next(
        (record for record in dns_records if _dns_record_matches(record, payload)),
        None,
    )
    if matching_record is not None:
        lines.append("Remote DNS record: configured")
    elif not dns_records:
        lines.append("Remote DNS record: missing")
    else:
        lines.append("Remote DNS record: present but does not match config")
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
    dns_result = ensure_pages_dns_record(client, config)
    print(f"Pages project {project_result['action']}: {config['project_name']}")
    print(f"Pages custom domain {domain_result['action']}: {config['custom_domain']}")
    print(
        f"Pages DNS record {dns_result['action']}: "
        f"{config['dns']['name']} -> {config['dns']['content']}"
    )
    return 0


def run_setup_dns() -> int:
    config = load_pages_config()
    errors = validate_pages_config(config)
    if errors:
        print("Cloudflare Pages config validation failed:")
        for error in errors:
            print(f"- ERROR: {error}")
        return 1

    client = cloudflare_client_from_env(required=True)
    assert client is not None
    dns_result = ensure_pages_dns_record(client, config)
    print(
        f"Pages DNS record {dns_result['action']}: "
        f"{config['dns']['name']} -> {config['dns']['content']}"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Manage Sunclub Cloudflare Pages.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("status", help="Show local and optional remote Pages status.")
    subparsers.add_parser(
        "setup", help="Create or update the Pages project and domain."
    )
    subparsers.add_parser(
        "setup-dns", help="Create or update the Pages custom-domain DNS record."
    )
    args = parser.parse_args(argv)

    try:
        if args.command == "status":
            return run_status()
        if args.command == "setup":
            return run_setup()
        if args.command == "setup-dns":
            return run_setup_dns()
    except ConfigError as error:
        print(f"ERROR: {error}")
        return 2
    except CloudflareAPIError as error:
        print(f"ERROR: {error}")
        if error.status in {401, 403}:
            config = load_pages_config()
            if args.command == "status":
                print(pages_status_permissions_help(config))
            else:
                print(pages_dns_permissions_help(config))
        return 2

    parser.error(f"Unknown command: {args.command}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
