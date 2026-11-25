#!/bin/bash
# Puts the DLL built by build-xgameruntime.sh into sake's engine and a bottle, after backing
# up what is there. Stop the game and sake first. sake replaces these copies again when it
# updates or reruns its GDK step.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../../../.." && pwd)"
BOTTLE="${1:-default}"
ENGINE="$HOME/Library/Sake/engine/lib/xgameruntime/xgameruntime.dll"
TARGET="$HOME/Library/Sake/bottles/$BOTTLE/drive_c/windows/system32/xgameruntime.dll"
NEW="$REPO/target/xgameruntime/xgameruntime.dll"
BACKUP="$HOME/Library/Sake/backup-xgameruntime"

[ -f "$NEW" ] || { echo "build it first: build-xgameruntime.sh" >&2; exit 1; }
if pgrep -f "$HOME/Library/Sake/engine" >/dev/null; then
    echo "something from the engine is still running; stop the game and quit sake" >&2; exit 1
fi
mkdir -p "$BACKUP"
stamp="$(date +%Y%m%d-%H%M%S)"
cp "$ENGINE" "$BACKUP/engine-$stamp.dll"
cp "$NEW" "$ENGINE"
cp "$NEW" "$TARGET"
echo "installed; the previous engine copy is $BACKUP/engine-$stamp.dll"
