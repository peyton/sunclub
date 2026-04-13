from __future__ import annotations

import argparse
import os
import shlex
import subprocess
from collections.abc import Mapping, Sequence
from pathlib import Path

from scripts.cloudflare.common import (
    ConfigError,
    JsonObject,
    MissingEnvironmentError,
    REPO_ROOT,
    load_pages_config,
    validate_pages_config,
)


def normalize_branch(value: str) -> str:
    branch = value.strip()
    if branch.startswith("BRANCH="):
        branch = branch.split("=", 1)[1].strip()
    if not branch:
        raise ConfigError("Cloudflare Pages deploy branch cannot be empty.")
    return branch


def build_pages_deploy_command(config: JsonObject, branch: str) -> list[str]:
    return [
        "mise",
        "exec",
        "--",
        "wrangler",
        "pages",
        "deploy",
        str(config["deployment"]["build_output"]),
        f"--project-name={config['project_name']}",
        f"--branch={normalize_branch(branch)}",
    ]


def pages_deploy_environment(
    config: JsonObject,
    environ: Mapping[str, str] | None = None,
) -> dict[str, str]:
    source_env = os.environ if environ is None else environ
    token = source_env.get("CLOUDFLARE_API_TOKEN", "").strip()
    if not token:
        raise MissingEnvironmentError(
            "CLOUDFLARE_API_TOKEN",
            "Set it to a Cloudflare API token with Cloudflare Pages Edit access.",
        )

    expected_account_id = str(config["account_id"])
    configured_account_id = source_env.get("CLOUDFLARE_ACCOUNT_ID", "").strip()
    if configured_account_id and configured_account_id != expected_account_id:
        raise ConfigError(
            "CLOUDFLARE_ACCOUNT_ID does not match infra/cloudflare/pages-project.json."
        )

    env = dict(source_env)
    env["CLOUDFLARE_ACCOUNT_ID"] = expected_account_id
    return env


def ensure_build_output_exists(config: JsonObject, repo_root: Path = REPO_ROOT) -> None:
    output_dir = repo_root / str(config["deployment"]["build_output"])
    if not output_dir.is_dir():
        raise ConfigError(
            f"Missing build output {output_dir}. Run just web-build first."
        )


def run_pages_deploy(
    branch: str,
    *,
    dry_run: bool = False,
    environ: Mapping[str, str] | None = None,
) -> int:
    config = load_pages_config()
    errors = validate_pages_config(config)
    if errors:
        print("Cloudflare Pages config validation failed:")
        for error in errors:
            print(f"- ERROR: {error}")
        return 1

    branch = normalize_branch(branch)
    ensure_build_output_exists(config)
    env = pages_deploy_environment(config, environ)
    command = build_pages_deploy_command(config, branch)

    print(
        f"Deploying {config['deployment']['build_output']} to "
        f"Cloudflare Pages project {config['project_name']} on branch {branch}."
    )
    print(f"$ {shlex.join(command)}")
    if dry_run:
        return 0

    completed = subprocess.run(command, cwd=REPO_ROOT, env=env, check=False)
    return completed.returncode


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Deploy Sunclub's static web artifact to Cloudflare Pages."
    )
    parser.add_argument(
        "--branch",
        default="master",
        help="Cloudflare Pages branch to deploy. Defaults to master.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate config and print the Wrangler command without deploying.",
    )
    args = parser.parse_args(argv)

    try:
        return run_pages_deploy(args.branch, dry_run=bool(args.dry_run))
    except ConfigError as error:
        print(f"ERROR: {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
