from __future__ import annotations

import base64
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
import json
import os
from pathlib import Path
import subprocess
import time
from typing import Any, Self
from urllib import error, parse, request


JsonObject = dict[str, Any]
JsonBody = Mapping[str, Any]
OpenCallable = Callable[..., Any]
SleepCallable = Callable[[float], None]

DEFAULT_BASE_URL = "https://api.appstoreconnect.apple.com/v1"
RETRY_STATUSES = {429, 500, 502, 503, 504}


class AppStoreConnectError(RuntimeError):
    """Raised when App Store Connect rejects or cannot complete a request."""


@dataclass(frozen=True)
class AppStoreConnectCredentials:
    key_id: str
    issuer_id: str
    key_file: Path

    @classmethod
    def from_env(cls, environment: Mapping[str, str] | None = None) -> Self:
        values = environment or os.environ
        missing = [
            key
            for key in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_FILE")
            if not values.get(key)
        ]
        if missing:
            joined = ", ".join(missing)
            raise AppStoreConnectError(
                f"Missing App Store Connect environment variable(s): {joined}"
            )

        key_file = Path(values["ASC_KEY_FILE"])
        if not key_file.is_file():
            raise AppStoreConnectError(
                f"App Store Connect key file not found: {key_file}"
            )

        return cls(
            key_id=values["ASC_KEY_ID"],
            issuer_id=values["ASC_ISSUER_ID"],
            key_file=key_file,
        )

    def jwt(self, *, lifetime_seconds: int = 1200) -> str:
        now = int(time.time())
        header = {"alg": "ES256", "kid": self.key_id, "typ": "JWT"}
        payload = {
            "iss": self.issuer_id,
            "exp": now + lifetime_seconds,
            "aud": "appstoreconnect-v1",
        }
        signing_input = f"{urlsafe_json(header)}.{urlsafe_json(payload)}".encode(
            "utf-8"
        )
        try:
            result = subprocess.run(
                ["openssl", "dgst", "-sha256", "-sign", str(self.key_file)],
                input=signing_input,
                check=True,
                capture_output=True,
            )
        except FileNotFoundError as error_:
            raise AppStoreConnectError(
                "openssl is required to sign ASC JWTs."
            ) from error_
        except subprocess.CalledProcessError as error_:
            details = error_.stderr.decode("utf-8", errors="replace").strip()
            raise AppStoreConnectError(
                f"Failed to sign App Store Connect JWT: {details}"
            ) from error_

        signature = urlsafe_bytes(ecdsa_der_to_raw(result.stdout))
        return f"{signing_input.decode('utf-8')}.{signature}"


