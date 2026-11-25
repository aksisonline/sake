#!/bin/bash
# Builds Wine from the source sake already unpacked and patched, with GStreamer on and every
# other configure flag as in WineBuilder.configureArguments. It installs into a STAGING prefix:
# sake's engine is not touched. About five minutes on ten cores.
#   GST_ROOT   the tree prepare-gstreamer.sh made (default ~/gst-root)
#   WORK       where the build and the staging prefix go (default ~/wine-gst)
set -euo pipefail

SRC="$HOME/Library/Caches/Sake/sources/wine"
ENG="$HOME/Library/Sake/engine"
TC="$(ls -d "$HOME"/Library/Caches/Sake/toolchain/llvm-mingw-*/bin | head -1)"
GST="${GST_ROOT:-$HOME/gst-root}"
W="${WORK:-$HOME/wine-gst}"

[ -d "$SRC" ] || { echo "sake has not unpacked Wine's source yet" >&2; exit 1; }
[ -f "$GST/lib/pkgconfig/gstreamer-1.0.pc" ] || { echo "run prepare-gstreamer.sh first" >&2; exit 1; }
mkdir -p "$W/build" "$W/stage"; cd "$W/build"

export PATH="$ENG/bin:$TC:$PATH"
export PKG_CONFIG_PATH="$ENG/lib/pkgconfig:$GST/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
export CPPFLAGS="-I$ENG/include"
export LDFLAGS="-L$ENG/lib -Wl,-rpath,$GST/lib"
export CFLAGS="-O2 -Wno-implicit-function-declaration -Wno-format -Wno-deprecated-declarations -Wno-incompatible-pointer-types"
export CXXFLAGS="$CFLAGS"
J="$(sysctl -n hw.activecpu)"

"$SRC/configure" --prefix="$W/stage" --host=x86_64-apple-darwin --build=x86_64-apple-darwin \
    "CC=/usr/bin/clang -arch x86_64" "CXX=/usr/bin/clang++ -arch x86_64" \
    --enable-win64 --enable-archs=i386,x86_64 --disable-tests --without-x \
    --with-freetype --with-gnutls --with-vulkan --with-gstreamer \
    --without-fontconfig --without-cups --without-sane --without-gphoto --without-pulse \
    --without-alsa --without-oss --without-dbus --without-inotify --without-udev --without-krb5 \
    --without-gssapi --without-netapi --without-pcap --without-pcsclite --without-usb \
    --without-v4l2 --without-hwloc --without-ffmpeg --without-opencl --without-capi
grep -q 'gst_pad_new in -lgstreamer-1.0... yes' config.log || { echo "configure did not find GStreamer" >&2; exit 1; }
make -j"$J" include/all
make -j"$J"
make install
find "$W/stage" -name 'winegstreamer*'
