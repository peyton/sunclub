# App Store Submission Guide

Complete walkthrough for submitting Sunclub to the App Store. Every step uses the command line where possible.

## Files Created

```
scripts/appstore/
├── metadata.json               # App name, description, keywords, review notes
├── screenshots.html            # Marketing screenshot mockups (open in browser)
├── capture-screenshots.sh      # Export screenshots via Puppeteer
├── setup-signing.sh            # One-time credential setup (interactive)
├── bump-version.sh             # Set marketing version in Project.swift
├── archive-and-upload.sh       # Build → Archive → Export IPA → Upload
├── create-app-store-listing.sh # Push metadata to ASC via API
└── ExportOptions.plist         # Xcode export config for App Store
```

## Prerequisites

- macOS with Xcode 16+
- Active Apple Developer Program membership ($99/year)
- `just`, `tuist`, `jq` installed (`brew install just jq`)
- FastVLM model downloaded (`just download-model`)

---

## Phase 1: One-Time Setup

### 1.1 Run the setup script

```bash
./scripts/appstore/setup-signing.sh
```

This walks you through:
- Storing your Apple ID as `SUNCLUB_APPLE_ID`
- Creating an app-specific password and saving it to Keychain
- (Optional) Setting up an ASC API key for metadata automation

### 1.2 Add env vars to your shell

```bash
# Add to ~/.zshrc
export SUNCLUB_APPLE_ID="your@email.com"

# Optional — only if you set up an ASC API key:
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ASC_KEY_FILE="$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
```

Then reload:

```bash
source ~/.zshrc
```

### 1.3 Create the app in App Store Connect

This is the one step that must be done in a browser (Apple doesn't support app creation via CLI/API).

1. Go to https://appstoreconnect.apple.com/apps
2. Click **+** → **New App**
3. Fill in:
   - **Name:** `Sunclub — Daily Sunscreen`
   - **Primary Language:** English (U.S.)
   - **Bundle ID:** `app.peyton.sunclub`
   - **SKU:** `sunclub-ios-001`
4. Click **Create**

---

## Phase 2: Prepare the Build

### 2.1 Set the marketing version

```bash
./scripts/appstore/bump-version.sh 1.0
```

### 2.2 Regenerate the Xcode project

```bash
cd app && tuist install && tuist generate --no-open && cd ..
```

### 2.3 Run tests

```bash
just test
```

---

## Phase 3: Screenshots

### 3.1 Review the mockups

```bash
open scripts/appstore/screenshots.html
```

Six screens are pre-built matching the Sunclub UI: Welcome, Home, AI Verification, Success, Weekly Summary, and Settings.

### 3.2 Export as PNGs

**Option A — Puppeteer (automated):**

```bash
brew install node    # if needed
./scripts/appstore/capture-screenshots.sh
```

Output lands in `.build/screenshots/`.

**Option B — Manual browser capture:**

Open `screenshots.html` in Chrome, right-click each phone frame → Inspect → select the `.marketing-card` node → right-click → "Capture node screenshot".

### 3.3 Resize to exact App Store dimensions

App Store requires **1290 × 2796** for 6.7-inch. If your captures aren't exact:

```bash
# Using sips (built into macOS)
for f in .build/screenshots/*.png; do
  sips -z 2796 1290 "$f"
done
```

---

## Phase 4: Archive and Upload

### 4.1 Dry run first

```bash
./scripts/appstore/archive-and-upload.sh --dry-run
```

This builds, archives, and exports the IPA without uploading. Verify there are no signing or build errors.

### 4.2 Upload for real

```bash
./scripts/appstore/archive-and-upload.sh
```

The script:
1. Generates the Tuist project
2. Sets a timestamped build number
3. Archives a Release build
4. Exports an IPA with automatic signing
5. Validates the IPA with App Store Connect
6. Uploads via `xcrun altool`

Wait 5–15 minutes for App Store Connect to finish processing the build.

---

## Phase 5: App Store Metadata

### 5.1 Review metadata.json

All App Store copy lives in `scripts/appstore/metadata.json`. Edit anything you want to change — name, description, keywords, promotional text, review notes.

### 5.2 Push metadata via API (optional)

If you set up the ASC API key:

```bash
./scripts/appstore/create-app-store-listing.sh
```

This updates the description, keywords, promo text, support URL, and privacy URL on your App Store listing.

### 5.3 Upload screenshots

Screenshots must be uploaded through App Store Connect UI or Transporter:

```bash
# Open Transporter (if installed)
open -a Transporter
```

Or drag the PNGs directly into the App Store Connect screenshot slots in your browser.

---

## Phase 6: Final Checklist

Complete these in App Store Connect (https://appstoreconnect.apple.com):

### App Privacy

Since Sunclub is fully on-device with no data collection:

1. Go to **App Privacy** in your app's page
2. Select **Data types collected: None**
3. Save

### Pricing

1. Go to **Pricing and Availability**
2. Set base price to **Free**
3. Add in-app purchases if your subscription StoreKit config is ready

### Age Rating

1. Go to **Age Rating**
2. Answer all questions — Sunclub has no objectionable content
3. Expected rating: **4+**

### Review Information

From `metadata.json`:

- **Notes:** Sunclub uses the device camera to verify sunscreen via an on-device vision model (FastVLM). No images are uploaded. To test: tap "Verify Now" and point at any sunscreen bottle. You can also use "Log Manually".
- **Demo account:** None required (fully local app)

---

## Phase 7: Submit for Review

```bash
# Check your build was processed
# (Look for it in App Store Connect → TestFlight → builds)
```

1. In App Store Connect, go to your app → **App Store** tab
2. Select the build you uploaded
3. Click **Add for Review**
4. Click **Submit to App Review**

Review typically takes 24–48 hours for new apps.

---

## Quick Reference: All Commands

```bash
# One-time setup
./scripts/appstore/setup-signing.sh

# Version bump
./scripts/appstore/bump-version.sh 1.0

# Regenerate project
cd app && tuist install && tuist generate --no-open && cd ..

# Run tests
just test

# Generate screenshots
open scripts/appstore/screenshots.html
./scripts/appstore/capture-screenshots.sh

# Archive and upload
./scripts/appstore/archive-and-upload.sh --dry-run   # test first
./scripts/appstore/archive-and-upload.sh              # upload for real

# Push metadata (optional, needs API key)
./scripts/appstore/create-app-store-listing.sh
```
