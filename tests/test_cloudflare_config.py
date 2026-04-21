from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest

from scripts.cloudflare import common, email, pages, pages_deploy

JsonObject = dict[str, Any]


class FakeCloudflareClient:
    def __init__(self, responses: dict[tuple[str, str], Any]) -> None:
        self.responses = responses
        self.calls: list[tuple[str, str, JsonObject | None]] = []
        self.queries: list[tuple[str, str, JsonObject | None]] = []

    def request(
        self,
        method: str,
        path: str,
        body: JsonObject | None = None,
        query: JsonObject | None = None,
    ) -> Any:
        method = method.upper()
        self.calls.append((method, path, body))
        self.queries.append((method, path, query))
        response = self.responses[(method, path)]
        if isinstance(response, Exception):
            raise response
        return response


def test_cloudflare_config_files_are_valid() -> None:
    pages_config, email_config = common.load_cloudflare_configs()

    assert common.validate_pages_config(pages_config) == []
    assert common.validate_email_config(email_config) == []
    assert pages_config["project_name"] == "sunclub"
    assert pages_config["custom_domain"] == "sunclub.peyton.app"
    assert email_config["zone_name"] == "peyton.app"
    assert email_config["mail_domain"] == "mail.sunclub.peyton.app"
    assert email_config["routes"] == ["support", "privacy", "security", "contact"]


def test_pages_project_payload_matches_github_actions_direct_upload_plan() -> None:
    config = common.load_pages_config()

    payload = pages.build_pages_project_payload(config, github_repo_id="123456")

    assert payload["name"] == "sunclub"
    assert payload["production_branch"] == "master"
    assert payload["build_config"] == {
        "build_command": "just web-build",
        "destination_dir": ".build/web",
        "root_dir": "/",
    }
    assert "source" not in payload
    assert config["deployment"] == {
        "mode": "github_actions_direct_upload",
        "github_environment": "cloudflare-production",
        "workflow": ".github/workflows/deploy-web-cloudflare.yml",
        "build_output": ".build/web",
        "required_secrets": [
            "CLOUDFLARE_API_TOKEN",
            "CLOUDFLARE_ACCOUNT_ID",
        ],
    }
    assert config["source_control"]["production_deployments_enabled"] is False
    assert config["source_control"]["preview_deployment_setting"] == "none"
    assert config["dns"] == {
        "type": "CNAME",
        "name": "sunclub.peyton.app",
        "content": "sunclub.pages.dev",
        "proxied": True,
        "ttl": 1,
    }


def test_pages_project_update_disables_existing_git_automatic_deployments() -> None:
    config = common.load_pages_config()
    existing_project = {
        "source": {
            "type": "github",
            "config": {
                "owner": "peyton",
                "repo_name": "sunclub",
                "production_deployments_enabled": True,
                "preview_deployment_setting": "all",
            },
        }
    }

    payload = pages.build_pages_project_update_payload(
        config,
        existing_project,
        github_repo_id="123456",
    )

    assert payload["source"] == {
        "type": "github",
        "config": {
            "owner": "peyton",
            "repo_name": "sunclub",
            "production_branch": "master",
            "production_deployments_enabled": False,
            "preview_deployment_setting": "none",
            "pr_comments_enabled": False,
            "path_includes": [],
            "path_excludes": [],
            "repo_id": "123456",
        },
    }


def test_pages_project_update_keeps_direct_upload_project_source_free() -> None:
    config = common.load_pages_config()

    payload = pages.build_pages_project_update_payload(config, {"name": "sunclub"})

    assert payload == {
        "production_branch": "master",
        "build_config": {
            "build_command": "just web-build",
            "destination_dir": ".build/web",
            "root_dir": "/",
        },
    }


def test_manual_pages_deploy_command_matches_cloudflare_pages_config() -> None:
    config = common.load_pages_config()

    command = pages_deploy.build_pages_deploy_command(config, "BRANCH=preview")

    assert command == [
        "mise",
        "exec",
        "--",
        "wrangler",
        "pages",
        "deploy",
        ".build/web",
        "--project-name=sunclub",
        "--branch=preview",
    ]


def test_pages_dns_payload_matches_custom_domain_config() -> None:
    config = common.load_pages_config()

    payload = pages.build_pages_dns_record_payload(config)

    assert payload == {
        "type": "CNAME",
        "name": "sunclub.peyton.app",
        "content": "sunclub.pages.dev",
        "proxied": True,
        "ttl": 1,
        "comment": "Sunclub Cloudflare Pages custom domain",
    }


