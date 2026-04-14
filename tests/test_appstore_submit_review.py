from __future__ import annotations

from collections.abc import Mapping, Sequence
import copy
from pathlib import Path
import struct
from typing import Any

import pytest

from scripts.appstore import manifest as appstore_manifest
from scripts.appstore.connect_api import AppStoreConnectError
from scripts.appstore.submit_review import (
    CHECKPOINT_CONFIRMATION_ENV,
    CONFIRMATION_ENV,
    AppStoreReviewSubmitter,
    SubmissionContext,
    collect_screenshot_files,
    dry_run_lines,
    local_validation,
    require_confirmation,
    write_checkpoint_summary,
)


REPO_ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = REPO_ROOT / "scripts" / "appstore" / "metadata.json"
READY_ENV = {
    "SUNCLUB_APP_REVIEW_CONTACT_FIRST_NAME": "Peyton",
    "SUNCLUB_APP_REVIEW_CONTACT_LAST_NAME": "Randolph",
    "SUNCLUB_APP_REVIEW_CONTACT_EMAIL": "review@example.com",
    "SUNCLUB_APP_REVIEW_CONTACT_PHONE": "+1-415-555-0100",
    "SUNCLUB_APP_PRIVACY_COMPLETED": "1",
    "SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS": "NOT_MEDICAL_DEVICE",
}


