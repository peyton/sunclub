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
    def __init__(
        self,
        *,
        stale_submission_item: bool = False,
        reject_whats_new_once: bool = False,
        reject_accessibility_publish_once: bool = False,
        reject_build_encryption_once: bool = False,
        reject_app_store_version_create_once: bool = False,
        rejected_submission_item: bool = False,
        existing_editable_version: Mapping[str, Any] | None = None,
        category_ids: Mapping[str, str] | None = None,
        existing_review_detail: Mapping[str, Any] | None = None,
    ) -> None:
        self.stale_submission_item = stale_submission_item
        self.reject_whats_new_once = reject_whats_new_once
        self.reject_accessibility_publish_once = reject_accessibility_publish_once
        self.reject_build_encryption_once = reject_build_encryption_once
        self.reject_app_store_version_create_once = reject_app_store_version_create_once
        self.rejected_submission_item = rejected_submission_item
        self.existing_editable_version = existing_editable_version
        self.category_ids = dict(category_ids or {})
        self.existing_review_detail = existing_review_detail
        self.build_calls = 0
        self.posts: list[tuple[str, Mapping[str, Any]]] = []
        self.patches: list[tuple[str, Mapping[str, Any]]] = []
        self.deletes: list[str] = []
        self.uploaded: list[Path] = []
        self.collection_queries: list[
            tuple[str, Mapping[str, str | int | bool | Sequence[str]] | None]
        ] = []

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
        if path.startswith("/appInfos/info-1/relationships/"):
            relationship = path.rsplit("/", 1)[-1]
            category_id = self.category_ids.get(relationship)
            return {
                "data": (
                    {"type": "appCategories", "id": category_id}
                    if category_id
                    else None
                )
            }
        raise AssertionError(f"Unexpected get path: {path}")

    def get_optional(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> dict[str, Any] | None:
        if path.endswith("/appStoreReviewDetail"):
            if self.existing_review_detail is None:
                return None
            return dict(self.existing_review_detail)
        raise AssertionError(f"Unexpected get_optional path: {path}")

    def get_collection(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[dict[str, Any]]:
        self.collection_queries.append((path, query))
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
            if (
                self.existing_editable_version is not None
                and query is not None
                and "filter[versionString]" not in query
            ):
                return [dict(self.existing_editable_version)]
            return []
        if path in {
            "/appStoreVersions/version-1/appStoreVersionLocalizations",
            "/appStoreVersions/version-existing/appStoreVersionLocalizations",
        }:
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
            requested_state = query.get("filter[state]") if query is not None else None
            if self.rejected_submission_item:
                if requested_state != "UNRESOLVED_ISSUES":
                    return []
                version_id = (
                    "version-existing"
                    if self.existing_editable_version is not None
                    else "version-1"
                )
                return [
                    {
                        "type": "reviewSubmissions",
                        "id": "review-1",
                        "attributes": {"state": "UNRESOLVED_ISSUES"},
                        "relationships": {
                            "appStoreVersionForReview": {
                                "data": {
                                    "type": "appStoreVersions",
                                    "id": version_id,
                                }
                            }
                        },
                    }
                ]
            if requested_state == "UNRESOLVED_ISSUES":
                return []
            return [
                {
                    "type": "reviewSubmissions",
                    "id": "review-1",
                    "attributes": {"state": "READY_FOR_REVIEW"},
                }
            ]
        if path == "/reviewSubmissions/review-1/items":
            if self.rejected_submission_item:
                version_id = (
                    "version-existing"
                    if self.existing_editable_version is not None
                    else "version-1"
                )
                item: dict[str, Any] = {
                    "type": "reviewSubmissionItems",
                    "id": "item-rejected",
                    "attributes": {"state": "REJECTED"},
                }
                if query_requests_item_app_store_version(query):
                    item["relationships"] = {
                        "appStoreVersion": {
                            "data": {
                                "type": "appStoreVersions",
                                "id": version_id,
                            }
                        }
                    }
                return [item]
            if self.stale_submission_item:
                item = {
                    "type": "reviewSubmissionItems",
                    "id": "item-old",
                    "attributes": {"state": "READY_FOR_REVIEW"},
                }
                if query_requests_item_app_store_version(query):
                    item["relationships"] = {
                        "appStoreVersion": {
                            "data": {
                                "type": "appStoreVersions",
                                "id": "different-version",
                            }
                        }
                    }
                return [item]
            return []
        raise AssertionError(f"Unexpected collection path: {path}")

    def post(self, path: str, body: Mapping[str, Any]) -> dict[str, Any]:
        self.posts.append((path, body))
        if path == "/appStoreVersions" and self.reject_app_store_version_create_once:
            self.reject_app_store_version_create_once = False
            raise AppStoreConnectError(
                "The provided entity includes a relationship with an invalid value - "
                "You cannot create a new version of the App in the current state."
            )
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
            "/reviewSubmissions": ("reviewSubmissions", "review-1"),
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
        attributes = body.get("data", {}).get("attributes", {})
        if (
            self.reject_build_encryption_once
            and path.startswith("/builds/")
            and isinstance(attributes, Mapping)
            and "usesNonExemptEncryption" in attributes
        ):
            self.reject_build_encryption_once = False
            raise AppStoreConnectError(
                "The provided entity includes an attribute with an invalid value - "
                "You cannot update when the value is already set."
            )
        if (
            self.reject_whats_new_once
            and path.startswith("/appStoreVersionLocalizations/")
            and isinstance(attributes, Mapping)
            and "whatsNew" in attributes
        ):
            self.reject_whats_new_once = False
            raise AppStoreConnectError(
                "Attribute 'whatsNew' cannot be edited at this time"
            )
        if (
            self.reject_accessibility_publish_once
            and path.startswith("/accessibilityDeclarations/")
            and isinstance(attributes, Mapping)
            and attributes.get("publish") is True
        ):
            self.reject_accessibility_publish_once = False
            raise AppStoreConnectError(
                "An app with the 'iOS' platform must be available on the App Store "
                "to publish an 'accessibilityDeclarations' with an 'IPHONE' device family."
            )
        return {"data": {"type": "patched", "id": path.rsplit("/", 1)[-1]}}

    def delete(self, path: str) -> None:
        self.deletes.append(path)

    def upload_operations(
        self,
        file_path: Path,
        operations: Sequence[dict[str, Any]],
    ) -> None:
        self.uploaded.append(file_path)


def query_requests_item_app_store_version(
    query: Mapping[str, str | int | bool | Sequence[str]] | None,
) -> bool:
    if query is None:
        return False
    fields = query.get("fields[reviewSubmissionItems]")
    if isinstance(fields, str):
        return "appStoreVersion" in fields.split(",")
    if isinstance(fields, Sequence):
        return "appStoreVersion" in fields
    return False


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


def test_submitter_reuses_editable_version_when_create_is_blocked(
    tmp_path: Path,
) -> None:
    manifest = ready_manifest(tmp_path)
    client = FakeSubmissionClient(
        reject_app_store_version_create_once=True,
        existing_editable_version={
            "type": "appStoreVersions",
            "id": "version-existing",
            "attributes": {
                "versionString": "1.0.57",
                "appStoreState": "REJECTED",
            },
        },
    )
    submitter = AppStoreReviewSubmitter(
        client,
        manifest,
        SubmissionContext(marketing_version="1.2.3", build_number="20260412.1.1"),
        repo_root=tmp_path,
        sleep=lambda _seconds: None,
        poll_interval_seconds=0,
    )

    result = submitter.submit()

    assert result.app_store_version_id == "version-existing"
    version_patch = next(
        body
        for path, body in client.patches
        if path == "/appStoreVersions/version-existing"
    )
    assert version_patch["data"]["attributes"]["versionString"] == "1.2.3"
    assert (
        "/appStoreVersions/version-existing/relationships/build",
        {"data": {"type": "builds", "id": "build-1"}},
    ) in client.patches
    assert any(path == "/appStoreVersions" for path, _body in client.posts)


def test_submitter_resolves_rejected_review_item_for_update_review(
    tmp_path: Path,
) -> None:
    manifest = ready_manifest(tmp_path)
    client = FakeSubmissionClient(
        reject_app_store_version_create_once=True,
        rejected_submission_item=True,
        existing_editable_version={
            "type": "appStoreVersions",
            "id": "version-existing",
            "attributes": {
                "versionString": "1.0.57",
                "appStoreState": "METADATA_REJECTED",
            },
        },
    )
    submitter = AppStoreReviewSubmitter(
        client,
        manifest,
        SubmissionContext(marketing_version="1.2.3", build_number="20260412.1.1"),
        repo_root=tmp_path,
        sleep=lambda _seconds: None,
        poll_interval_seconds=0,
    )

    result = submitter.submit()

    assert result.app_store_version_id == "version-existing"
    assert result.review_submission_id == "review-1"
    assert result.review_submission_item_id == "item-rejected"
    assert (
        "/reviewSubmissionItems/item-rejected",
        {
            "data": {
                "type": "reviewSubmissionItems",
                "id": "item-rejected",
                "attributes": {"resolved": True},
            }
        },
    ) in client.patches
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
    assert any(
        path == "/reviewSubmissions/review-1/items"
        and query_requests_item_app_store_version(query)
        for path, query in client.collection_queries
    )
    assert not any(path == "/reviewSubmissionItems" for path, _body in client.posts)


def test_submitter_reuses_existing_review_contact(tmp_path: Path) -> None:
    manifest = ready_manifest(tmp_path)
    manifest["review"]["contact"] = {
        "first_name": "",
        "last_name": "",
        "email": "",
        "phone": "",
    }
    client = FakeSubmissionClient(
        existing_review_detail={
            "data": {
                "type": "appStoreReviewDetails",
                "id": "review-detail-1",
                "attributes": {
                    "contactFirstName": "Existing",
                    "contactLastName": "Reviewer",
                    "contactEmail": "existing@example.com",
                    "contactPhone": "+14155550100",
                },
            }
        }
    )
    submitter = AppStoreReviewSubmitter(
        client,
        manifest,
        SubmissionContext(marketing_version="1.2.3", build_number="20260412.1.1"),
        repo_root=tmp_path,
        sleep=lambda _seconds: None,
        poll_interval_seconds=0,
        reuse_existing_review_contact=True,
    )

    assert submitter.upsert_review_detail("version-1") == "review-detail-1"

    review_detail_patch = next(
        body
        for path, body in client.patches
        if path == "/appStoreReviewDetails/review-detail-1"
    )
    attributes = review_detail_patch["data"]["attributes"]
    assert attributes["contactFirstName"] == "Existing"
    assert attributes["contactLastName"] == "Reviewer"
    assert attributes["contactEmail"] == "existing@example.com"
    assert attributes["contactPhone"] == "+14155550100"
    assert attributes["notes"] == manifest["review"]["notes"]


def test_submitter_retries_initial_version_localization_without_whats_new(
    tmp_path: Path,
) -> None:
    manifest = ready_manifest(tmp_path)
    client = FakeSubmissionClient(reject_whats_new_once=True)
    submitter = AppStoreReviewSubmitter(
        client,
        manifest,
        SubmissionContext(marketing_version="1.2.3", build_number="20260412.1.1"),
        repo_root=tmp_path,
        sleep=lambda _seconds: None,
        poll_interval_seconds=0,
    )

    submitter.ensure_version_localization("version-1")

    localization_patches = [
        body
        for path, body in client.patches
        if path == "/appStoreVersionLocalizations/version-loc-1"
    ]
    assert len(localization_patches) == 2
    assert "whatsNew" in localization_patches[0]["data"]["attributes"]
    assert "whatsNew" not in localization_patches[1]["data"]["attributes"]


def test_submitter_ignores_already_set_build_encryption(
    tmp_path: Path,
) -> None:
    manifest = ready_manifest(tmp_path)
    client = FakeSubmissionClient(reject_build_encryption_once=True)
    submitter = AppStoreReviewSubmitter(
        client,
        manifest,
        SubmissionContext(marketing_version="1.2.3", build_number="20260412.1.1"),
        repo_root=tmp_path,
        sleep=lambda _seconds: None,
        poll_interval_seconds=0,
    )

    assert submitter.wait_for_valid_build("app-1") == "build-1"

    build_patches = [body for path, body in client.patches if path == "/builds/build-1"]
    assert len(build_patches) == 1
    assert build_patches[0]["data"]["attributes"]["usesNonExemptEncryption"] is False


def test_submitter_skips_category_update_when_relationships_already_match(
    tmp_path: Path,
) -> None:
    manifest = ready_manifest(tmp_path)
    client = FakeSubmissionClient(
        category_ids={
            "primaryCategory": "HEALTH_AND_FITNESS",
            "secondaryCategory": "LIFESTYLE",
        }
    )
    submitter = AppStoreReviewSubmitter(
        client,
        manifest,
        SubmissionContext(marketing_version="1.2.3", build_number="20260412.1.1"),
        repo_root=tmp_path,
        sleep=lambda _seconds: None,
        poll_interval_seconds=0,
    )

    submitter.update_app_info("app-1")

    assert not any(
        path == "/appInfos/info-1/relationships/primaryCategory"
        for path, _body in client.patches
    )
    assert not any(
        path == "/appInfos/info-1/relationships/secondaryCategory"
        for path, _body in client.patches
    )


def test_submitter_saves_accessibility_when_first_submission_cannot_publish(
    tmp_path: Path,
) -> None:
    manifest = ready_manifest(tmp_path)
    client = FakeSubmissionClient(reject_accessibility_publish_once=True)
    submitter = AppStoreReviewSubmitter(
        client,
        manifest,
        SubmissionContext(marketing_version="1.2.3", build_number="20260412.1.1"),
        repo_root=tmp_path,
        sleep=lambda _seconds: None,
        poll_interval_seconds=0,
    )

    submitter.publish_accessibility_declaration("app-1")

    accessibility_patches = [
        body
        for path, body in client.patches
        if path == "/accessibilityDeclarations/accessibility-1"
    ]
    assert len(accessibility_patches) == 2
    assert accessibility_patches[0]["data"]["attributes"]["publish"] is True
    assert "publish" not in accessibility_patches[1]["data"]["attributes"]


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
