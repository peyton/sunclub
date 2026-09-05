import ast
import json
import os
import subprocess
from pathlib import Path

import pytest

from scripts.tooling.ci_policy import gate_errors, is_full_ci_run, requires_ios

ROOT = Path(__file__).resolve().parents[1]


def test_policy_syntax_supports_python_before_tool_setup():
    source = (ROOT / "scripts/tooling/ci_policy.py").read_text()
    ast.parse(source, feature_version=(3, 9))


def test_policy_runs_with_system_python_before_tool_setup(tmp_path):
    python = Path("/usr/bin/python3")
    if not python.exists():
        pytest.skip("System Python smoke check is available on macOS/Linux runners")
    output = tmp_path / "github-output"
    environment = {
        **os.environ,
        "GITHUB_EVENT_NAME": "pull_request",
        "GITHUB_OUTPUT": str(output),
        "NEEDS_JSON": json.dumps(needs()),
    }
    environment.pop("CI_BASE_SHA", None)
    for command in ("changes", "gate"):
        result = subprocess.run(
            [str(python), "-m", "scripts.tooling.ci_policy", command],
            cwd=ROOT,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )
        assert result.returncode == 0, result.stderr
    assert output.read_text() == "run_ios=true\n"


@pytest.mark.parametrize(
    "paths",
    [["web/index.html"], ["docs/architecture.md"], ["README.md", "web/styles.css"]],
)
def test_known_web_and_docs_prs_skip_ios(paths):
    assert not requires_ios("pull_request", paths)


@pytest.mark.parametrize(
    "event,paths",
    [
        ("push", ["web/index.html"]),
        ("workflow_dispatch", ["README.md"]),
        ("pull_request", []),
        ("pull_request", None),
        ("pull_request", ["app/Sunclub/Sources/New.swift"]),
        ("pull_request", [".github/actions/setup/action.yml"]),
        ("pull_request", ["unknown"]),
        ("pull_request", ["web/index.html", "mise.lock"]),
    ],
)
def test_full_or_uncertain_changes_run_ios(event, paths):
    assert requires_ios(event, paths)


def needs(run_ios=True):
    return {
        **{
            name: {"result": "success"}
            for name in [
                "lint",
                "test-python",
                "test-ios-unit",
                "test-ios-ui",
                "build-ios",
            ]
        },
        "changes": {"result": "success", "outputs": {"run_ios": str(run_ios).lower()}},
    }


def test_ci_gate_requires_every_expected_result():
    assert gate_errors(needs()) == []
    for job in needs():
        for result in ["failure", "cancelled", "skipped"]:
            payload = needs()
            payload[job]["result"] = result
            assert gate_errors(payload), (job, result)
    assert gate_errors({})


def test_ci_gate_accepts_only_classified_ios_skips():
    payload = needs(False)
    for job in ["test-ios-unit", "test-ios-ui", "build-ios"]:
        payload[job]["result"] = "skipped"
    assert gate_errors(payload) == []
    payload["test-python"]["result"] = "skipped"
    assert gate_errors(payload)


def test_release_evidence_requires_exact_sha_full_tests_and_gate():
    run = {"head_sha": "abc", "conclusion": "success", "event": "push"}
    jobs = [
        {"name": "CI", "conclusion": "success"},
        {
            "name": "iOS UI Tests",
            "conclusion": "success",
            "steps": [{"name": "Run full UI tests", "conclusion": "success"}],
        },
    ]
    assert is_full_ci_run(run, jobs, "abc")
    assert not is_full_ci_run(run, jobs, "different")
    assert not is_full_ci_run({**run, "event": "pull_request"}, jobs, "abc")
    assert not is_full_ci_run(run, jobs[:1], "abc")
    assert not is_full_ci_run(run, jobs[1:], "abc")
    jobs[1]["steps"][0]["name"] = "Run UI smoke tests"
    assert not is_full_ci_run(run, jobs, "abc")