def test_pages_dns_setup_creates_missing_cname() -> None:
    config = common.load_pages_config()
    dns_path = "/zones/a004f01ed99de3582152debde5a96a08/dns_records"
    client = FakeCloudflareClient(
        {
            ("GET", dns_path): [],
            ("POST", dns_path): {"id": "record-id"},
        }
    )

    result = pages.ensure_pages_dns_record(client, config)

    assert result["action"] == "created"
    assert client.calls == [
        ("GET", dns_path, None),
        (
            "POST",
            dns_path,
            {
                "type": "CNAME",
                "name": "sunclub.peyton.app",
                "content": "sunclub.pages.dev",
                "proxied": True,
                "ttl": 1,
                "comment": "Sunclub Cloudflare Pages custom domain",
            },
        ),
    ]
    assert client.queries == [
        (
            "GET",
            dns_path,
            {"name.exact": "sunclub.peyton.app", "per_page": 100},
        ),
        ("POST", dns_path, None),
    ]


def test_pages_dns_setup_ignores_email_records_when_creating_cname() -> None:
    config = common.load_pages_config()
    dns_path = "/zones/a004f01ed99de3582152debde5a96a08/dns_records"
    client = FakeCloudflareClient(
        {
            ("GET", dns_path): [
                {
                    "id": "mx-record-id",
                    "type": "MX",
                    "name": "sunclub.peyton.app",
                    "content": "route1.mx.cloudflare.net",
                },
                {
                    "id": "txt-record-id",
                    "type": "TXT",
                    "name": "sunclub.peyton.app",
                    "content": "v=spf1 include:_spf.mx.cloudflare.net ~all",
                },
            ],
            ("POST", dns_path): {"id": "record-id"},
        }
    )

    result = pages.ensure_pages_dns_record(client, config)

    assert result["action"] == "created"
    assert client.calls[-1] == (
        "POST",
        dns_path,
        {
            "type": "CNAME",
            "name": "sunclub.peyton.app",
            "content": "sunclub.pages.dev",
            "proxied": True,
            "ttl": 1,
            "comment": "Sunclub Cloudflare Pages custom domain",
        },
    )


def test_pages_dns_setup_ignores_email_records_when_cname_exists() -> None:
    config = common.load_pages_config()
    dns_path = "/zones/a004f01ed99de3582152debde5a96a08/dns_records"
    cname_record = {
        "id": "record-id",
        "type": "CNAME",
        "name": "sunclub.peyton.app",
        "content": "sunclub.pages.dev",
        "proxied": True,
    }
    client = FakeCloudflareClient(
        {
            ("GET", dns_path): [
                {
                    "id": "mx-record-id",
                    "type": "MX",
                    "name": "sunclub.peyton.app",
                    "content": "route1.mx.cloudflare.net",
                },
                {
                    "id": "txt-record-id",
                    "type": "TXT",
                    "name": "sunclub.peyton.app",
                    "content": "v=spf1 include:_spf.mx.cloudflare.net ~all",
                },
                cname_record,
            ],
        }
    )

    result = pages.ensure_pages_dns_record(client, config)

    assert result == {"action": "exists", "record": cname_record}
    assert client.calls == [("GET", dns_path, None)]


def test_pages_dns_setup_updates_mismatched_cname() -> None:
    config = common.load_pages_config()
    dns_path = "/zones/a004f01ed99de3582152debde5a96a08/dns_records"
    record_path = f"{dns_path}/record-id"
    client = FakeCloudflareClient(
        {
            ("GET", dns_path): [
                {
                    "id": "record-id",
                    "type": "CNAME",
                    "name": "sunclub.peyton.app",
                    "content": "old.pages.dev",
                    "proxied": False,
                }
            ],
            ("PATCH", record_path): {"id": "record-id"},
        }
    )

    result = pages.ensure_pages_dns_record(client, config)

    assert result["action"] == "updated"
    assert client.calls[-1] == (
        "PATCH",
        record_path,
        {
            "type": "CNAME",
            "name": "sunclub.peyton.app",
            "content": "sunclub.pages.dev",
            "proxied": True,
            "ttl": 1,
            "comment": "Sunclub Cloudflare Pages custom domain",
        },
    )


def test_pages_dns_setup_rejects_non_cname_conflict() -> None:
    config = common.load_pages_config()
    dns_path = "/zones/a004f01ed99de3582152debde5a96a08/dns_records"
    client = FakeCloudflareClient(
        {
            ("GET", dns_path): [
                {
                    "id": "record-id",
                    "type": "A",
                    "name": "sunclub.peyton.app",
                    "content": "192.0.2.10",
                    "proxied": True,
                }
            ],
        }
    )

    with pytest.raises(common.ConfigError):
        pages.ensure_pages_dns_record(client, config)


def test_pages_status_permissions_help_names_required_cloudflare_permissions() -> None:
    config = common.load_pages_config()

    message = pages.pages_status_permissions_help(config)

    assert "Pages Read/Write" in message
    assert "DNS Read/Write" in message
    assert "peyton.app" in message


