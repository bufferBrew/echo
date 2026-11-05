#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Echo"
BUNDLE_ID="com.kartikjain.echo"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

echo "Building release binary..."
swift build -c release

echo "Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Assets/Echo.icns "$APP_BUNDLE/Contents/Resources/Echo.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>Echo</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# A stable signing identity keeps the designated requirement constant across rebuilds,
# so macOS Accessibility/TCC grants survive. Ad-hoc signing pins the requirement to the
# binary's cdhash, which changes every build and silently revokes the grant.
SIGN_IDENTITY="${ECHO_SIGN_IDENTITY:-Echo Local Signing}"
if security find-identity -v -p codesigning 2>/dev/null | grep -qF "$SIGN_IDENTITY"; then
    echo "Signing with identity: $SIGN_IDENTITY"
    codesign --force --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
    STABLE_SIGNATURE=1
else
    echo "Ad-hoc signing (no '$SIGN_IDENTITY' identity found)..."
    codesign --force --sign - "$APP_BUNDLE"
    STABLE_SIGNATURE=0
fi

if [ "${1:-}" = "--no-install" ]; then
    echo "Built $APP_BUNDLE (installation skipped)."
    exit 0
fi

echo "Installing to /Applications..."
rm -rf "/Applications/$APP_NAME.app"
cp -R "$APP_BUNDLE" "/Applications/"

echo "Done. Launch with: open /Applications/$APP_NAME.app"
echo

if [ "$STABLE_SIGNATURE" = "1" ]; then
    echo "Signed with a stable identity - the Accessibility grant survives rebuilds."
else
    cat <<'NOTE'
NOTE: ad-hoc signature. Its designated requirement is the binary's cdhash, which
changes every build, so macOS silently revokes the Accessibility grant each time -
even though System Settings still shows Echo as enabled. Quick-paste will do
nothing until you re-grant it:

  tccutil reset Accessibility com.kartikjain.echo

then System Settings > Privacy & Security > Accessibility, add
/Applications/Echo.app, toggle on, and relaunch Echo.

To stop this recurring, create a self-signed code-signing certificate named
"Echo Local Signing" (Keychain Access > Certificate Assistant > Create a
Certificate, type "Code Signing", then set it to Always Trust). This script picks
it up automatically. Override the name with ECHO_SIGN_IDENTITY.
NOTE
fi
