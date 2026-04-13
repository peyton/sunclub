from __future__ import annotations

import argparse
from typing import Any

from scripts.cloudflare.common import (
    CloudflareAPIError,
    CloudflareClient,
    ConfigError,
    cloudflare_client_from_env,
    load_email_config,
    optional_env,
    print_lines,
    require_env,
    validate_email_config,
)

JsonObject = dict[str, Any]


def email_setup_permissions_help(config: JsonObject) -> str:
    return "\n".join(
        [
            "Cloudflare Email Routing setup needs a token with:",
            "- Account permission: Email Routing Addresses Edit/Write",
            f"- Zone {config['zone_name']} permission: DNS Write",
            f"- Zone {config['zone_name']} permission: Email Routing Rules Edit/Write",
            "The deploy-only Pages token is not enough for this setup command.",
        ]
    )


def destination_address(config: JsonObject) -> str:
    return require_env(
        str(config["destination_env"]),
        "Set it to the private inbox that should receive peyton.app mail.",
    )


def build_catch_all_payload(config: JsonObject, destination: str) -> JsonObject:
    catch_all = config["catch_all"]
    return {
        "name": catch_all["name"],
        "enabled": catch_all["enabled"],
        "matchers": [{"type": catch_all["matcher"]}],
        "actions": [{"type": catch_all["action"], "value": [destination]}],
    }


def list_destination_addresses(
    client: CloudflareClient,
    config: JsonObject,
) -> list[JsonObject]:
    result = client.request(
        "GET",
        f"/accounts/{config['account_id']}/email/routing/addresses",
    )
    if isinstance(result, list):
        return [item for item in result if isinstance(item, dict)]
    return []


def ensure_destination_address(
    client: CloudflareClient,
    config: JsonObject,
) -> JsonObject:
    destination = destination_address(config)
    for address in list_destination_addresses(client, config):
        email = str(address.get("email", "")).lower()
        if email == destination.lower():
            return {"action": "exists", "address": address}

    created = client.request(
        "POST",
        f"/accounts/{config['account_id']}/email/routing/addresses",
        body={"email": destination},
    )
    return {"action": "created", "address": created}


def ensure_email_routing(
    client: CloudflareClient,
    config: JsonObject,
) -> JsonObject:
    dns_result = _request_allowing_already_configured(
        client,
        "POST",
        f"/zones/{config['zone_id']}/email/routing/dns",
        body={"name": config["zone_name"]},
    )
    enable_result = _request_allowing_already_configured(
        client,
        "POST",
        f"/zones/{config['zone_id']}/email/routing/enable",
        body={},
    )
    return {"dns": dns_result, "enable": enable_result}


def ensure_catch_all_rule(
    client: CloudflareClient,
    config: JsonObject,
) -> JsonObject:
    destination = destination_address(config)
    return client.request(
        "PUT",
        f"/zones/{config['zone_id']}/email/routing/rules/catch_all",
        body=build_catch_all_payload(config, destination),
    )


def get_email_routing_settings(
    client: CloudflareClient,
    config: JsonObject,
) -> JsonObject | None:
    try:
        result = client.request("GET", f"/zones/{config['zone_id']}/email/routing")
    except CloudflareAPIError as error:
        if error.status == 404:
            return None
        raise
    if isinstance(result, dict):
        return result
    return None


def get_catch_all_rule(
    client: CloudflareClient,
    config: JsonObject,
) -> JsonObject | None:
    try:
        result = client.request(
            "GET",
            f"/zones/{config['zone_id']}/email/routing/rules/catch_all",
        )
    except CloudflareAPIError as error:
        if error.status == 404:
            return None
        raise
    if isinstance(result, dict):
        return result
    return None


def email_status_lines(
    client: CloudflareClient | None, config: JsonObject
) -> list[str]:
    destination = optional_env(str(config["destination_env"]))
    lines = [
        f"Email zone: {config['zone_name']}",
        "Email Routing rule: catch-all",
        f"Destination env: {config['destination_env']}",
    ]
    if destination:
        lines.append(f"Destination configured locally: {destination}")
    else:
        lines.append(
            f"Destination configured locally: missing {config['destination_env']}"
        )

    if client is None:
        lines.append(
            "Remote Email Routing status skipped: set CLOUDFLARE_API_TOKEN to query Cloudflare."
        )
        return lines

    settings = get_email_routing_settings(client, config)
    if settings is None:
        lines.append("Remote Email Routing: unavailable")
    else:
        enabled = settings.get("enabled", settings.get("status", "unknown"))
        lines.append(f"Remote Email Routing: {enabled}")

    if destination:
        addresses = list_destination_addresses(client, config)
        match = next(
            (
                address
                for address in addresses
                if str(address.get("email", "")).lower() == destination.lower()
            ),
            None,
        )
        if match is None:
            lines.append("Remote destination address: missing")
        else:
            lines.append(
                f"Remote destination address verified: {bool(match.get('verified'))}"
            )

    catch_all = get_catch_all_rule(client, config)
    if catch_all is None:
        lines.append("Remote catch-all rule: missing")
    else:
        lines.append(f"Remote catch-all rule enabled: {bool(catch_all.get('enabled'))}")
    return lines


def _request_allowing_already_configured(
    client: CloudflareClient,
    method: str,
    path: str,
    body: JsonObject,
) -> Any:
    try:
        return client.request(method, path, body=body)
    except CloudflareAPIError as error:
        message = error.joined_messages().lower()
        if "already" in message or "configured" in message or "exists" in message:
            return {"already_configured": True}
        raise


def _address_verified(address: JsonObject) -> bool:
    return bool(address.get("verified"))


def run_status() -> int:
    config = load_email_config()
    errors = validate_email_config(config)
    if errors:
        print("Cloudflare Email Routing config validation failed:")
        for error in errors:
            print(f"- ERROR: {error}")
        return 1

    client = cloudflare_client_from_env(required=False)
    print_lines(email_status_lines(client, config))
    return 0


def run_setup() -> int:
    config = load_email_config()
    errors = validate_email_config(config)
    if errors:
        print("Cloudflare Email Routing config validation failed:")
        for error in errors:
            print(f"- ERROR: {error}")
        return 1

    client = cloudflare_client_from_env(required=True)
    assert client is not None
    destination_result = ensure_destination_address(client, config)
    address = destination_result["address"]
    print(
        f"Destination address {destination_result['action']}: {destination_address(config)}"
    )

    if not _address_verified(address):
        print(
            "Destination address is not verified yet. Verify the Cloudflare "
            "Email Routing confirmation email, then rerun this command."
        )
        return 2

    ensure_email_routing(client, config)
    ensure_catch_all_rule(client, config)
    print(
        f"Email Routing catch-all forwards *@{config['zone_name']} to {destination_address(config)}."
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Manage Sunclub Cloudflare Email Routing."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser(
        "status", help="Show local and optional remote Email Routing status."
    )
    subparsers.add_parser(
        "setup", help="Create or update Email Routing catch-all forwarding."
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
    except CloudflareAPIError as error:
        print(f"ERROR: {error}")
        if error.status == 403:
            config = load_email_config()
            print(email_setup_permissions_help(config))
        return 2

    parser.error(f"Unknown command: {args.command}")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
