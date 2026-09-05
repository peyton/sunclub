"""CI policy, standalone on Python 3.9+ before the locked tool setup runs."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from fnmatch import fnmatchcase
from pathlib import Path

IOS_JOBS = ("test-ios-unit", "test-ios-ui", "build-ios")
NON_IOS_PATHS = (
    "web/*",
    "scripts/web/*",
    "scripts/cloudflare/*",
    "infra/cloudflare/*",
    "tests/test_web_*.py",
    "tests/test_cloudflare_config.py",
    "docs/*.md",
    "README.md",
    "AGENTS.md",
    "app/README.md",
    "DESIGN.md",
    ".github/workflows/deploy-web-cloudflare.yml",
    ".github/workflows/release-web.yml",
    ".github/workflows/rollback-web-cloudflare.yml",
)


def requires_ios(event: str, paths: list[str] | None) -> bool:
    return (
        event != "pull_request"
        or not paths
        or any(
            not any(fnmatchcase(path, pattern) for pattern in NON_IOS_PATHS)
            for path in paths
        )
    )


def gate_errors(needs: dict) -> list[str]:
    errors = []
    for name in ("changes", "lint", "test-python"):
        if needs.get(name, {}).get("result") != "success":
            errors.append(f"{name} did not succeed")
    run_ios = needs.get("changes", {}).get("outputs", {}).get("run_ios")
    if run_ios not in ("true", "false"):
        errors.append("Missing or invalid iOS change classification")
    expected = "skipped" if run_ios == "false" else "success"
    for name in IOS_JOBS:
        if needs.get(name, {}).get("result") != expected:
            errors.append(f"{name}: expected {expected}")
    return errors


def is_full_ci_run(run: dict, jobs: list[dict], sha: str) -> bool:
    if (
        run.get("head_sha") != sha
        or run.get("conclusion") != "success"
        or run.get("event") not in ("push", "workflow_dispatch")
    ):
        return False
    gate = any(
        job.get("name") == "CI" and job.get("conclusion") == "success" for job in jobs
    )
    full_ui = any(
        job.get("name") == "iOS UI Tests"
        and job.get("conclusion") == "success"
        and any(
            step.get("name") == "Run full UI tests"
            and step.get("conclusion") == "success"
            for step in job.get("steps", [])
        )
        for job in jobs
    )
    return gate and full_ui


def gh_json(endpoint: str) -> list[dict]:
    return json.loads(
        subprocess.check_output(
            ["gh", "api", "--paginate", "--slurp", endpoint], text=True
        )
    )


def require_clean_release_source() -> None:
    try:
        changes = subprocess.check_output(
            [
                "git",
                "--no-optional-locks",
                "status",
                "--porcelain=v1",
                "--untracked-files=all",
                "--ignore-submodules=none",
                "-z",
            ],
            stderr=subprocess.STDOUT,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(
            "Release blocked: could not verify a clean release source tree."
        ) from error
    if changes:
        raise SystemExit(
            "Release blocked: release source has uncommitted changes. "
            "Commit tracked, staged and untracked source changes, then run full CI "
            "for that exact commit before signing or exporting. "
            "Ignored generated outputs are allowed."
        )


def require_full_ci(sha: str) -> None:
    repo = (
        os.environ.get("GITHUB_REPOSITORY")
        or subprocess.check_output(
            ["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"],
            text=True,
        ).strip()
    )
    pages = gh_json(
        f"repos/{repo}/actions/workflows/ci.yml/runs?head_sha={sha}&status=success&per_page=100"
    )
    for page in pages:
        for run in page["workflow_runs"]:
            if run.get("event") not in ("push", "workflow_dispatch"):
                continue
            job_pages = gh_json(
                f"repos/{repo}/actions/runs/{run['id']}/jobs?filter=latest&per_page=100"
            )
            jobs = [job for part in job_pages for job in part["jobs"]]
            if is_full_ci_run(run, jobs, sha):
                print(f"Full CI verified for {sha}: {run['html_url']}")
                return
    raise SystemExit(
        f"Release blocked: no successful full CI for {sha}. "
        "Run `gh workflow run ci.yml --ref <branch-or-tag-at-this-SHA>`, "
        "wait for CI to pass, then retry."
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("changes", "gate", "require-release"))
    parser.add_argument("--sha")
    args = parser.parse_args()
    if args.command == "gate":
        errors = gate_errors(json.loads(os.environ["NEEDS_JSON"]))
        if errors:
            raise SystemExit("\n".join(errors))
        print("All required CI checks passed.")
    elif args.command == "require-release":
        require_clean_release_source()
        sha = (
            args.sha
            or subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
        )
        require_full_ci(sha)
    else:
        paths = None
        event = os.environ.get("GITHUB_EVENT_NAME", "workflow_dispatch")
        if event == "pull_request":
            try:
                changed = subprocess.check_output(
                    [
                        "git",
                        "diff",
                        "--name-only",
                        "--no-renames",
                        "-z",
                        f"{os.environ['CI_BASE_SHA']}...{os.environ['CI_HEAD_SHA']}",
                    ],
                )
                paths = [
                    path.decode("utf-8", errors="surrogateescape")
                    for path in changed.split(b"\0")
                    if path
                ]
            except (subprocess.CalledProcessError, KeyError):
                print("Could not determine changed paths; running iOS checks.")
        run_ios = requires_ios(event, paths)
        output = f"run_ios={str(run_ios).lower()}\n"
        print(output, end="")
        with Path(os.environ["GITHUB_OUTPUT"]).open("a") as stream:
            stream.write(output)


if __name__ == "__main__":
    main()
