#!/bin/bash
# Builds Tabby as a universal .app bundle at dist/Tabby.app
#   VERSION=1.2.0 BUILD_NUMBER=42 ./Scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Tabby"
BUNDLE_ID="com.aimen.tabby"   # never change: macOS permissions are keyed to it
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
FEED_URL="https://raw.githubusercontent.com/aimen08/tabby/main/appcast.xml"
PUBLIC_KEY="$(cat .sparkle-public-key)"

APP="dist/$APP_NAME.app"
CONTENTS="$APP/Contents"

echo "→ Building release binary (arm64 + x86_64)…"
BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)
swift build "${BUILD_FLAGS[@]}"
BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

[ -f Resources/AppIcon.icns ] || ./Scripts/make-icon.swift

echo "→ Assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"
cp "$BIN_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"
cp Resources/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"
cp -R .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework "$CONTENTS/Frameworks/"
# SwiftPM doesn't bake in an rpath for embedded frameworks.
install_name_tool -add_rpath "@executable_path/../Frameworks" "$CONTENTS/MacOS/$APP_NAME"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 Aymen Hamza</string>
    <key>SUFeedURL</key><string>$FEED_URL</string>
    <key>SUPublicEDKey</key><string>$PUBLIC_KEY</string>
    <key>SUEnableAutomaticChecks</key><true/>
    <key>SUScheduledCheckInterval</key><integer>86400</integer>
</dict>
</plist>
PLIST

# Sign with a stable certificate so Accessibility / Screen Recording permission
# survives rebuilds and updates. Put the identity name in .signing-identity.
IDENTITY="${CODE_SIGN_IDENTITY:-$( [ -f .signing-identity ] && tr -d '\n' < .signing-identity || echo - )}"
echo "→ Signing with: $IDENTITY"
codesign --force --deep --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

echo "✓ Built $APP ($VERSION, build $BUILD_NUMBER, $(du -sh "$APP" | cut -f1))"
