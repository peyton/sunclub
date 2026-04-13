from __future__ import annotations

from collections.abc import Sequence
import io
import json
from pathlib import Path
from typing import Any
from urllib import error, request

from scripts.appstore.connect_api import AppStoreConnectClient, ecdsa_der_to_raw


class FakeResponse:
    def __init__(self, payload: dict[str, Any] | bytes = b"") -> None:
        self.payload = (
            json.dumps(payload).encode("utf-8")
            if isinstance(payload, dict)
            else payload
        )

    def __enter__(self) -> "FakeResponse":
        return self

    def __exit__(self, *_args: object) -> None:
        return None

    def read(self) -> bytes:
        return self.payload


def test_client_adds_bearer_auth_and_paginates() -> None:
    calls: list[request.Request] = []
    responses = [
        {
            "data": [{"type": "apps", "id": "app-1"}],
            "links": {"next": "https://api.appstoreconnect.apple.com/v1/apps?page=2"},
        },
        {"data": [{"type": "apps", "id": "app-2"}], "links": {}},
    ]

    def opener(req: request.Request, *, timeout: float) -> FakeResponse:
        calls.append(req)
        return FakeResponse(responses.pop(0))

    client = AppStoreConnectClient(
        jwt_factory=lambda: "test-token",
        opener=opener,
    )

    data = client.get_collection("/apps", {"filter[bundleId]": "app.peyton.sunclub"})

    assert [item["id"] for item in data] == ["app-1", "app-2"]
    assert calls[0].get_header("Authorization") == "Bearer test-token"
    assert "filter%5BbundleId%5D=app.peyton.sunclub" in calls[0].full_url
    assert calls[1].full_url.endswith("/v1/apps?page=2")


def test_client_retries_transient_http_errors() -> None:
    attempts = 0

    def opener(req: request.Request, *, timeout: float) -> FakeResponse:
        nonlocal attempts
        attempts += 1
        if attempts == 1:
            raise error.HTTPError(
                req.full_url,
                500,
                "Server error",
                {},
                io.BytesIO(b'{"errors":[{"title":"Temporary","detail":"try again"}]}'),
            )
        return FakeResponse({"data": {"type": "apps", "id": "app-1"}})

    client = AppStoreConnectClient(
        jwt_factory=lambda: "test-token",
        opener=opener,
        sleep=lambda _seconds: None,
        max_retries=1,
    )

    assert client.get("/apps/app-1")["data"]["id"] == "app-1"
    assert attempts == 2


def test_client_uploads_asset_operations(tmp_path: Path) -> None:
    uploaded: list[tuple[str, bytes, str | None]] = []
    asset = tmp_path / "home.png"
    asset.write_bytes(b"abcdef")

    def opener(req: request.Request, *, timeout: float) -> FakeResponse:
        headers = {key.lower(): value for key, value in req.header_items()}
        uploaded.append(
            (
                req.full_url,
                req.data or b"",
                headers.get("content-type"),
            )
        )
        return FakeResponse()

    client = AppStoreConnectClient(
        jwt_factory=lambda: "test-token",
        opener=opener,
    )

    operations: Sequence[dict[str, Any]] = [
        {
            "method": "PUT",
            "url": "https://upload.example/part-1",
            "offset": 1,
            "length": 3,
            "requestHeaders": [
                {"name": "Content-Type", "value": "application/octet-stream"}
            ],
        }
    ]
    client.upload_operations(asset, operations)

    assert uploaded == [
        ("https://upload.example/part-1", b"bcd", "application/octet-stream")
    ]


def test_ecdsa_der_signature_is_converted_to_raw_jwt_shape() -> None:
    r = bytes.fromhex("01" * 32)
    s = bytes.fromhex("80" + "02" * 31)
    der = b"\x30\x45" + b"\x02\x20" + r + b"\x02\x21" + b"\x00" + s

    assert ecdsa_der_to_raw(der) == r + s
