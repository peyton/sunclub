"""Validate the full TestFlight release pipeline setup.

Checks ASC credentials, API connectivity, bundle IDs, capabilities,
certificates, provisioning profiles, entitlements, metadata, and Xcode.

Usage:
    uv run python -m scripts.appstore.release_doctor
    uv run python -m scripts.appstore.release_doctor --flavor prod
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

from scripts.appstore.connect_api import (
    AppStoreConnectClient,
    AppStoreConnectCredentials,
    AppStoreConnectError,
)

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

# Required App ID capabilities for the main app bundle.
REQUIRED_CAPABILITIES = {
    "ICLOUD": "iCloud (CloudKit)",
    "PUSH_NOTIFICATIONS": "Push Notifications",
    "HEALTHKIT": "HealthKit",
    "APP_GROUPS": "App Groups",
    "WEATHERKIT": "WeatherKit",
}

# Bundle ID suffixes relative to the main app identifier.
BUNDLE_SUFFIXES = {
    "main app": "",
    "widget extension": ".widgets",
    "watch app": ".watch",
    "watch widget extension": ".watch.widgets",
}


class DoctorContext:
    def __init__(self, *, flavor: str) -> None:
        self.flavor = flavor
        self.passed = 0
        self.failed = 0
        self.warned = 0
        self.client: AppStoreConnectClient | None = None
        self.bundle_id_objects: dict[str, dict[str, Any]] = {}

        if flavor == "prod":
            self.app_identifier = "app.peyton.sunclub"
            self.app_group = "group.app.peyton.sunclub"
            self.cloudkit_container = "iCloud.app.peyton.sunclub"
        else:
            self.app_identifier = "app.peyton.sunclub.dev"
            self.app_group = "group.app.peyton.sunclub.dev"
            self.cloudkit_container = "iCloud.app.peyton.sunclub.dev"

    def section(self, title: str) -> None:
        print(f"\n\033[1;36m{'─' * 60}\033[0m")
        print(f"\033[1;36m  {title}\033[0m")
        print(f"\033[1;36m{'─' * 60}\033[0m")

    def ok(self, message: str) -> None:
        print(f"  \033[1;32m✓\033[0m {message}")
        self.passed += 1

    def fail(self, message: str, *, hint: str = "") -> None:
        print(f"  \033[1;31m✗\033[0m {message}")
        if hint:
            for line in hint.strip().splitlines():
                print(f"    \033[33m→ {line}\033[0m")
        self.failed += 1

    def warn(self, message: str, *, hint: str = "") -> None:
        print(f"  \033[1;33m!\033[0m {message}")
        if hint:
            for line in hint.strip().splitlines():
                print(f"    \033[33m→ {line}\033[0m")
        self.warned += 1

    def info(self, message: str) -> None:
        print(f"    \033[2m{message}\033[0m")


def check_asc_credentials(ctx: DoctorContext) -> bool:
    """Check that ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE are set and valid."""
    ctx.section("App Store Connect Credentials")

    key_id = os.environ.get("ASC_KEY_ID", "")
    issuer_id = os.environ.get("ASC_ISSUER_ID", "")
    key_file = os.environ.get("ASC_KEY_FILE", "")

    if not key_id:
        ctx.fail(
            "ASC_KEY_ID is not set",
            hint=(
                "Create an API key at https://appstoreconnect.apple.com/access/integrations/api\n"
                "Then: export ASC_KEY_ID='your-key-id'\n"
                "Or run: bash scripts/appstore/setup-signing.sh"
            ),
        )
        return False
    ctx.ok(f"ASC_KEY_ID is set ({key_id})")

    if not issuer_id:
        ctx.fail(
            "ASC_ISSUER_ID is not set",
            hint=(
                "Find your Issuer ID at https://appstoreconnect.apple.com/access/integrations/api\n"
                "Then: export ASC_ISSUER_ID='your-issuer-id'"
            ),
        )
        return False
    ctx.ok(f"ASC_ISSUER_ID is set ({issuer_id})")

    if not key_file:
        ctx.fail(
            "ASC_KEY_FILE is not set",
            hint=(
                "Download the .p8 key file from App Store Connect and set:\n"
                "  export ASC_KEY_FILE='$HOME/.appstoreconnect/AuthKey_<KEY_ID>.p8'"
            ),
        )
        return False

    key_path = Path(key_file)
    if not key_path.is_file():
        ctx.fail(
            f"ASC_KEY_FILE does not exist: {key_file}",
            hint="Download the .p8 key file from App Store Connect.",
        )
        return False
    ctx.ok(f"ASC_KEY_FILE exists ({key_file})")

    if not shutil.which("openssl"):
        ctx.fail(
            "openssl is not available",
            hint="Install openssl to sign ASC JWTs.",
        )
        return False

    try:
        creds = AppStoreConnectCredentials.from_env()
        creds.jwt()
        ctx.ok("JWT generation succeeded (openssl can sign with the .p8 key)")
    except AppStoreConnectError as error:
        ctx.fail(f"JWT generation failed: {error}")
        return False

    return True


def check_asc_api_connectivity(ctx: DoctorContext) -> bool:
    """Verify the ASC API accepts our credentials."""
    ctx.section("App Store Connect API")

    try:
        client = AppStoreConnectClient.from_env()
        client.get("/bundleIds", {"limit": 1})
        ctx.ok("Authenticated successfully (GET /bundleIds returned 200)")
        ctx.client = client
        return True
    except AppStoreConnectError as error:
        ctx.fail(
            f"API request failed: {error}",
            hint=(
                "Check that your API key has Admin or App Manager role.\n"
                "Revoked or expired keys will also cause this."
            ),
        )
        return False


def check_bundle_ids(ctx: DoctorContext) -> bool:
    """Verify all required bundle IDs are registered."""
    ctx.section("Bundle IDs")

    if ctx.client is None:
        ctx.fail("Skipped (no API connection)")
        return False

    all_found = True
    for label, suffix in BUNDLE_SUFFIXES.items():
        identifier = f"{ctx.app_identifier}{suffix}"
        matches = ctx.client.get_collection(
            "/bundleIds",
            {"filter[identifier]": identifier, "limit": 200},
        )
        exact = [
            bid
            for bid in matches
            if (bid.get("attributes") or {}).get("identifier") == identifier
        ]
        if exact:
            ctx.ok(f"{label}: {identifier}")
            ctx.bundle_id_objects[identifier] = exact[0]
        else:
            ctx.fail(
                f"{label}: {identifier} is not registered",
                hint=(
                    "Register it in the Apple Developer portal under\n"
                    "Certificates, Identifiers & Profiles > Identifiers,\n"
                    "or open the project in Xcode with automatic signing once."
                ),
            )
            all_found = False

    return all_found


def check_capabilities(ctx: DoctorContext) -> bool:
    """Check that the main app bundle ID has all required capabilities."""
    ctx.section("App ID Capabilities")

    if ctx.client is None:
        ctx.fail("Skipped (no API connection)")
        return False

    main_bundle = ctx.bundle_id_objects.get(ctx.app_identifier)
    if main_bundle is None:
        ctx.fail("Skipped (main bundle ID not found)")
        return False

    bundle_id = main_bundle["id"]
    try:
        capabilities = ctx.client.get_collection(
            f"/bundleIds/{bundle_id}/bundleIdCapabilities",
        )
    except AppStoreConnectError as error:
        ctx.fail(f"Could not fetch capabilities: {error}")
        return False

    enabled_types: set[str] = set()
    for cap in capabilities:
        cap_type = (cap.get("attributes") or {}).get("capabilityType")
        if cap_type:
            enabled_types.add(cap_type)

    all_ok = True
    for cap_type, label in REQUIRED_CAPABILITIES.items():
        if cap_type in enabled_types:
            ctx.ok(f"{label} ({cap_type})")
        else:
            ctx.fail(
                f"{label} ({cap_type}) is not enabled",
                hint=(
                    f"Enable {label} on App ID {ctx.app_identifier} at\n"
                    "https://developer.apple.com/account/resources/identifiers/list"
                ),
            )
            all_ok = False

    return all_ok


def check_distribution_certificate(ctx: DoctorContext) -> bool:
    """Check that an active distribution certificate exists."""
    ctx.section("Distribution Certificate")

    if ctx.client is None:
        ctx.fail("Skipped (no API connection)")
        return False

    from scripts.appstore.provisioning_profiles import (
        DISTRIBUTION_CERTIFICATE_TYPES,
        certificate_is_usable,
    )

    certificates_by_id: dict[str, dict[str, Any]] = {}
    for cert_type in DISTRIBUTION_CERTIFICATE_TYPES:
        for cert in ctx.client.get_collection(
            "/certificates",
            {"filter[certificateType]": cert_type, "limit": 200},
        ):
            certificates_by_id[cert["id"]] = cert

    usable = [c for c in certificates_by_id.values() if certificate_is_usable(c)]
    if usable:
        best = max(
            usable,
            key=lambda c: (c.get("attributes") or {}).get("expirationDate", ""),
        )
        expiry = (best.get("attributes") or {}).get("expirationDate", "unknown")
        ctx.ok(f"Active distribution certificate found (expires {expiry})")
        return True

    ctx.fail(
        "No active distribution certificate found",
        hint=(
            "The release pipeline will create one automatically,\n"
            "but your ASC API key needs Admin or App Manager role."
        ),
    )
    return False


def check_provisioning_profiles(ctx: DoctorContext) -> bool:
    """Check that active App Store profiles exist for all bundles."""
    ctx.section("Provisioning Profiles")

    if ctx.client is None:
        ctx.fail("Skipped (no API connection)")
        return False

    all_ok = True
    for label, suffix in BUNDLE_SUFFIXES.items():
        identifier = f"{ctx.app_identifier}{suffix}"
        bundle_obj = ctx.bundle_id_objects.get(identifier)
        if bundle_obj is None:
            ctx.warn(f"{label}: skipped (bundle ID not registered)")
            continue

        bundle_id = bundle_obj["id"]
        profiles = ctx.client.get_collection(
            f"/bundleIds/{bundle_id}/profiles",
            {"limit": 200},
        )

        from scripts.appstore.provisioning_profiles import (
            APP_STORE_PROFILE_TYPE,
            profile_is_active,
            profile_matches_type,
        )

        active = [
            p
            for p in profiles
            if profile_matches_type(p, APP_STORE_PROFILE_TYPE) and profile_is_active(p)
        ]

        if active:
            best = max(
                active,
                key=lambda p: (p.get("attributes") or {}).get("expirationDate", ""),
            )
            name = (best.get("attributes") or {}).get("name", "unknown")
            expiry = (best.get("attributes") or {}).get("expirationDate", "unknown")
            ctx.ok(f"{label}: {name} (expires {expiry})")
        else:
            ctx.warn(
                f"{label}: no active App Store profile for {identifier}",
                hint="The release pipeline will create one automatically during archive.",
            )

    return all_ok


def check_cloudkit(ctx: DoctorContext) -> None:
    """Check CloudKit container accessibility via cktool."""
    ctx.section("CloudKit")

    cktool = shutil.which("cktool")
    if cktool is None:
        try:
            result = subprocess.run(
                ["xcrun", "--find", "cktool"],
                capture_output=True,
                text=True,
                check=True,
            )
            cktool = result.stdout.strip()
        except FileNotFoundError, subprocess.CalledProcessError:
            pass

    if not cktool:
        ctx.warn(
            "cktool not available (Xcode command-line tools may not be installed)",
            hint="Run: xcode-select --install",
        )
        return

    token_args: list[str] = []
    cktool_token = os.environ.get("CKTOOL_TOKEN", "")
    if cktool_token:
        token_args = ["--token", cktool_token]

    try:
        result = subprocess.run(
            ["xcrun", "cktool", "get-teams", *token_args],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            ctx.fail(
                "cktool get-teams failed",
                hint="Save a CloudKit management token with: just cloudkit-save-token",
            )
            return
    except FileNotFoundError:
        ctx.warn("xcrun not available")
        return
    except subprocess.TimeoutExpired:
        ctx.warn("cktool get-teams timed out")
        return

    team_id = os.environ.get("CLOUDKIT_TEAM_ID", "3VDQ4656LX")
    if f"{team_id}:" not in result.stdout:
        ctx.fail(
            f"Team {team_id} is not visible to the CloudKit management token",
            hint="Check the token or run: just cloudkit-save-token",
        )
        return
    ctx.ok(f"CloudKit management token is valid for team {team_id}")

    environment = os.environ.get("CLOUDKIT_ENVIRONMENT", "development")
    try:
        probe = subprocess.run(
            [
                "xcrun",
                "cktool",
                "export-schema",
                *token_args,
                "--team-id",
                team_id,
                "--container-id",
                ctx.cloudkit_container,
                "--environment",
                environment,
                "--output-file",
                "/dev/null",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if probe.returncode == 0:
            ctx.ok(
                f"CloudKit container {ctx.cloudkit_container} is accessible ({environment})"
            )
        else:
            ctx.fail(
                f"Cannot access CloudKit container {ctx.cloudkit_container} ({environment})",
                hint=(
                    "Create the container at https://developer.apple.com/account/resources/identifiers/list\n"
                    "and assign it to the App ID, or run: just cloudkit-doctor"
                ),
            )
    except subprocess.TimeoutExpired:
        ctx.warn("cktool export-schema timed out")


def check_entitlements(ctx: DoctorContext) -> None:
    """Check that entitlements templates can be resolved."""
    ctx.section("Entitlements")

    from scripts.appstore.resolve_entitlements import resolve_entitlements

    source = REPO_ROOT / "app" / "Sunclub" / "Sunclub.entitlements"
    if not source.is_file():
        ctx.fail(f"Entitlements source not found: {source}")
        return

    aps_env = os.environ.get("SUNCLUB_APS_ENVIRONMENT", "production")
    replacements = {
        "SUNCLUB_APS_ENVIRONMENT": aps_env,
        "SUNCLUB_ICLOUD_ENVIRONMENT": "Production"
        if aps_env == "production"
        else "Development",
        "SUNCLUB_ICLOUD_CONTAINER": ctx.cloudkit_container,
        "SUNCLUB_APP_GROUP_ID": ctx.app_group,
    }

    output = REPO_ROOT / ".build" / "doctor-entitlements" / "Sunclub.entitlements.plist"
    try:
        resolve_entitlements(source, output, replacements)
        ctx.ok("Entitlements resolved without unresolved placeholders")
        output.unlink(missing_ok=True)
        output.parent.rmdir()
    except (ValueError, OSError) as error:
        ctx.fail(f"Entitlements resolution failed: {error}")


def check_metadata(ctx: DoctorContext) -> None:
    """Run the metadata validator in draft mode."""
    ctx.section("App Store Metadata")

    try:
        result = subprocess.run(
            [
                sys.executable,
                "-m",
                "scripts.appstore.validate_metadata",
                "--allow-draft",
            ],
            capture_output=True,
            text=True,
            cwd=str(REPO_ROOT),
            timeout=30,
        )
        if result.returncode == 0:
            ctx.ok("Metadata validates (draft mode)")
        else:
            output = (result.stderr or result.stdout).strip()
            ctx.fail(
                "Metadata validation failed",
                hint=output[:500] if output else "Run: just appstore-validate",
            )
    except FileNotFoundError:
        ctx.fail("Python not available to run metadata validation")
    except subprocess.TimeoutExpired:
        ctx.warn("Metadata validation timed out")


def check_xcode(ctx: DoctorContext) -> None:
    """Report the local Xcode version and compare to the CI pin."""
    ctx.section("Xcode")

    ci_version = _read_ci_xcode_version()
    if ci_version:
        ctx.info(f"CI-pinned Xcode version: {ci_version}")

    try:
        result = subprocess.run(
            ["xcodebuild", "-version"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0:
            version_line = result.stdout.strip().splitlines()[0]
            ctx.ok(f"Local: {version_line}")
            if ci_version and ci_version not in version_line:
                ctx.warn(
                    f"Local Xcode does not match CI pin ({ci_version})",
                    hint="This is fine for local development but CI uses the pinned version.",
                )
        else:
            ctx.fail(
                "xcodebuild -version failed",
                hint="Is Xcode installed? Run: xcode-select --install",
            )
    except FileNotFoundError:
        ctx.warn("xcodebuild not found (not on macOS or Xcode not installed)")
    except subprocess.TimeoutExpired:
        ctx.warn("xcodebuild -version timed out")


def _read_ci_xcode_version() -> str | None:
    workflow = REPO_ROOT / ".github" / "workflows" / "release-testflight.yml"
    if not workflow.is_file():
        return None
    for line in workflow.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("SUNCLUB_XCODE_VERSION:"):
            return stripped.split(":", 1)[1].strip().strip('"').strip("'")
    return None


def check_github_secrets_reminder(ctx: DoctorContext) -> None:
    """Remind about GitHub Actions secrets that cannot be checked locally."""
    ctx.section("GitHub Actions Secrets (manual check)")

    ctx.info("The following secrets must be set in your GitHub repo")
    ctx.info("under Settings > Environments > testflight:")
    ctx.info("")
    ctx.info("  ASC_KEY_ID       — same value as your local ASC_KEY_ID")
    ctx.info("  ASC_KEY_P8       — full contents of your .p8 key file")
    ctx.info("  ASC_ISSUER_ID    — same value as your local ASC_ISSUER_ID")
    ctx.info("")
    ctx.info("Also confirm the 'testflight' environment exists in")
    ctx.info("Settings > Environments.")
    ctx.warn("Cannot verify GitHub secrets from the CLI — check manually")


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(
        description="Validate the full TestFlight release pipeline setup.",
    )
    parser.add_argument(
        "--flavor",
        default=os.environ.get("SUNCLUB_FLAVOR", "prod"),
        choices=("prod", "dev"),
        help="App flavor to check (default: prod)",
    )
    args = parser.parse_args()

    ctx = DoctorContext(flavor=args.flavor)

    print("\033[1m")
    print("  Sunclub Release Doctor")
    print(f"  Flavor: {ctx.flavor} ({ctx.app_identifier})")
    print("\033[0m")

    has_creds = check_asc_credentials(ctx)

    if has_creds:
        has_api = check_asc_api_connectivity(ctx)
    else:
        has_api = False
        ctx.section("App Store Connect API")
        ctx.fail("Skipped (credentials not configured)")

    if has_api:
        check_bundle_ids(ctx)
        check_capabilities(ctx)
        check_distribution_certificate(ctx)
        check_provisioning_profiles(ctx)
    else:
        for title in [
            "Bundle IDs",
            "App ID Capabilities",
            "Distribution Certificate",
            "Provisioning Profiles",
        ]:
            ctx.section(title)
            ctx.fail("Skipped (no API connection)")

    check_cloudkit(ctx)
    check_entitlements(ctx)
    check_metadata(ctx)
    check_xcode(ctx)
    check_github_secrets_reminder(ctx)

    # Summary
    print(f"\n\033[1m{'━' * 60}\033[0m")
    parts = [f"\033[1;32m{ctx.passed} passed\033[0m"]
    if ctx.failed:
        parts.append(f"\033[1;31m{ctx.failed} failed\033[0m")
    if ctx.warned:
        parts.append(f"\033[1;33m{ctx.warned} warnings\033[0m")
    print(f"  {', '.join(parts)}")

    if ctx.failed:
        print("\n  Fix the failures above before pushing a release tag.")
        print(
            "  For credential setup run: \033[1mbash scripts/appstore/setup-signing.sh\033[0m"
        )
        print("  For CloudKit issues run:  \033[1mjust cloudkit-doctor\033[0m")
        print(f"\033[1m{'━' * 60}\033[0m")
        return 1

    if ctx.warned:
        print("\n  Warnings are non-blocking but worth reviewing.")

    print(f"\033[1m{'━' * 60}\033[0m")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
