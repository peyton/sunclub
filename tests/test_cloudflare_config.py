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

    def request(
        self,
        method: str,
        path: str,
        body: JsonObject | None = None,
        query: JsonObject | None = None,
    ) -> Any:
        del query
        method = method.upper()
        self.calls.append((method, path, body))
        return self.responses[(method, path)]


def test_cloudflare_config_files_are_valid() -> None:
    pages_config, email_config = common.load_cloudflare_configs()

    assert common.validate_pages_config(pages_config) == []
    assert common.validate_email_config(email_config) == []
    assert pages_config["project_name"] == "sunclub"
    assert pages_config["custom_domain"] == "sunclub.peyton.app"
    assert email_config["zone_name"] == "peyton.app"


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
        "workflow": ".github/workflows/deploy-web-cloudflare.yml",
        "build_output": ".build/web",
        "required_secrets": [
            "CLOUDFLARE_API_TOKEN",
            "CLOUDFLARE_ACCOUNT_ID",
        ],
    }
    assert config["source_control"]["production_deployments_enabled"] is False
    assert config["source_control"]["preview_deployment_setting"] == "none"


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


def test_email_catch_all_payload_uses_env_destination(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(common, "LOCAL_ENV_PATH", tmp_path / "missing.env")
    monkeypatch.setenv("SUNCLUB_FORWARD_TO", "owner@example.com")
    config = common.load_email_config()

    payload = email.build_catch_all_payload(config, email.destination_address(config))

    assert payload == {
        "name": "Catch-all forwarding",
        "enabled": True,
        "matchers": [{"type": "all"}],
        "actions": [{"type": "forward", "value": ["owner@example.com"]}],
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
    assert "DNS Write" in message
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
