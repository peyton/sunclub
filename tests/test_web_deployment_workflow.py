from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS_DIR = REPO_ROOT / ".github" / "workflows"
DEPLOY_WEB_WORKFLOW = WORKFLOWS_DIR / "deploy-web-cloudflare.yml"
RELEASE_WEB_WORKFLOW = WORKFLOWS_DIR / "release-web.yml"
ROLLBACK_WEB_WORKFLOW = WORKFLOWS_DIR / "rollback-web-cloudflare.yml"
RELEASE_TESTFLIGHT_WORKFLOW = WORKFLOWS_DIR / "release-testflight.yml"
JUSTFILE = REPO_ROOT / "justfile"

WEB_WORKFLOWS = (
    DEPLOY_WEB_WORKFLOW,
    RELEASE_WEB_WORKFLOW,
    ROLLBACK_WEB_WORKFLOW,
)


def workflow_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def uses_references(workflow: str) -> list[str]:
    return re.findall(r"uses:\s*([^\s#]+)", workflow)


def test_web_deploy_workflow_runs_only_for_web_directory_changes() -> None:
    workflow = workflow_text(DEPLOY_WEB_WORKFLOW)

    assert "branches: [master]" in workflow
    assert workflow.count('      - "web/**"') == 2
    assert "scripts/web/**" not in workflow
    assert "infra/cloudflare/**" not in workflow
    assert "justfile" not in workflow


def test_web_deploy_to_cloudflare_is_push_only() -> None:
    workflow = workflow_text(DEPLOY_WEB_WORKFLOW)

    assert (
        "if: ${{ github.event_name == 'push' && github.ref == 'refs/heads/master' }}"
        in workflow
    )
    assert (
        "pages deploy .build/web --project-name=sunclub --branch=master "
        "--commit-hash=${{ github.sha }}"
    ) in workflow


def test_web_package_builds_before_packaging() -> None:
    justfile = (REPO_ROOT / "justfile").read_text(encoding="utf-8")

    assert re.search(r"^web-package VERSION='local': web-build$", justfile, re.M)


def test_manual_cloudflare_pages_deploy_is_exposed_through_just() -> None:
    justfile = workflow_text(JUSTFILE)

    assert "cloudflare-pages-deploy BRANCH='master': web-build" in justfile
    assert (
        'uv run python -m scripts.cloudflare.pages_deploy --branch "{{BRANCH}}"'
        in justfile
    )
    assert "cloudflare-pages-dns:" in justfile
    assert "uv run python -m scripts.cloudflare.pages setup-dns" in justfile


def test_web_and_ios_release_tags_are_separate() -> None:
    web_workflow = workflow_text(RELEASE_WEB_WORKFLOW)
    ios_workflow = workflow_text(RELEASE_TESTFLIGHT_WORKFLOW)

    assert '- "web/v*.*.*"' in web_workflow
    assert '- "v*.*.*"' in ios_workflow
    assert "web/v*.*.*" not in ios_workflow


def test_web_workflows_do_not_use_ios_release_secrets() -> None:
    combined = "\n".join(workflow_text(path) for path in WEB_WORKFLOWS)

    assert "ASC_KEY_ID" not in combined
    assert "ASC_ISSUER_ID" not in combined
    assert "ASC_KEY_P8" not in combined
    assert "CLOUDFLARE_API_TOKEN" in combined
    assert "CLOUDFLARE_ACCOUNT_ID" in combined


def test_web_workflow_actions_are_pinned_to_full_commit_shas() -> None:
    for path in WEB_WORKFLOWS:
        workflow = workflow_text(path)
        for reference in uses_references(workflow):
            assert re.search(r"@[0-9a-f]{40}$", reference), (
                f"{path.name} action reference is not pinned to a full SHA: {reference}"
            )


def test_web_workflow_permissions_are_minimal() -> None:
    deploy_workflow = workflow_text(DEPLOY_WEB_WORKFLOW)
    release_workflow = workflow_text(RELEASE_WEB_WORKFLOW)
    rollback_workflow = workflow_text(ROLLBACK_WEB_WORKFLOW)

    assert re.search(
        r"build:\n(?:.*\n)*?    permissions:\n      contents: read\n",
        deploy_workflow,
    )
    assert re.search(
        r"deploy:\n(?:.*\n)*?    permissions:\n      contents: read\n",
        deploy_workflow,
    )
    assert "deployments: write" not in deploy_workflow
    assert "deployments: write" not in release_workflow
    assert "permissions:\n  contents: write\n" in release_workflow
    assert "permissions:\n  contents: read\n" in rollback_workflow
    assert "deployments: write" not in rollback_workflow


def test_cloudflare_web_workflows_use_single_github_deployment_environment() -> None:
    deploy_workflow = workflow_text(DEPLOY_WEB_WORKFLOW)
    rollback_workflow = workflow_text(ROLLBACK_WEB_WORKFLOW)
    combined = f"{deploy_workflow}\n{rollback_workflow}"

    assert combined.count("name: cloudflare-production") == 2
    assert combined.count("url: https://sunclub.peyton.app") == 2
    assert "gitHubToken:" not in combined


def test_web_rollback_is_manual_and_uses_release_assets() -> None:
    workflow = workflow_text(ROLLBACK_WEB_WORKFLOW)

    assert "workflow_dispatch:" in workflow
    assert "release_tag:" in workflow
    assert "gh release download" in workflow
    assert "shasum -a 256 -c" in workflow
    assert "pages deploy .build/web --project-name=sunclub --branch=master" in workflow
