#!/usr/bin/env bash
#
# capture-screenshots.sh — Export App Store screenshots from screenshots.html using Puppeteer.
#
# Prerequisites:
#   brew install node   (if not installed)
#   npm install -g puppeteer
#
# Usage:
#   ./scripts/appstore/capture-screenshots.sh
#
# Output:
#   .build/screenshots/screenshot-{1..6}-{name}.png (1290x2796 each)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HTML_FILE="$SCRIPT_DIR/screenshots.html"
OUTPUT_DIR=".build/screenshots"
SCREENSHOT_JS="$SCRIPT_DIR/.capture-screenshots.cjs"

mkdir -p "$OUTPUT_DIR"

# ─── Generate Puppeteer script ───────────────────────────────────────────────

cat > "$SCREENSHOT_JS" << 'PUPPETEER_EOF'
const puppeteer = require('puppeteer');
const path = require('path');

const WIDTH = 1290;
const HEIGHT = 2796;
const SCALE = 2; // Render at 2x for retina-quality output

const SCREENSHOTS = [
  { index: 0, name: 'welcome' },
  { index: 1, name: 'home' },
  { index: 2, name: 'ai-verification' },
  { index: 3, name: 'success' },
  { index: 4, name: 'weekly-summary' },
  { index: 5, name: 'settings' },
];

(async () => {
  const htmlPath = process.argv[2];
  const outputDir = process.argv[3];

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
  });

  const page = await browser.newPage();
  await page.setViewport({ width: WIDTH, height: HEIGHT, deviceScaleFactor: SCALE });
  await page.goto(`file://${htmlPath}`, { waitUntil: 'networkidle0' });

  for (const { index, name } of SCREENSHOTS) {
    // Each .marketing-card contains: headline, subline, phone frame, label
    // We want to capture just the phone frame at 1290x2796 with the marketing text as overlay
    const cards = await page.$$('.marketing-card');
    if (!cards[index]) {
      console.error(`Card ${index} not found, skipping ${name}`);
      continue;
    }

    const outputPath = path.join(outputDir, `screenshot-${index + 1}-${name}.png`);

    // Take a screenshot of the entire card
    await cards[index].screenshot({
      path: outputPath,
      type: 'png',
    });

    console.log(`Saved: ${outputPath}`);
  }

  await browser.close();
  console.log('\nDone! Screenshots saved to:', outputDir);
  console.log('Note: Resize to exactly 1290x2796 if needed for App Store upload.');
})();
PUPPETEER_EOF

# ─── Run Puppeteer ───────────────────────────────────────────────────────────

echo "→ Capturing screenshots from $HTML_FILE"
echo "  Output: $OUTPUT_DIR"
echo ""

if command -v npx >/dev/null 2>&1; then
  npx --yes puppeteer browsers install chrome 2>/dev/null || true
  node "$SCREENSHOT_JS" "$HTML_FILE" "$OUTPUT_DIR"
else
  echo "npx not found. Install Node.js first:"
  echo "  brew install node"
  echo ""
  echo "Then run:"
  echo "  npm install -g puppeteer"
  echo "  node $SCREENSHOT_JS $HTML_FILE $OUTPUT_DIR"
  exit 1
fi

# Cleanup
rm -f "$SCREENSHOT_JS"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Screenshots saved to: $OUTPUT_DIR"
echo "  Files:"
ls -1 "$OUTPUT_DIR"/*.png 2>/dev/null || echo "  (none found)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
