from scripts.tooling.config import CONFIG


def test_tooling_config_matches_repo_contract() -> None:
    assert CONFIG.app_workspace == "app/Sunclub.xcworkspace"
    assert CONFIG.app_scheme == "Sunclub"
    assert CONFIG.default_simulator_device == "iPhone 17 Pro"
    assert CONFIG.test_simulator_name == "Sunclub Test iPhone 17 Pro"
    assert CONFIG.run_app_path.endswith("Sunclub.app")
