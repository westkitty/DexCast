#!/bin/zsh
# DexCast Build Automation Script
set -euo pipefail

ROOT="/Users/andrew/DexCast"
SRC="$ROOT/src/DexCast.swift"
APP="$ROOT/DexCast.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"
DESKTOP_APP="/Users/andrew/Desktop/DexCast.app"

echo "=== Building DexCast macOS App ==="

# 1. Clean previous build if any
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

# 2. Compile SwiftUI App
echo "Compiling Swift source..."
xcrun swiftc -parse-as-library "$SRC" -o "$MACOS/DexCast" -framework SwiftUI -framework AppKit

# 3. Copy Asset resources
echo "Copying asset resources..."
# Copy custom Dexter states if they exist
if [ -d "$ROOT/assets" ]; then
  find "$ROOT/assets" -name "*.png" -exec cp {} "$RES/" \;
  if [ -f "$ROOT/assets/AppIcon.icns" ]; then
    cp "$ROOT/assets/AppIcon.icns" "$RES/AppIcon.icns"
  fi
fi

# 4. Generate Info.plist
echo "Generating Info.plist..."
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>DexCast</string>
  <key>CFBundleDisplayName</key>
  <string>DexCast</string>
  <key>CFBundleIdentifier</key>
  <string>local.andrew.dexcast</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleExecutable</key>
  <string>DexCast</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

# 5. Apply Permissions
chmod +x "$MACOS/DexCast"
if [ -f "$ROOT/bin/dexcast-action.zsh" ]; then
  chmod +x "$ROOT/bin/dexcast-action.zsh"
fi

# 6. Apply Codesign (ad-hoc)
echo "Signing application bundle..."
codesign --force --deep --sign - "$APP"

# 7. Copy to Desktop for ease of access
echo "Deploying to Desktop..."
rm -rf "$DESKTOP_APP"
cp -R "$APP" "$DESKTOP_APP"

echo "=== Build Completed Successfully! ==="
echo "App located at: $APP"
echo "Desktop copy at: $DESKTOP_APP"
