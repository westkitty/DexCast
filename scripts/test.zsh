#!/bin/zsh
# DexCast Test Suite
set -euo pipefail

ROOT="/Users/andrew/DexCast"
BIN_ACTION="$ROOT/bin/dexcast-action.zsh"
BUILD_SCRIPT="$ROOT/scripts/build.zsh"
DOCTOR_SCRIPT="$ROOT/scripts/doctor.zsh"
SRC_SWIFT="$ROOT/src/DexCast.swift"
APP="$ROOT/DexCast.app"

echo "=== Running DexCast Tests & Sanity Checks ==="
ERRORS=0

# Helper to check syntax of zsh script
check_zsh_syntax() {
  local filepath="$1"
  if [ -f "$filepath" ]; then
    if zsh -n "$filepath"; then
      echo "✅ Zsh Syntax Pass: $(basename "$filepath")"
    else
      echo "❌ Zsh Syntax Fail: $(basename "$filepath")"
      ERRORS=$((ERRORS + 1))
    fi
  else
    echo "❌ Missing script file: $(basename "$filepath")"
    ERRORS=$((ERRORS + 1))
  fi
}

# 1. Verify Zsh Syntax on all scripts
check_zsh_syntax "$BIN_ACTION"
check_zsh_syntax "$BUILD_SCRIPT"
check_zsh_syntax "$DOCTOR_SCRIPT"

# 2. Check Swift source structure
if [ -f "$SRC_SWIFT" ]; then
  if grep -q "struct ContentView:" "$SRC_SWIFT" && grep -q "@main" "$SRC_SWIFT"; then
    echo "✅ Swift Source Check: ContentView and main entry point exist"
  else
    echo "❌ Swift Source Check: Swift file lacks expected SwiftUI structures"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "❌ Missing Swift file: $SRC_SWIFT"
  ERRORS=$((ERRORS + 1))
fi

# 3. Check compiled app bundle structure (if built)
if [ -d "$APP" ]; then
  if [ -f "$APP/Contents/Info.plist" ] && [ -f "$APP/Contents/MacOS/DexCast" ]; then
    echo "✅ App Bundle Check: Executable and Info.plist exist"
  else
    echo "❌ App Bundle Check: App bundle directory is incomplete"
    ERRORS=$((ERRORS + 1))
  fi
else
  echo "⚠️ App Bundle Check: App bundle DexCast.app not built yet (Run build.zsh first)"
fi

# 4. Check Assets fallback existence
if [ -f "$ROOT/assets/AppIcon.icns" ]; then
  echo "✅ Icon Asset Check: AppIcon.icns compiled successfully"
else
  echo "⚠️ Icon Asset Check: AppIcon.icns is missing (Custom assets prep not complete or skipped)"
fi

echo "=============================================="
if [ "$ERRORS" -eq 0 ]; then
  echo "✅ ALL SANITY TESTS PASSED!"
  exit 0
else
  echo "❌ $ERRORS SANITY TESTS FAILED!"
  exit 1
fi
