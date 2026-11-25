#!/bin/bash
# Builds xgameruntime.dll from this checkout with sake's own toolchain and its pinned
# libHttpClient. The DLL lands in <repo>/target/xgameruntime/.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../../../.." && pwd)"
CACHE="$HOME/Library/Caches/Sake"
TOOLCHAIN="$(ls -d "$CACHE"/toolchain/llvm-mingw-*/bin | head -1)"
TARBALL="$CACHE/dl/libhttpclient-7ead73f6.tar.gz"
COMMIT=7ead73f6389271c2dc2cb10cdafcc587b899bd8a
SHA256=dda556ee4c7f5f925779fec25a8dfa3d7b236513638b0e516ed456817c8aac94

[ -f "$TARBALL" ] || { echo "missing $TARBALL: run sake's Sources step first" >&2; exit 1; }
[ "$(shasum -a 256 "$TARBALL" | cut -d' ' -f1)" = "$SHA256" ] || { echo "libHttpClient tarball hash differs" >&2; exit 1; }

mkdir -p "$REPO/target/lhc"
[ -d "$REPO/target/lhc/libHttpClient-$COMMIT" ] || tar xzf "$TARBALL" -C "$REPO/target/lhc"

PATH="$TOOLCHAIN:$PATH" make -C "$REPO/xgameruntime" \
    LIBHTTPCLIENT="$REPO/target/lhc/libHttpClient-$COMMIT" \
    OUT="$REPO/target/xgameruntime" -j"$(sysctl -n hw.activecpu)"
ls -la "$REPO/target/xgameruntime/xgameruntime.dll"