class FakeSubmissionClient:
    def __init__(self, *, stale_submission_item: bool = False) -> None:
        self.stale_submission_item = stale_submission_item
        self.build_calls = 0
        self.posts: list[tuple[str, Mapping[str, Any]]] = []
        self.patches: list[tuple[str, Mapping[str, Any]]] = []
        self.deletes: list[str] = []
        self.uploaded: list[Path] = []

    def get(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> dict[str, Any]:
        if path.startswith("/appScreenshots/"):
            return {
                "data": {
                    "type": "appScreenshots",
                    "id": "screenshot-1",
                    "attributes": {"assetDeliveryState": {"state": "COMPLETE"}},
                }
            }
        raise AssertionError(f"Unexpected get path: {path}")

    def get_optional(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> dict[str, Any] | None:
        if path.endswith("/appStoreReviewDetail"):
            return None
        raise AssertionError(f"Unexpected get_optional path: {path}")

    def get_collection(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[dict[str, Any]]:
        if path == "/apps":
            return [{"type": "apps", "id": "app-1", "attributes": {}}]
        if path == "/builds":
            self.build_calls += 1
            state = "PROCESSING" if self.build_calls == 1 else "VALID"
            return [
                {
                    "type": "builds",
                    "id": "build-1",
                    "attributes": {"processingState": state},
                }
            ]
        if path == "/apps/app-1/appStoreVersions":
            return []
        if path == "/appStoreVersions/version-1/appStoreVersionLocalizations":
            return []
        if path == "/apps/app-1/appInfos":
            return [{"type": "appInfos", "id": "info-1", "attributes": {}}]
        if path == "/appInfos/info-1/appInfoLocalizations":
            return []
        if path == "/appStoreVersionLocalizations/version-loc-1/appScreenshotSets":
            return []
        if path == "/apps/app-1/accessibilityDeclarations":
            return []
        if path == "/apps/app-1/reviewSubmissions":
            return [{"type": "reviewSubmissions", "id": "review-1", "attributes": {}}]
        if path == "/reviewSubmissions/review-1/items":
            if self.stale_submission_item:
                return [
                    {
                        "type": "reviewSubmissionItems",
                        "id": "item-old",
                        "relationships": {
                            "appStoreVersion": {
                                "data": {
                                    "type": "appStoreVersions",
                                    "id": "different-version",
                                }
                            }
                        },
                    }
                ]
            return []
        raise AssertionError(f"Unexpected collection path: {path}")

    def post(self, path: str, body: Mapping[str, Any]) -> dict[str, Any]:
        self.posts.append((path, body))
        ids = {
            "/appStoreVersions": ("appStoreVersions", "version-1"),
            "/appStoreVersionLocalizations": (
                "appStoreVersionLocalizations",
                "version-loc-1",
            ),
            "/appInfoLocalizations": ("appInfoLocalizations", "info-loc-1"),
            "/appScreenshotSets": ("appScreenshotSets", "screenshot-set-1"),
            "/appScreenshots": ("appScreenshots", "screenshot-1"),
            "/accessibilityDeclarations": (
                "accessibilityDeclarations",
                "accessibility-1",
            ),
            "/appStoreReviewDetails": ("appStoreReviewDetails", "review-detail-1"),
            "/reviewSubmissionItems": ("reviewSubmissionItems", "item-1"),
        }
        resource_type, resource_id = ids[path]
        response: dict[str, Any] = {
            "data": {"type": resource_type, "id": resource_id, "attributes": {}}
        }
        if path == "/appScreenshots":
            response["data"]["attributes"] = {
                "uploadOperations": [
                    {
                        "method": "PUT",
                        "url": "https://upload.example/screenshot",
                        "offset": 0,
                        "length": 24,
                        "requestHeaders": [],
                    }
                ]
            }
        return response

    def patch(self, path: str, body: Mapping[str, Any]) -> dict[str, Any]:
        self.patches.append((path, body))
        return {"data": {"type": "patched", "id": path.rsplit("/", 1)[-1]}}

    def delete(self, path: str) -> None:
        self.deletes.append(path)

    def upload_operations(
        self,
        file_path: Path,
        operations: Sequence[dict[str, Any]],
    ) -> None:
        self.uploaded.append(file_path)


def ready_manifest(tmp_path: Path) -> dict[str, Any]:
    manifest = appstore_manifest.load_resolved_manifest(
        MANIFEST_PATH,
        environment=READY_ENV,
        load_env_file=False,
    )
    manifest = copy.deepcopy(manifest)
    manifest["accessibility"]["iphone"]["ready"] = True
    manifest["assets"]["screenshots"]["output_directory"] = "screenshots"
    for screenshot in collect_screenshot_files(manifest, tmp_path):
        screenshot.path.parent.mkdir(parents=True, exist_ok=True)
        write_png(screenshot.path)
    return manifest


def write_png(path: Path, *, width: int = 1320, height: int = 2868) -> None:
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" + struct.pack(">II", width, height)
    )


def test_local_validation_requires_screenshots_for_submit(tmp_path: Path) -> None:
    manifest = ready_manifest(tmp_path)
    for screenshot in collect_screenshot_files(manifest, tmp_path):
        screenshot.path.unlink()

    errors, warnings = local_validation(
        manifest,
        repo_root=tmp_path,
        submission_ready=True,
    )

    assert any("Missing screenshot:" in error for error in errors)
    assert warnings == []


def test_dry_run_reports_planned_mutations_without_network(tmp_path: Path) -> None:
    manifest = ready_manifest(tmp_path)
    errors, warnings = local_validation(
        manifest,
        repo_root=tmp_path,
        submission_ready=False,
    )

    lines = dry_run_lines(
        manifest,
        SubmissionContext(marketing_version="1.2.3", build_number="20260412.1.1"),
        warnings,
    )

    assert errors == []
    assert "App Store review submission dry run" in lines
    assert any("Submit the draft review submission" in line for line in lines)


def test_final_submit_requires_confirmation() -> None:
    namespace = type("Args", (), {"confirm_submit": False})()

    with pytest.raises(AppStoreConnectError, match="requires --confirm-submit"):
        require_confirmation(namespace, {})


def test_final_submit_requires_checkpoint_confirmation() -> None:
    namespace = type("Args", (), {"confirm_submit": True})()

    with pytest.raises(AppStoreConnectError, match="checkpoint gate"):
        require_confirmation(namespace, {CONFIRMATION_ENV: "1"})


def test_final_submit_accepts_noninteractive_ci_bypass_when_all_gates_are_set() -> None:
    namespace = type("Args", (), {"confirm_submit": False})()

    require_confirmation(
        namespace,
        {
            CONFIRMATION_ENV: "1",
            CHECKPOINT_CONFIRMATION_ENV: "1",
        },
    )


def test_checkpoint_summary_redacts_contact_and_prints_exact_phrase(
    tmp_path: Path,
) -> None:
    report = appstore_manifest.load_resolved_manifest_report(
        MANIFEST_PATH,
        environment=READY_ENV,
        load_env_file=False,
    )
    output_path = tmp_path / "summary.md"

    write_checkpoint_summary(
        report,
        context=SubmissionContext(
            marketing_version="1.2.3",
            build_number="20260414.1.1",
        ),
        warnings=[],
        output_path=output_path,
    )

    summary = output_path.read_text()
    assert "review@example.com" not in summary
    assert "r***@example.com" in summary
    assert "submit Sunclub 1.2.3 (20260414.1.1) to App Review" in summary


def test_review_env_file_loads_without_tracked_secret_paths(tmp_path: Path) -> None:
    key_file = tmp_path / "AuthKey_TEST.p8"
    key_file.write_text("private key")
    env_file = tmp_path / "review.env"
    env_file.write_text(
        "\n".join(
            [
                "export SUNCLUB_APP_REVIEW_CONTACT_FIRST_NAME=Peyton",
                "export SUNCLUB_APP_REVIEW_CONTACT_LAST_NAME=Randolph",
                "export SUNCLUB_APP_REVIEW_CONTACT_EMAIL=review@example.com",
                "export SUNCLUB_APP_REVIEW_CONTACT_PHONE=+14155550100",
                "export SUNCLUB_APP_PRIVACY_COMPLETED=1",
                "export SUNCLUB_REGULATED_MEDICAL_DEVICE_STATUS=NOT_MEDICAL_DEVICE",
                f"export ASC_KEY_FILE={key_file}",
            ]
        )
    )

    manifest = appstore_manifest.load_resolved_manifest(
        MANIFEST_PATH,
        environment={},
        env_file=env_file,
    )

    assert manifest["review"]["contact"]["email"] == "review@example.com"
    assert manifest["privacy"]["app_store_connect_completed"] is True


def test_submitter_creates_review_submission_flow(tmp_path: Path) -> None:
    manifest = ready_manifest(tmp_path)
    client = FakeSubmissionClient()
    submitter = AppStoreReviewSubmitter(
        client,
        manifest,
        SubmissionContext(marketing_version="1.2.3", build_number="20260412.1.1"),
        repo_root=tmp_path,
        sleep=lambda _seconds: None,
        poll_interval_seconds=0,
    )

    result = submitter.submit()

    assert result.app_id == "app-1"
    assert result.build_id == "build-1"
    assert result.app_store_version_id == "version-1"
    assert result.review_submission_id == "review-1"
    assert result.review_submission_item_id == "item-1"
    assert client.uploaded
    assert (
        "/reviewSubmissions/review-1",
        {
            "data": {
                "type": "reviewSubmissions",
                "id": "review-1",
                "attributes": {"submitted": True},
            }
        },
    ) in client.patches
    assert any(path == "/accessibilityDeclarations" for path, _body in client.posts)
    assert any(
        path == "/appInfos/info-1/relationships/primaryCategory"
        for path, _body in client.patches
    )
    assert any(
        path == "/appInfos/info-1/relationships/secondaryCategory"
        for path, _body in client.patches
    )


def test_submitter_rejects_stale_draft_review_submission(tmp_path: Path) -> None:
    manifest = ready_manifest(tmp_path)
    client = FakeSubmissionClient(stale_submission_item=True)
    submitter = AppStoreReviewSubmitter(
        client,
        manifest,
        SubmissionContext(marketing_version="1.2.3", build_number="20260412.1.1"),
        repo_root=tmp_path,
        sleep=lambda _seconds: None,
        poll_interval_seconds=0,
    )

    with pytest.raises(AppStoreConnectError, match="different app version"):
        submitter.submit()
