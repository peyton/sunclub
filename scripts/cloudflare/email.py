from __future__ import annotations

import argparse
from typing import Any
from urllib.parse import quote

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
            f"- Zone {config['zone_name']} permission: Zone Settings Read/Write",
            f"- Zone {config['zone_name']} permission: Email Routing Rules Edit/Write",
            "The deploy-only Pages token is not enough for this setup command.",
        ]
    )


def destination_address(config: JsonObject) -> str:
    return require_env(
        str(config["destination_env"]),
        "Set it to the private inbox that should receive Sunclub public mail.",
    )


def email_route_local_parts(config: JsonObject) -> list[str]:
    return [str(route).strip() for route in config["routes"]]


def email_route_address(config: JsonObject, local_part: str) -> str:
    return f"{local_part}@{config['mail_domain']}"


def email_route_addresses(config: JsonObject) -> list[str]:
    return [
        email_route_address(config, local_part)
        for local_part in email_route_local_parts(config)
    ]


def build_route_payload(
    config: JsonObject,
    local_part: str,
    destination: str,
) -> JsonObject:
    public_address = email_route_address(config, local_part)
    return {
        "name": f"Sunclub {local_part} forwarding",
        "enabled": True,
        "matchers": [
            {
                "type": "literal",
                "field": "to",
                "value": public_address,
            }
        ],
        "actions": [{"type": "forward", "value": [destination]}],
    }


def build_disabled_catch_all_payload(config: JsonObject) -> JsonObject:
    catch_all = config["catch_all"]
    action: JsonObject = {"type": catch_all["action"]}
    return {
        "name": catch_all["name"],
        "enabled": catch_all["enabled"],
        "matchers": [{"type": catch_all["matcher"]}],
        "actions": [action],
    }


def build_catch_all_payload(
    config: JsonObject,
    destination: str | None = None,
) -> JsonObject:
    del destination
    return build_disabled_catch_all_payload(config)


def list_routing_rules(
    client: CloudflareClient,
    config: JsonObject,
) -> list[JsonObject]:
    result = client.request(
        "GET",
        f"/zones/{config['zone_id']}/email/routing/rules",
        query={"per_page": 100},
    )
    if isinstance(result, list):
        return [item for item in result if isinstance(item, dict)]
    return []


def ensure_email_route_rule(
    client: CloudflareClient,
    config: JsonObject,
    local_part: str,
    existing_rules: list[JsonObject],
) -> JsonObject:
    destination = destination_address(config)
    payload = build_route_payload(config, local_part, destination)
    existing = _find_matching_route_rule(existing_rules, payload)
    if existing is None:
        created = client.request(
            "POST",
            f"/zones/{config['zone_id']}/email/routing/rules",
            body=payload,
        )
        if isinstance(created, dict):
            existing_rules.append(created)
        return {
            "action": "created",
            "address": email_route_address(config, local_part),
            "rule": created,
        }

    if _routing_rule_payload_matches(existing, payload):
        return {
            "action": "exists",
            "address": email_route_address(config, local_part),
            "rule": existing,
        }

    rule_id = existing.get("id")
    if not isinstance(rule_id, str) or not rule_id:
        raise ConfigError(
            f"Cloudflare Email Routing rule for {email_route_address(config, local_part)} "
            "has no id."
        )

    updated = client.request(
        "PUT",
        f"/zones/{config['zone_id']}/email/routing/rules/{quote(rule_id, safe='')}",
        body=payload,
    )
    return {
        "action": "updated",
        "address": email_route_address(config, local_part),
        "rule": updated,
    }


def ensure_email_route_rules(
    client: CloudflareClient,
    config: JsonObject,
) -> list[JsonObject]:
    existing_rules = list_routing_rules(client, config)
    return [
        ensure_email_route_rule(client, config, local_part, existing_rules)
        for local_part in email_route_local_parts(config)
    ]


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
        body={"name": config["mail_domain"]},
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
    return client.request(
        "PUT",
        f"/zones/{config['zone_id']}/email/routing/rules/catch_all",
        body=build_disabled_catch_all_payload(config),
    )