def test_pages_status_reports_permissions_help_when_pages_access_is_missing() -> None:
    config = common.load_pages_config()
    project_path = "/accounts/0e32ee7804b102bea6b9d3056d60f980/pages/projects/sunclub"
    client = FakeCloudflareClient(
        {
            (
                "GET",
                project_path,
            ): common.CloudflareAPIError(
                "GET",
                project_path,
                403,
                [{"message": "Authentication error"}],
                [],
            ),
        }
    )

    lines = pages.pages_status_lines(client, config)

    assert "Remote Pages project: unavailable with current token" in lines
    assert any(
        "Cloudflare Pages remote status needs a token with:" in line for line in lines
    )
    assert any("Pages Read/Write" in line for line in lines)
    assert any("DNS Read/Write" in line for line in lines)


def test_pages_status_reports_permissions_help_when_dns_access_is_missing() -> None:
    config = common.load_pages_config()
    project_path = "/accounts/0e32ee7804b102bea6b9d3056d60f980/pages/projects/sunclub"
    domain_path = (
        "/accounts/0e32ee7804b102bea6b9d3056d60f980/pages/projects/sunclub/domains"
    )
    dns_path = "/zones/a004f01ed99de3582152debde5a96a08/dns_records"
    client = FakeCloudflareClient(
        {
            ("GET", project_path): {"name": "sunclub"},
            ("GET", domain_path): [
                {"name": "sunclub.peyton.app", "status": "active"},
            ],
            (
                "GET",
                dns_path,
            ): common.CloudflareAPIError(
                "GET",
                dns_path,
                403,
                [{"message": "Authentication error"}],
                [],
            ),
        }
    )

    lines = pages.pages_status_lines(client, config)

    assert "Remote Pages project: present" in lines
    assert "Remote custom domain: present (sunclub.peyton.app, active)" in lines
    assert "Remote DNS record: unavailable with current token" in lines
    assert any(
        "Cloudflare Pages remote status needs a token with:" in line for line in lines
    )


def test_manual_pages_deploy_env_uses_config_account_id() -> None:
    config = common.load_pages_config()

    env = pages_deploy.pages_deploy_environment(
        config,
        {"CLOUDFLARE_API_TOKEN": "token"},
    )

    assert env["CLOUDFLARE_API_TOKEN"] == "token"
    assert env["CLOUDFLARE_ACCOUNT_ID"] == "0e32ee7804b102bea6b9d3056d60f980"


def test_manual_pages_deploy_requires_token() -> None:
    config = common.load_pages_config()

    with pytest.raises(common.MissingEnvironmentError):
        pages_deploy.pages_deploy_environment(config, {})


def test_manual_pages_deploy_rejects_wrong_account_id() -> None:
    config = common.load_pages_config()

    with pytest.raises(common.ConfigError):
        pages_deploy.pages_deploy_environment(
            config,
            {
                "CLOUDFLARE_API_TOKEN": "token",
                "CLOUDFLARE_ACCOUNT_ID": "wrong-account",
            },
        )


