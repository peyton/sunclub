# CloudKit Setup

## Commands

- `just cloudkit-save-token`
- `just cloudkit-doctor`
- `just cloudkit-ensure-container`
- `just cloudkit-export-schema`
- `just cloudkit-validate-schema`

## Release preflight

Run `just cloudkit-doctor` first when a TestFlight crash or release issue points at CloudKit. If `.state/cloudkit/sunclub-cloudkit-schema.json` is missing or stale, run `just cloudkit-export-schema` and then `just cloudkit-validate-schema`.

These commands prove that the saved management token can see the team and that CloudKit accepts the development schema. They do not prove the final TestFlight IPA has CloudKit entitlements. For release artifacts, inspect the exported app entitlements from the downloaded GitHub Actions artifact, for example:

```bash
plutil -p /tmp/sunclub-vX.Y.Z/release-diagnostics/Sunclub.entitlements.plist
```

The final app signature must include `com.apple.developer.icloud-container-identifiers` with `iCloud.app.peyton.sunclub` and `com.apple.developer.icloud-services` with `CloudKit` for live iCloud sync. The TestFlight workflow ad-hoc signs unsigned archives with resolved release entitlements and then validates the exported IPA before upload. If final IPA entitlements are still absent, the workflow should fail before TestFlight distribution; the runtime guard is only a last-resort launch-crash guard.

## What `cloudkit-doctor` checks

1. The saved `cktool` token can access the configured team via `cktool get-teams`. If this passes, the token is a management token with team-level management API access.
2. `cktool export-schema` can access `iCloud.app.peyton.sunclub` in the configured environment.
3. If schema export still fails, the script runs a signed iOS build with `-allowProvisioningUpdates` on the same team and inspects the signed app entitlements.

## Interpreting failures

- If `cktool get-teams` does not list the configured team, the saved token is wrong for this repo or lacks access to the team.
- If the signed app entitlements do not include `com.apple.developer.icloud-container-identifiers = iCloud.app.peyton.sunclub` and `com.apple.developer.icloud-services = CloudKit`, then the App ID is still missing iCloud/CloudKit configuration on Apple’s side.
- If the signed app does include those entitlements but `cktool export-schema` still fails, the container exists and is assigned to the App ID; the remaining problem is CloudKit Console/API access on the Apple side.

## Manual Apple-side setup

Apple does not expose iCloud container creation through the installed `cktool` CLI in this repo. If `just cloudkit-ensure-container` reports missing CloudKit entitlements, finish the setup in Apple’s portal:

1. In Certificates, IDs & Profiles, create the iCloud container `iCloud.app.peyton.sunclub`.
2. Enable the iCloud capability on App ID `app.peyton.sunclub`.
3. Assign the `iCloud.app.peyton.sunclub` container to that App ID.
4. If you expect Xcode automatic signing to do that work, verify Automatic Signing Controls are not blocking App ID changes for your role.

Apple references:

- Create an iCloud container: <https://developer.apple.com/help/account/identifiers/create-an-icloud-container/>
- Enable iCloud for an App ID: <https://developer.apple.com/help/account/identifiers/enable-app-capabilities/>
- Automatic Signing Controls: <https://developer.apple.com/help/account/access/automatic-signing-controls/>

Apple’s help docs say creating an iCloud container requires the Account Holder or Admin role.