class AppStoreConnectClient:
    def __init__(
        self,
        credentials: AppStoreConnectCredentials | None = None,
        *,
        base_url: str = DEFAULT_BASE_URL,
        opener: OpenCallable = request.urlopen,
        jwt_factory: Callable[[], str] | None = None,
        sleep: SleepCallable = time.sleep,
        timeout: float = 60,
        max_retries: int = 3,
    ) -> None:
        self.credentials = credentials
        self.base_url = base_url.rstrip("/")
        self.opener = opener
        self.jwt_factory = jwt_factory
        self.sleep = sleep
        self.timeout = timeout
        self.max_retries = max_retries

    @classmethod
    def from_env(
        cls,
        environment: Mapping[str, str] | None = None,
        **kwargs: Any,
    ) -> Self:
        return cls(AppStoreConnectCredentials.from_env(environment), **kwargs)

    def get(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> JsonObject:
        return self.request_json("GET", path, query=query)

    def get_optional(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> JsonObject | None:
        try:
            return self.get(path, query=query)
        except AppStoreConnectError as error_:
            if "HTTP 404" in str(error_):
                return None
            raise

    def get_collection(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> list[JsonObject]:
        payload = self.get(path, query=query)
        results = list(collection_data(payload))
        next_url = next_link(payload)
        while next_url:
            payload = self.request_json_url("GET", next_url)
            results.extend(collection_data(payload))
            next_url = next_link(payload)
        return results

    def post(self, path: str, body: JsonBody) -> JsonObject:
        return self.request_json("POST", path, body=body)

    def patch(self, path: str, body: JsonBody) -> JsonObject:
        return self.request_json("PATCH", path, body=body)

    def delete(self, path: str) -> None:
        self.request_json("DELETE", path)

    def request_json(
        self,
        method: str,
        path: str,
        *,
        body: JsonBody | None = None,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> JsonObject:
        url = self.api_url(path, query)
        return self.request_json_url(method, url, body=body)

    def request_json_url(
        self,
        method: str,
        url: str,
        *,
        body: JsonBody | None = None,
    ) -> JsonObject:
        data = None
        headers = {
            "Authorization": f"Bearer {self.jwt()}",
            "Accept": "application/json",
        }
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"

        raw = self._request(method, url, body=data, headers=headers)
        if not raw:
            return {}
        return json.loads(raw.decode("utf-8"))

    def upload_operations(
        self, file_path: Path, operations: Sequence[JsonObject]
    ) -> None:
        data = file_path.read_bytes()
        for operation in operations:
            method = str(operation.get("method", "PUT"))
            url = str(operation["url"])
            offset = int(operation.get("offset", 0))
            length = int(operation.get("length", len(data)))
            headers = {
                str(header["name"]): str(header["value"])
                for header in operation.get("requestHeaders", [])
            }
            self._request(
                method,
                url,
                body=data[offset : offset + length],
                headers=headers,
                authorize=False,
            )

    def api_url(
        self,
        path: str,
        query: Mapping[str, str | int | bool | Sequence[str]] | None = None,
    ) -> str:
        if path.startswith("https://"):
            base = path
        else:
            base = f"{self.base_url}/{path.lstrip('/')}"
        if not query:
            return base
        return f"{base}?{encode_query(query)}"

    def jwt(self) -> str:
        if self.jwt_factory is not None:
            return self.jwt_factory()
        if self.credentials is None:
            raise AppStoreConnectError(
                "App Store Connect credentials are not configured."
            )
        return self.credentials.jwt()

    def _request(
        self,
        method: str,
        url: str,
        *,
        body: bytes | None = None,
        headers: Mapping[str, str] | None = None,
        authorize: bool = True,
    ) -> bytes:
        request_headers = dict(headers or {})
        if authorize and "Authorization" not in request_headers:
            request_headers["Authorization"] = f"Bearer {self.jwt()}"
        req = request.Request(
            url,
            data=body,
            headers=request_headers,
            method=method,
        )

        for attempt in range(self.max_retries + 1):
            try:
                with self.opener(req, timeout=self.timeout) as response:
                    return response.read()
            except error.HTTPError as error_:
                if error_.code in RETRY_STATUSES and attempt < self.max_retries:
                    self.sleep(retry_delay(error_, attempt))
                    continue
                raise AppStoreConnectError(http_error_message(error_)) from error_
            except error.URLError as error_:
                if attempt < self.max_retries:
                    self.sleep(2**attempt)
                    continue
                raise AppStoreConnectError(
                    f"Network request failed: {error_}"
                ) from error_

        raise AppStoreConnectError("Network request failed after retries.")


def urlsafe_json(payload: Mapping[str, Any]) -> str:
    raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    return urlsafe_bytes(raw)


def urlsafe_bytes(payload: bytes) -> str:
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def ecdsa_der_to_raw(signature: bytes, *, coordinate_size: int = 32) -> bytes:
    offset = 0

    def read_length() -> int:
        nonlocal offset
        if offset >= len(signature):
            raise AppStoreConnectError("Invalid ECDSA signature length.")
        first = signature[offset]
        offset += 1
        if first < 0x80:
            return first
        length_bytes = first & 0x7F
        if length_bytes == 0 or offset + length_bytes > len(signature):
            raise AppStoreConnectError("Invalid ECDSA signature length.")
        value = int.from_bytes(signature[offset : offset + length_bytes], "big")
        offset += length_bytes
        return value

    def read_integer() -> bytes:
        nonlocal offset
        if offset >= len(signature) or signature[offset] != 0x02:
            raise AppStoreConnectError("Invalid ECDSA signature integer.")
        offset += 1
        length = read_length()
        value = signature[offset : offset + length]
        offset += length
        normalized = value.lstrip(b"\x00")
        if len(normalized) > coordinate_size:
            raise AppStoreConnectError("ECDSA signature integer is too large.")
        return normalized.rjust(coordinate_size, b"\x00")

    if not signature or signature[offset] != 0x30:
        raise AppStoreConnectError("Invalid ECDSA signature sequence.")
    offset += 1
    sequence_length = read_length()
    sequence_end = offset + sequence_length
    if sequence_end != len(signature):
        raise AppStoreConnectError("Invalid ECDSA signature sequence length.")

    raw = read_integer() + read_integer()
    if offset != sequence_end:
        raise AppStoreConnectError("Invalid ECDSA signature trailing data.")
    return raw


def encode_query(query: Mapping[str, str | int | bool | Sequence[str]]) -> str:
    normalized: dict[str, str] = {}
    for key, value in query.items():
        if isinstance(value, bool):
            normalized[key] = "true" if value else "false"
        elif isinstance(value, str):
            normalized[key] = value
        elif isinstance(value, Sequence):
            normalized[key] = ",".join(str(item) for item in value)
        else:
            normalized[key] = str(value)
    return parse.urlencode(normalized)


def collection_data(payload: JsonObject) -> list[JsonObject]:
    data = payload.get("data", [])
    if not isinstance(data, list):
        raise AppStoreConnectError("Expected App Store Connect collection response.")
    return data


def next_link(payload: JsonObject) -> str | None:
    links = payload.get("links", {})
    if not isinstance(links, dict):
        return None
    next_value = links.get("next")
    return str(next_value) if next_value else None


def retry_delay(error_: error.HTTPError, attempt: int) -> float:
    retry_after = error_.headers.get("Retry-After") if error_.headers else None
    if retry_after:
        try:
            return float(retry_after)
        except ValueError:
            pass
    return float(2**attempt)


def http_error_message(error_: error.HTTPError) -> str:
    raw = error_.read()
    if not raw:
        return f"App Store Connect request failed with HTTP {error_.code}."

    try:
        payload = json.loads(raw.decode("utf-8"))
    except json.JSONDecodeError:
        detail = raw.decode("utf-8", errors="replace").strip()
        return f"App Store Connect request failed with HTTP {error_.code}: {detail}"

    errors = payload.get("errors")
    if isinstance(errors, list) and errors:
        messages = []
        for item in errors:
            if isinstance(item, dict):
                title = item.get("title")
                detail = item.get("detail")
                messages.append(
                    " - ".join(str(part) for part in (title, detail) if part)
                )
        if messages:
            return (
                f"App Store Connect request failed with HTTP {error_.code}: "
                + "; ".join(messages)
            )

    return f"App Store Connect request failed with HTTP {error_.code}."
