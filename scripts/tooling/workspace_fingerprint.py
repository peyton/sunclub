"""Inputs that require Tuist generation, distinct from inputs Xcode recompiles."""

from __future__ import annotations

import hashlib
import json
import os
from collections.abc import Mapping
from pathlib import Path


def workspace_fingerprint(root: Path, environment: Mapping[str, str]) -> str:
    manifests = {
        root / name
        for name in (
            "mise.toml",
            "mise.lock",
            "app/Tuist.swift",
            "app/Workspace.swift",
            "app/Tuist/Package.swift",
            "app/Tuist/Package.resolved",
            "app/Sunclub/Project.swift",
            "scripts/tooling/sunclub.env",
        )
    }
    manifests.update((root / "app/Tuist/ProjectDescriptionHelpers").rglob("*.swift"))
    manifests.update((root / "app/Sunclub").glob("*.plist"))
    manifests.update((root / "app/Sunclub").glob("*.entitlements"))
    digest = hashlib.sha256()
    for path in sorted(manifests):
        if path.is_file():
            digest.update(str(path.relative_to(root)).encode())
            digest.update(b"\0" + path.read_bytes() + b"\0")
    for directory in (
        "Sources",
        "Resources",
        "Tests",
        "UITests",
        "WidgetExtension",
        "WatchApp",
        "WatchWidgetExtension",
    ):
        for path in sorted((root / "app/Sunclub" / directory).rglob("*")):
            if path.name != ".DS_Store":
                digest.update(str(path.relative_to(root)).encode() + b"\0")
    inputs = {
        key: value
        for key, value in environment.items()
        if key.startswith("TUIST_SUNCLUB_") or key in {"TUIST_TEAM_ID", "DEVELOPER_DIR"}
    }
    digest.update(json.dumps(inputs, sort_keys=True).encode())
    return digest.hexdigest()


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    print(workspace_fingerprint(root, os.environ))


if __name__ == "__main__":
    main()
