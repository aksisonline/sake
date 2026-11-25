#!/bin/bash
# Adds the three winegstreamer files from the staging prefix to sake's engine and updates a
# bottle so the module is installed and registered. Backs up the bottle's registry first.
# Stop the game and quit sake first.
#   WORK   the build-wine-gstreamer.sh folder (default ~/wine-gst)
set -euo pipefail

W="${WORK:-$HOME/wine-gst}"
BOTTLE="${1:-default}"
ENGINE="$HOME/Library/Sake/engine"
PREFIX="$HOME/Library/Sake/bottles/$BOTTLE"
BACKUP="$HOME/Library/Sake/backup-gst"

for f in x86_64-unix/winegstreamer.so x86_64-windows/winegstreamer.dll i386-windows/winegstreamer.dll; do
    [ -f "$W/stage/lib/wine/$f" ] || { echo "missing $W/stage/lib/wine/$f" >&2; exit 1; }
done
if pgrep -f "$ENGINE" >/dev/null; then
    echo "something from the engine is still running; stop the game and quit sake" >&2; exit 1
fi

mkdir -p "$BACKUP"
cp -n "$PREFIX/system.reg" "$PREFIX/user.reg" "$PREFIX/userdef.reg" "$BACKUP/" || true
for f in x86_64-unix/winegstreamer.so x86_64-windows/winegstreamer.dll i386-windows/winegstreamer.dll; do
    cp "$W/stage/lib/wine/$f" "$ENGINE/lib/wine/$f"
done

# What sake's own runs set (Bottle.environment): leaving any out breaks something unrelated.
export WINEPREFIX="$PREFIX" WINEDLLOVERRIDES="mscoree,mshtml=d" WINEDEBUG=-all WINE_SIMULATE_WRITECOPY=1
timeout 240 "$ENGINE/bin/wine" wineboot -u
"$ENGINE/bin/wineserver" -w || true
ls -la "$PREFIX/drive_c/windows/system32/winegstreamer.dll" "$PREFIX/drive_c/windows/syswow64/winegstreamer.dll"
echo "registry entries naming it: $(grep -c -i winegstreamer "$PREFIX/system.reg")"
