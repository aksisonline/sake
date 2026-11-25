#!/bin/bash
# Downloads GStreamer's universal macOS packages, checks them against the hashes of the files
# this was done with, and unpacks them into one tree WITHOUT installing them: nothing is run
# as root and nothing goes into /Library. The packages are unsigned.
#   GST_ROOT   where the merged tree goes (default ~/gst-root, about 4 GB)
set -euo pipefail

VERSION=1.28.9
GST_ROOT="${GST_ROOT:-$HOME/gst-root}"
WORK="${WORK:-$HOME/gst-pkg}"
BASE="https://gstreamer.freedesktop.org/data/pkg/osx/$VERSION"
RUNTIME="gstreamer-1.0-$VERSION-universal.pkg"
DEVEL="gstreamer-1.0-devel-$VERSION-universal.pkg"
RUNTIME_SHA=05d27c8e9b4374bbcf1788cf1604bb4b1a4bdcbdc13bc37b67d3a225c8aa86a6
DEVEL_SHA=54e27ccc9af096f7f12cff32b6111b7f1b867d968cb8888e80719ad46a97c777

mkdir -p "$WORK"; cd "$WORK"
for pair in "$RUNTIME:$RUNTIME_SHA" "$DEVEL:$DEVEL_SHA"; do
    file="${pair%%:*}"; want="${pair##*:}"
    [ -f "$file" ] || curl -fL -O "$BASE/$file"
    got="$(shasum -a 256 "$file" | cut -d' ' -f1)"
    [ "$got" = "$want" ] || { echo "$file hashes to $got, not the $want this was done with" >&2; exit 1; }
done

rm -rf expanded; mkdir expanded
pkgutil --expand-full "$RUNTIME" expanded/runtime
pkgutil --expand-full "$DEVEL" expanded/devel
mkdir -p "$GST_ROOT"
for payload in expanded/runtime/*/Payload expanded/devel/*/Payload; do
    rsync -a "$payload"/ "$GST_ROOT"/
done

export PKG_CONFIG_PATH="$GST_ROOT/lib/pkgconfig" PKG_CONFIG_LIBDIR="$GST_ROOT/lib/pkgconfig"
pkgconf --modversion gstreamer-1.0 gstreamer-video-1.0 gstreamer-audio-1.0 gstreamer-tag-1.0
echo "plugins: $(ls "$GST_ROOT/lib/gstreamer-1.0" | wc -l)   root: $GST_ROOT"
