import json
import tarfile
from pathlib import Path

from scripts.web.package_static_site import package_site, sha256_file
from scripts.web.validate_static_site import (
    WEATHERKIT_CONFIG_EXPECTED_VALUES,
    validate_site,
)


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_committed_static_site_is_review_ready() -> None:
    errors = validate_site(REPO_ROOT / "web")

    assert errors == []


def test_weatherkit_config_uses_canonical_schema_and_safe_caps() -> None:
    config_path = REPO_ROOT / "web" / "config" / "weatherkit.json"
    schema_path = REPO_ROOT / "web" / "schemas" / "weatherkit-config.v1.json"

    assert config_path.exists()
    assert schema_path.exists()
    assert validate_site(REPO_ROOT / "web") == []


def test_weatherkit_config_does_not_reference_parked_domain() -> None:
    forbidden_fragments = (
        "https://sunclub." + "app/config/weatherkit",
        "https://sunclub." + "app/schemas/weatherkit",
    )
    roots = [
        REPO_ROOT / "app",
        REPO_ROOT / "scripts",
        REPO_ROOT / "tests",
        REPO_ROOT / "web",
        REPO_ROOT / ".github",
    ]

    matches: list[str] = []
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix in {".png", ".pdf"}:
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            for fragment in forbidden_fragments:
                if fragment in text:
                    matches.append(str(path.relative_to(REPO_ROOT)))

    assert matches == []


def test_static_site_validator_rejects_placeholder_and_missing_contact(
    tmp_path: Path,
) -> None:
    site_root = tmp_path / "web"
    site_root.mkdir()
    (site_root / "docs").mkdir()
    (site_root / "docs" / "automation").mkdir()
    (site_root / "config").mkdir()
    (site_root / "schemas").mkdir()
    (site_root / "support").mkdir()
    (site_root / "privacy").mkdir()
    (site_root / "assets").mkdir()
    (site_root / "assets" / "site.css").write_text("body { color: #111; }\n")
    (site_root / "robots.txt").write_text(
        "User-agent: *\nAllow: /\nSitemap: https://sunclub.peyton.app/sitemap.xml\n"
    )
    (site_root / "sitemap.xml").write_text(
        """
        <urlset>
          <url><loc>https://sunclub.peyton.app/</loc></url>
          <url><loc>https://sunclub.peyton.app/docs/</loc></url>
          <url><loc>https://sunclub.peyton.app/docs/automation/</loc></url>
          <url><loc>https://sunclub.peyton.app/support/</loc></url>
          <url><loc>https://sunclub.peyton.app/privacy/</loc></url>
        </urlset>
        """
    )
    broken_page = """
        <!doctype html>
        <html lang="en">
          <head>
            <title>Broken</title>
            <meta name="description" content="Broken page">
          </head>
          <body>
            <a href="#">Download on the App Store</a>
            <a href="mailto:support@sunclub.peyton.app">Old support address</a>
            <a href="/missing/">Missing</a>
          </body>
        </html>
        """
    for relative_path in (
        "index.html",
        "docs/index.html",
        "docs/automation/index.html",
        "support/index.html",
        "privacy/index.html",
        "404.html",
    ):
        (site_root / relative_path).write_text(broken_page)
    parked_schema = "https://sunclub." + "app/schemas/weatherkit-config.v1.json"
    (site_root / "config" / "weatherkit.json").write_text(
        json.dumps({"$schema": parked_schema, "version": 1}) + "\n",
        encoding="utf-8",
    )
    (site_root / "schemas" / "weatherkit-config.v1.json").write_text(
        json.dumps({"$id": parked_schema, "type": "object"}) + "\n",
        encoding="utf-8",
    )

    errors = validate_site(site_root)

    assert any("placeholder link" in error for error in errors)
    assert any("missing public contact email" in error for error in errors)
    assert any("missing public support email" in error for error in errors)
    assert any("missing public privacy email" in error for error in errors)
    assert any("missing public security email" in error for error in errors)
    assert any("@sunclub.peyton.app" in error for error in errors)
    assert any("download on the app store" in error for error in errors)
    assert any("broken internal" in error for error in errors)
    assert any("config/weatherkit.json" in error for error in errors)
    assert any("schemas/weatherkit-config.v1.json" in error for error in errors)


def test_static_site_validator_accepts_weatherkit_config_shape(tmp_path: Path) -> None:
    site_root = tmp_path / "web"
    config_dir = site_root / "config"
    schema_dir = site_root / "schemas"
    config_dir.mkdir(parents=True)
    schema_dir.mkdir(parents=True)
    (config_dir / "weatherkit.json").write_text(
        json.dumps(WEATHERKIT_CONFIG_EXPECTED_VALUES, indent=2) + "\n",
        encoding="utf-8",
    )
    (schema_dir / "weatherkit-config.v1.json").write_text(
        json.dumps(
            {
                "$id": "https://sunclub.peyton.app/schemas/weatherkit-config.v1.json",
                "type": "object",
                "additionalProperties": False,
                "required": list(WEATHERKIT_CONFIG_EXPECTED_VALUES),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    errors = [
        error for error in validate_site(site_root) if "weatherkit" in error.lower()
    ]

    assert errors == []


def test_static_site_package_contains_relative_site_files(tmp_path: Path) -> None:
    source_root = tmp_path / "web-build"
    source_root.mkdir()
    (source_root / "assets").mkdir()
    (source_root / "index.html").write_text("<!doctype html>\n", encoding="utf-8")
    (source_root / "assets" / "site.css").write_text(
        "body { color: #111; }\n",
        encoding="utf-8",
    )
    output_dir = tmp_path / "releases"

    result = package_site(source_root, "1.2.3", output_dir)

    assert result.archive_path == output_dir / "sunclub-web-1.2.3.tar.gz"
    assert result.checksum_path == output_dir / "sunclub-web-1.2.3.tar.gz.sha256"
    assert result.digest == sha256_file(result.archive_path)
    assert (
        result.checksum_path.read_text(encoding="utf-8")
        == f"{result.digest}  sunclub-web-1.2.3.tar.gz\n"
    )

    with tarfile.open(result.archive_path, "r:gz") as archive:
        assert archive.getnames() == ["assets/site.css", "index.html"]
        for member in archive.getmembers():
            assert member.uid == 0
            assert member.gid == 0
            assert member.mtime == 0
