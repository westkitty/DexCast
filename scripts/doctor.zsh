#!/bin/zsh
# DexCast Doctor Diagnostics Script
set -euo pipefail

ROOT="/Users/andrew/DexCast"
ACTION="$ROOT/bin/dexcast-action.zsh"
LOG="$HOME/Library/Logs/dexcast.log"

echo "=== Running DexCast Doctor Diagnostics ==="

if [ ! -f "$ACTION" ]; then
  echo "Error: Action handler script is missing at $ACTION" >&2
  exit 1
fi

# Run action doctor
"$ACTION" doctor

echo "----------------------------------------------"
echo "Doctor diagnostics triggered successfully."
echo "Full reports appended to: $LOG"
echo "Opening diagnostic log file..."
echo "=============================================="
