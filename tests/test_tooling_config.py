from scripts.tooling.config import CONFIG, _resolve_shell_default


def test_tooling_config_matches_repo_contract() -> None:
    assert CONFIG.app_workspace == "app/Sunclub.xcworkspace"
    assert CONFIG.app_scheme == "Sunclub"
    assert CONFIG.default_simulator_device == "iPhone 17 Pro"
    assert CONFIG.test_simulator_name == "Sunclub Test iPhone 17 Pro"
    assert CONFIG.run_app_path.endswith("Sunclub.app")


def test_resolve_shell_default_uses_environment_override(monkeypatch) -> None:
    monkeypatch.setenv("APP_WORKSPACE", "custom/Sunclub.xcworkspace")

    assert (
        _resolve_shell_default("${APP_WORKSPACE:-app/Sunclub.xcworkspace}")
        == "custom/Sunclub.xcworkspace"
    )
