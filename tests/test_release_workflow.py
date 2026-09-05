"""Exercise release event selection without Xcode, credentials or uploads."""

import os
import re
import subprocess
import textwrap
from pathlib import Path
from types import SimpleNamespace

import pytest

WORKFLOW = (
    Path(__file__).resolve().parents[1] / ".github/workflows/release-testflight.yml"
)


def steps():
    return dict(
        re.findall(
            r"^      - name: ([^\n]+)\n(.*?)(?=^      - |\Z)",
            WORKFLOW.read_text(),
            re.MULTILINE | re.DOTALL,
        )
    )


def run_script(step):
    run = re.search(r"^        run: (.*)$", step, re.MULTILINE)
    assert run is not None
    if run.group(1) == "|":
        return textwrap.dedent(step[run.end() + 1 :])
    return run.group(1)


def expression_value(expression, event):
    # These workflow policies use the shared equality/boolean/format subset.
    expression = expression.removeprefix("${{").removesuffix("}} ").removesuffix("}}")
    return eval(
        expression.strip().replace("&&", " and ").replace("||", " or "),
        {"__builtins__": {}, "format": str.format},
        {"github": SimpleNamespace(**event)},
    )


@pytest.mark.parametrize(
    "event_name,ref_type,ref_name,upload,artifact",
    [
        ("push", "tag", "v1.2.3", True, "sunclub-testflight-v1.2.3"),
        (
            "workflow_dispatch",
            "branch",
            "codex/release-validation",
            False,
            "sunclub-export-12345",
        ),
        ("workflow_dispatch", "tag", "v1.2.3", False, "sunclub-export-12345"),
    ],
)
def test_release_event_controls_upload_testers_and_artifact_name(
    tmp_path, event_name, ref_type, ref_name, upload, artifact
):
    workflow_steps = steps()
    archive_step = next(
        step
        for step in workflow_steps.values()
        if "bash scripts/appstore/archive-and-upload.sh" in step
    )
    script = tmp_path / "scripts/appstore/archive-and-upload.sh"
    script.parent.mkdir(parents=True)
    log = tmp_path / "archive-arguments"
    script.write_text('#!/bin/bash\nprintf "%s\\0" "$@" >> "$ARGUMENT_LOG"\n')
    event = {
        "event_name": event_name,
        "ref_type": ref_type,
        "ref_name": ref_name,
        "run_id": "12345",
    }
    result = subprocess.run(
        [
            "/bin/bash",
            "--noprofile",
            "--norc",
            "-euo",
            "pipefail",
            "-c",
            run_script(archive_step),
        ],
        cwd=tmp_path,
        env={
            **os.environ,
            "ARGUMENT_LOG": str(log),
            "RELEASE_EVENT_NAME": event_name,
            "RELEASE_REF_TYPE": ref_type,
        },
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    expected = [b"--allow-draft-metadata", b"--unsigned-archive"]
    if upload:
        expected.append(b"--upload-testflight")
    assert log.read_bytes().split(b"\0")[:-1] == expected

    tester_step = workflow_steps["Add Internal testers group"]
    condition = re.search(r"^        if: (.+)$", tester_step, re.MULTILINE)
    enabled = expression_value(condition.group(1), event) if condition else True
    assert enabled is upload

    artifact_step = workflow_steps["Upload release artifacts"]
    name = re.search(r"^          name: (.+)$", artifact_step, re.MULTILINE).group(1)
    resolved = re.sub(
        r"\$\{\{(.*?)\}\}",
        lambda match: str(expression_value(match.group(1), event)),
        name,
    )
    assert resolved == artifact
    assert "/" not in resolved


def test_release_workflow_requires_exact_source_ci_before_credentials():
    workflow = WORKFLOW.read_text()
    assert "workflow_dispatch:" in workflow
    assert workflow.index("scripts.tooling.ci_policy require-release") < workflow.index(
        "Materialize App Store Connect key"
    )
    archive_step = next(
        step
        for step in steps().values()
        if "bash scripts/appstore/archive-and-upload.sh" in step
    )
    assert "RELEASE_EVENT_NAME: ${{ github.event_name }}" in archive_step
    assert "RELEASE_REF_TYPE: ${{ github.ref_type }}" in archive_step