def test_email_route_payloads_use_env_destination(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(common, "LOCAL_ENV_PATH", tmp_path / "missing.env")
    monkeypatch.setenv("SUNCLUB_FORWARD_TO", "owner@example.com")
    config = common.load_email_config()

    payload = email.build_route_payload(
        config,
        "support",
        email.destination_address(config),
    )

    assert payload == {
        "name": "Sunclub support forwarding",
        "enabled": True,
        "matchers": [
            {
                "type": "literal",
                "field": "to",
                "value": "support@mail.sunclub.peyton.app",
            }
        ],
        "actions": [{"type": "forward", "value": ["owner@example.com"]}],
    }
    assert email.email_route_addresses(config) == [
        "support@mail.sunclub.peyton.app",
        "privacy@mail.sunclub.peyton.app",
        "security@mail.sunclub.peyton.app",
        "contact@mail.sunclub.peyton.app",
    ]


def test_email_catch_all_payload_disables_old_catch_all() -> None:
    config = common.load_email_config()

    payload = email.build_disabled_catch_all_payload(config)

    assert payload == {
        "name": "Catch-all disabled",
        "enabled": False,
        "matchers": [{"type": "all"}],
        "actions": [{"type": "drop"}],
    }


def test_email_destination_env_is_required(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(common, "LOCAL_ENV_PATH", tmp_path / "missing.env")
    monkeypatch.delenv("SUNCLUB_FORWARD_TO", raising=False)
    config = common.load_email_config()

    with pytest.raises(common.MissingEnvironmentError):
        email.destination_address(config)


def test_email_setup_permissions_help_names_required_cloudflare_permissions() -> None:
    config = common.load_email_config()

    message = email.email_setup_permissions_help(config)

    assert "Email Routing Addresses" in message
    assert "Zone Settings Read/Write" in message
    assert "Email Routing Rules" in message
    assert "peyton.app" in message


def test_pages_domain_setup_reuses_existing_domain() -> None:
    config = common.load_pages_config()
    domain_path = (
        "/accounts/0e32ee7804b102bea6b9d3056d60f980/pages/projects/sunclub/domains"
    )
    client = FakeCloudflareClient(
        {
            ("GET", domain_path): [{"name": "sunclub.peyton.app"}],
        }
    )

    result = pages.ensure_pages_domain(client, config)

    assert result["action"] == "exists"
    assert client.calls == [("GET", domain_path, None)]


def test_email_destination_setup_reuses_existing_address(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(common, "LOCAL_ENV_PATH", tmp_path / "missing.env")
    monkeypatch.setenv("SUNCLUB_FORWARD_TO", "owner@example.com")
    config = common.load_email_config()
    addresses_path = (
        "/accounts/0e32ee7804b102bea6b9d3056d60f980/email/routing/addresses"
    )
    client = FakeCloudflareClient(
        {
            ("GET", addresses_path): [
                {"email": "owner@example.com", "verified": True},
            ],
        }
    )

    result = email.ensure_destination_address(client, config)

    assert result["action"] == "exists"
    assert client.calls == [("GET", addresses_path, None)]


def test_email_routing_dns_uses_mail_subdomain() -> None:
    config = common.load_email_config()
    dns_path = "/zones/a004f01ed99de3582152debde5a96a08/email/routing/dns"
    enable_path = "/zones/a004f01ed99de3582152debde5a96a08/email/routing/enable"
    client = FakeCloudflareClient(
        {
            ("POST", dns_path): {"name": "mail.sunclub.peyton.app"},
            ("POST", enable_path): {"enabled": True},
        }
    )

    result = email.ensure_email_routing(client, config)

    assert result == {
        "dns": {"name": "mail.sunclub.peyton.app"},
        "enable": {"enabled": True},
    }
    assert client.calls == [
        ("POST", dns_path, {"name": "mail.sunclub.peyton.app"}),
        ("POST", enable_path, {}),
    ]


def test_email_route_setup_creates_missing_literal_rules(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(common, "LOCAL_ENV_PATH", tmp_path / "missing.env")
    monkeypatch.setenv("SUNCLUB_FORWARD_TO", "owner@example.com")
    config = common.load_email_config()
    rules_path = "/zones/a004f01ed99de3582152debde5a96a08/email/routing/rules"
    client = FakeCloudflareClient(
        {
            ("GET", rules_path): [],
            ("POST", rules_path): {"id": "created-id", "enabled": True},
        }
    )

    result = email.ensure_email_route_rules(client, config)

    assert [item["action"] for item in result] == [
        "created",
        "created",
        "created",
        "created",
    ]
    assert [call[2]["matchers"][0]["value"] for call in client.calls[1:]] == [
        "support@mail.sunclub.peyton.app",
        "privacy@mail.sunclub.peyton.app",
        "security@mail.sunclub.peyton.app",
        "contact@mail.sunclub.peyton.app",
    ]
    assert client.queries[0] == ("GET", rules_path, {"per_page": 100})


def test_email_route_setup_updates_existing_mismatched_rule(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(common, "LOCAL_ENV_PATH", tmp_path / "missing.env")
    monkeypatch.setenv("SUNCLUB_FORWARD_TO", "owner@example.com")
    config = common.load_email_config()
    rules: list[JsonObject] = [
        {
            "id": "support-rule-id",
            "name": "Old support rule",
            "enabled": False,
            "matchers": [
                {
                    "type": "literal",
                    "field": "to",
                    "value": "support@mail.sunclub.peyton.app",
                }
            ],
            "actions": [{"type": "drop"}],
        }
    ]
    update_path = (
        "/zones/a004f01ed99de3582152debde5a96a08/email/routing/rules/support-rule-id"
    )
    client = FakeCloudflareClient(
        {
            ("PUT", update_path): {"id": "support-rule-id", "enabled": True},
        }
    )

    result = email.ensure_email_route_rule(client, config, "support", rules)

    assert result["action"] == "updated"
    assert client.calls == [
        (
            "PUT",
            update_path,
            {
                "name": "Sunclub support forwarding",
                "enabled": True,
                "matchers": [
                    {
                        "type": "literal",
                        "field": "to",
                        "value": "support@mail.sunclub.peyton.app",
                    }
                ],
                "actions": [{"type": "forward", "value": ["owner@example.com"]}],
            },
        )
    ]
