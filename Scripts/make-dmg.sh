#!/bin/bash
# Packs dist/Tabby.app into a drag-to-Applications dist/Tabby.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

APP="dist/Tabby.app"
DMG="dist/Tabby.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

[ -d "$APP" ] || ./Scripts/build-app.sh

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -srcfolder "$STAGING" -volname "Tabby" -fs HFS+ -format UDZO -imagekey zlib-level=9 "$DMG" >/dev/null

IDENTITY="${CODE_SIGN_IDENTITY:-$( [ -f .signing-identity ] && tr -d '\n' < .signing-identity || echo - )}"
codesign --force --sign "$IDENTITY" "$DMG"
echo "✓ Built $DMG ($(du -sh "$DMG" | cut -f1))"
