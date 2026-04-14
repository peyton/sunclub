from pathlib import Path

from scripts.tooling.config import CONFIG, _resolve_shell_default


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_justfile_exposes_app_review_submission_commands() -> None:
    justfile = (REPO_ROOT / "justfile").read_text()

    assert "appstore-submit-dry-run:" in justfile
    assert "bash scripts/appstore/submit-review.sh --dry-run" in justfile
    assert "appstore-submit-review:" in justfile
    assert "bash scripts/appstore/submit-review.sh --submit" in justfile
    assert "release-testflight VERSION:" in justfile
    assert "VERSION={{VERSION}} bash scripts/appstore/release-tag.sh" in justfile


def test_tooling_config_matches_repo_contract() -> None:
    assert CONFIG.app_workspace == "app/Sunclub.xcworkspace"
    assert CONFIG.app_scheme == "SunclubDev"
    assert CONFIG.release_app_scheme == "Sunclub"
    assert CONFIG.app_identifier == "app.peyton.sunclub.dev"
    assert CONFIG.release_app_identifier == "app.peyton.sunclub"
    assert CONFIG.default_simulator_device == "iPhone 17 Pro"
    assert CONFIG.test_simulator_name == "Sunclub Test iPhone 17 Pro"
    assert CONFIG.run_app_path.endswith("SunclubDev.app")
    assert CONFIG.cloudkit_container_id == "iCloud.app.peyton.sunclub"
    assert CONFIG.cloudkit_team_id == CONFIG.team_id
    assert CONFIG.cloudkit_environment == "development"


def test_resolve_shell_default_uses_environment_override(monkeypatch) -> None:
    monkeypatch.setenv("APP_WORKSPACE", "custom/Sunclub.xcworkspace")

    assert (
        _resolve_shell_default("${APP_WORKSPACE:-app/Sunclub.xcworkspace}")
        == "custom/Sunclub.xcworkspace"
    )


def test_tooling_config_can_resolve_production_flavor_paths() -> None:
    assert CONFIG.app_scheme_for_flavor("prod") == "Sunclub"
    assert CONFIG.app_identifier_for_flavor("prod") == "app.peyton.sunclub"
    assert CONFIG.run_app_path_for_flavor("prod").endswith("Sunclub.app")
