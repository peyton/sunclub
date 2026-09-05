from pathlib import Path

from scripts.tooling.workspace_fingerprint import workspace_fingerprint


def test_generation_tracks_membership_but_not_swift_implementation(tmp_path: Path):
    source = tmp_path / "app/Sunclub/Sources/Feature.swift"
    source.parent.mkdir(parents=True)
    source.write_text("struct Feature {}")
    initial = workspace_fingerprint(tmp_path, {})
    source.write_text("struct Feature { let count = 1 }")
    assert workspace_fingerprint(tmp_path, {}) == initial
    added = source.with_name("Other.swift")
    added.write_text("struct Other {}")
    assert workspace_fingerprint(tmp_path, {}) != initial
    added.unlink()
    assert workspace_fingerprint(tmp_path, {}) == initial


def test_generation_tracks_manifests_tools_resources_and_environment(tmp_path: Path):
    for name in [
        "app/Sunclub/Project.swift",
        "mise.lock",
        "scripts/tooling/sunclub.env",
    ]:
        path = tmp_path / name
        path.parent.mkdir(parents=True, exist_ok=True)
        before = workspace_fingerprint(tmp_path, {})
        path.write_text("first")
        assert workspace_fingerprint(tmp_path, {}) != before
        before = workspace_fingerprint(tmp_path, {})
        path.write_text("second")
        assert workspace_fingerprint(tmp_path, {}) != before
    initial = workspace_fingerprint(tmp_path, {})
    resource = tmp_path / "app/Sunclub/Resources/Assets.xcassets/New.imageset/icon.png"
    resource.parent.mkdir(parents=True)
    resource.write_bytes(b"image")
    assert workspace_fingerprint(tmp_path, {}) != initial
    assert workspace_fingerprint(
        tmp_path, {"TUIST_SUNCLUB_BUILD_NUMBER": "2"}
    ) != workspace_fingerprint(tmp_path, {"TUIST_SUNCLUB_BUILD_NUMBER": "1"})
    assert workspace_fingerprint(
        tmp_path, {"DEVELOPER_DIR": "/new/Xcode"}
    ) != workspace_fingerprint(tmp_path, {})


def test_generation_ignores_build_outputs_and_unrelated_environment(tmp_path: Path):
    initial = workspace_fingerprint(tmp_path, {})
    generated = tmp_path / "app/Sunclub/Derived/Generated.swift"
    generated.parent.mkdir(parents=True)
    generated.write_text("generated")
    assert workspace_fingerprint(tmp_path, {"UNRELATED": "value"}) == initial
