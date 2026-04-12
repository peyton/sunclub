from pathlib import Path

from scripts.web.validate_static_site import validate_site


REPO_ROOT = Path(__file__).resolve().parents[1]


def test_committed_static_site_is_review_ready() -> None:
    errors = validate_site(REPO_ROOT / "web")

    assert errors == []


def test_static_site_validator_rejects_placeholder_and_missing_contact(
    tmp_path: Path,
) -> None:
    site_root = tmp_path / "web"
    site_root.mkdir()
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
            <a href="/missing/">Missing</a>
          </body>
        </html>
        """
    for relative_path in (
        "index.html",
        "support/index.html",
        "privacy/index.html",
        "404.html",
    ):
        (site_root / relative_path).write_text(broken_page)

    errors = validate_site(site_root)

    assert any("placeholder link" in error for error in errors)
    assert any("missing public support email" in error for error in errors)
    assert any("download on the app store" in error for error in errors)
    assert any("broken internal" in error for error in errors)