def ensure_catch_all_disabled(
    client: CloudflareClient,
    config: JsonObject,
) -> JsonObject:
    return ensure_catch_all_rule(client, config)


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
        f"Email Routing mail domain: {config['mail_domain']}",
        "Email Routing routes: " + ", ".join(email_route_addresses(config)),
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

    rules = list_routing_rules(client, config)
    for public_address in email_route_addresses(config):
        rule = _find_matching_route_rule_by_address(rules, public_address)
        if rule is None:
            lines.append(f"Remote route {public_address}: missing")
        else:
            lines.append(
                f"Remote route {public_address} enabled: {bool(rule.get('enabled'))}"
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


def _find_matching_route_rule(
    rules: list[JsonObject],
    payload: JsonObject,
) -> JsonObject | None:
    matchers = payload["matchers"]
    public_address = str(matchers[0]["value"])
    by_address = _find_matching_route_rule_by_address(rules, public_address)
    if by_address is not None:
        return by_address

    wanted_name = str(payload.get("name", "")).lower()
    return next(
        (rule for rule in rules if str(rule.get("name", "")).lower() == wanted_name),
        None,
    )


def _find_matching_route_rule_by_address(
    rules: list[JsonObject],
    public_address: str,
) -> JsonObject | None:
    wanted_address = public_address.lower()
    return next(
        (
            rule
            for rule in rules
            if (_literal_to_address(rule) or "").lower() == wanted_address
        ),
        None,
    )


def _literal_to_address(rule: JsonObject) -> str | None:
    matchers = rule.get("matchers")
    if not isinstance(matchers, list):
        return None
    for matcher in matchers:
        if not isinstance(matcher, dict):
            continue
        if matcher.get("type") == "literal" and matcher.get("field") == "to":
            value = matcher.get("value")
            if isinstance(value, str):
                return value
    return None


def _routing_rule_payload_matches(rule: JsonObject, payload: JsonObject) -> bool:
    return (
        str(rule.get("name", "")) == str(payload.get("name", ""))
        and bool(rule.get("enabled")) == bool(payload.get("enabled"))
        and _normalized_matchers(rule) == _normalized_matchers(payload)
        and _normalized_actions(rule) == _normalized_actions(payload)
    )


def _normalized_matchers(rule: JsonObject) -> list[tuple[str, str, str]]:
    matchers = rule.get("matchers")
    if not isinstance(matchers, list):
        return []
    normalized: list[tuple[str, str, str]] = []
    for matcher in matchers:
        if not isinstance(matcher, dict):
            continue
        normalized.append(
            (
                str(matcher.get("type", "")).lower(),
                str(matcher.get("field", "")).lower(),
                str(matcher.get("value", "")).lower(),
            )
        )
    return normalized


def _normalized_actions(rule: JsonObject) -> list[tuple[str, tuple[str, ...]]]:
    actions = rule.get("actions")
    if not isinstance(actions, list):
        return []
    normalized: list[tuple[str, tuple[str, ...]]] = []
    for action in actions:
        if not isinstance(action, dict):
            continue
        values = action.get("value", [])
        if not isinstance(values, list):
            values = []
        normalized.append(
            (
                str(action.get("type", "")).lower(),
                tuple(str(value).lower() for value in values),
            )
        )
    return normalized


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
    route_results = ensure_email_route_rules(client, config)
    catch_all_result = ensure_catch_all_disabled(client, config)
    for route_result in route_results:
        print(f"Email route {route_result['action']}: {route_result['address']}")
    print(f"Email Routing catch-all disabled: {bool(catch_all_result.get('enabled'))}")
    print(
        "Email Routing forwards "
        + ", ".join(email_route_addresses(config))
        + f" to {destination_address(config)}."
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
        "setup", help="Create or update explicit Email Routing forwarding rules."
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
