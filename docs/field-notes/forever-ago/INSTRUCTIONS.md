# Instructions

How to repeat what [README.md](README.md) describes: the two runtime fixes (locale and saves),
then the video setup. Every script is in [tools/](tools/). They are transcribed from commands
that were run by hand on one Mac; `build-xgameruntime.sh`, `build-wine-gstreamer.sh` and the
title script were run as written, and the others only syntax-checked, so read each before
running it.

Everything below assumes sake 0.2.1, an engine and a `default` bottle that setup already
built, the game installed in the bottle, and no sake or game process running.

## 0. Before anything: a backup

Most of this replaces files inside `~/Library/Sake`. The scripts back up what they overwrite,
but a copy of the whole thing is the only real undo:

```sh
ditto ~/Library/Sake ~/Sake-backup        # the engine and bottles; check the free space first
```

Saves live in the bottle at
`~/Library/Sake/bottles/default/drive_c/users/crossover/AppData/Local/Sake/<title ID>/GameSave`
once the save fix is in. Deleting the bottle deletes them.

## 1. The locale and save fixes

These are PR #27 (`XPackage`) and PR #28 (`XGameSave`, stacked on it). Check out the branch
with both and build the DLL:

```sh
git clone https://github.com/aksisonline/sake.git && cd sake
git checkout feat/xgamesave
docs/field-notes/forever-ago/tools/build-xgameruntime.sh
```

The script checks the cached libHttpClient tarball against the hash in
`xgameruntime/README.md` before it builds, so run sake's *Sources* step first if the tarball
is missing. It needs the cached llvm-mingw toolchain from the same step.

Quit sake and the game, then:

```sh
docs/field-notes/forever-ago/tools/install-xgameruntime.sh        # default bottle
```

It copies the DLL into the engine (`~/Library/Sake/engine/lib/xgameruntime/`) and the
bottle's `system32`, keeping the old engine copy in `~/Library/Sake/backup-xgameruntime/`.

**Check it took.** Launch the game from sake, play a little, quit. Then:

```sh
LOG=~/Library/Sake/bottles/default/drive_c/users/crossover/AppData/Local/Temp/xgameruntime.log
grep -c refused "$LOG"                  # should be 0 for XPackage and XGameSave
grep 'game save:' "$LOG" | tail -3      # one line per save the game made
find ~/Library/Sake/bottles/default/drive_c/users/crossover/AppData/Local/Sake -path '*GameSave*' -type f
```

The log is appended to by every launch. Truncating it first (`: > "$LOG"`) makes the counts
mean "since then".

**The real test** is the one that proves a save: reach a point the game saves at, quit
completely, relaunch, and look for the progress.

**Undo.** Copy `engine-<stamp>.dll` from `backup-xgameruntime/` back over the engine copy and
the bottle's `system32\xgameruntime.dll`.

### A test that does not need the game

[tools/savetest.c](tools/savetest.c) calls the `XGameSave` slots directly the way the title's
thunks do. It needs a `MicrosoftGame.config` next to it (it takes the title ID from there):

```sh
TC=$(ls -d ~/Library/Caches/Sake/toolchain/llvm-mingw-*/bin | head -1)
B=~/Library/Sake/bottles/default
mkdir -p "$B/drive_c/savetest"
PATH="$TC:$PATH" x86_64-w64-mingw32-clang -O1 -o "$B/drive_c/savetest/savetest.exe" docs/field-notes/forever-ago/tools/savetest.c
cp "$B/drive_c/<game folder>/MicrosoftGame.Config" "$B/drive_c/savetest/MicrosoftGame.config"

export WINEPREFIX=$B WINEDLLOVERRIDES="mscoree,mshtml=d" WINEDEBUG=-all WINE_SIMULATE_WRITECOPY=1
for mode in write read delete; do ~/Library/Sake/engine/bin/wine 'C:\savetest\savetest.exe' $mode; done
rm -rf "$B/drive_c/savetest"
```

`write` then `read` (a separate process) should print the same two blobs; `delete` removes the
container so test data does not sit next to a real save. Every HRESULT should be `00000000`
except the line that says it expects `80830008`.

## 2. Video

Nothing here is in sake's own build. It leaves sake's engine with extra files and a bottle
with one more registered module, and it depends on a folder you keep.

### 2a. GStreamer, unpacked and not installed

```sh
GST_ROOT=~/gst-root docs/field-notes/forever-ago/tools/prepare-gstreamer.sh
```

It downloads GStreamer 1.28.9's universal macOS packages (about 160 MB and 810 MB), refuses to
go on unless their SHA-256 is the one this was done with, and unpacks them with
`pkgutil --expand-full` into one tree of about 4 GB. **The packages are unsigned.** The script
never runs them as installers. If a newer release is wanted, the hashes have to be updated by
whoever has checked that package.

| File | SHA-256 |
|---|---|
| `gstreamer-1.0-1.28.9-universal.pkg` | `05d27c8e9b4374bbcf1788cf1604bb4b1a4bdcbdc13bc37b67d3a225c8aa86a6` |
| `gstreamer-1.0-devel-1.28.9-universal.pkg` | `54e27ccc9af096f7f12cff32b6111b7f1b867d968cb8888e80719ad46a97c777` |

Keep `GST_ROOT` where it is afterwards: Wine will load GStreamer from there by absolute path.

### 2b. Wine built with GStreamer, in a staging prefix

```sh
GST_ROOT=~/gst-root WORK=~/wine-gst docs/field-notes/forever-ago/tools/build-wine-gstreamer.sh
```

It uses sake's own unpacked, patched Wine source and the engine's libraries, with
`WineBuilder.configureArguments` unchanged but for `--with-gstreamer`, and installs into
`~/wine-gst/stage`, not into the engine. It stops if configure did not find GStreamer. The
last line lists the three files it made.

### 2c. Install the module and register it

Quit sake and the game.

```sh
WORK=~/wine-gst docs/field-notes/forever-ago/tools/install-winegstreamer.sh      # default bottle
```

It backs up the bottle's three `.reg` files to `~/Library/Sake/backup-gst/`, adds the three files
to the engine (the engine has no `winegstreamer` before this), and runs `wineboot -u` with
sake's own environment so the module lands in `system32` and `syswow64` and is registered. It
prints the two file listings and how many registry lines now name the module; that count was 0
before and 36 after.

### 2d. Tell the title where the plugins are

```sh
docs/field-notes/forever-ago/tools/set-title-gstreamer-env.py foreverago default ~/gst-root
```

This adds `GST_PLUGIN_SYSTEM_PATH_1_0`, `GST_PLUGIN_SCANNER` and `GST_REGISTRY_1_0` to that
title's environment in `sake-titles.json`. The registry file is built on first use; the first
run scans about 500 plugins under Rosetta and is slow. Pre-building it avoids a first-launch
stall:

```sh
R=~/gst-root
GST_PLUGIN_SYSTEM_PATH_1_0=$R/lib/gstreamer-1.0 GST_PLUGIN_SCANNER=$R/libexec/gstreamer-1.0/gst-plugin-scanner \
GST_REGISTRY_1_0=~/Library/Caches/Sake/gst-registry-1.0.bin \
    arch -x86_64 $R/bin/gst-inspect-1.0 qtdemux
for e in avdec_h264 vtdec_hw atdec avdec_aac; do arch -x86_64 $R/bin/gst-inspect-1.0 $e | head -1; done
```

Each should print `Factory Details:`.

### 2e. Check video without the game

[tools/mftest.c](tools/mftest.c) opens `C:\clip10.mp4` through Media Foundation and decodes up
to 30 frames. Use any MP4 with H.264; a Unity `.resource` file that is a whole MP4 works as is.

```sh
B=~/Library/Sake/bottles/default; R=~/gst-root; TC=$(ls -d ~/Library/Caches/Sake/toolchain/llvm-mingw-*/bin | head -1)
PATH="$TC:$PATH" x86_64-w64-mingw32-clang -O1 -o "$B/drive_c/mftest.exe" docs/field-notes/forever-ago/tools/mftest.c -lmfplat -lmfreadwrite -lmfuuid -lole32 -luuid
cp /path/to/some.mp4 "$B/drive_c/clip10.mp4"

WINEPREFIX=$B WINEDLLOVERRIDES="mscoree,mshtml=d" WINEDEBUG=-all WINE_SIMULATE_WRITECOPY=1 \
GST_PLUGIN_SYSTEM_PATH_1_0=$R/lib/gstreamer-1.0 GST_PLUGIN_SCANNER=$R/libexec/gstreamer-1.0/gst-plugin-scanner \
GST_REGISTRY_1_0=~/Library/Caches/Sake/gst-registry-1.0.bin \
    ~/Library/Sake/engine/bin/wine 'C:\mftest.exe'
rm -f "$B/drive_c/mftest.exe" "$B/drive_c/clip10.mp4"
```

Success looks like `CreateSourceReader 00000000`, a native video type (`NV12`), a few
`frame N t=...ms` lines and `frames decoded: 30`. Two lines on the way are expected and were not
resolved: `set video RGB32 c00d5212` (the converter is not there; frames come back as NV12) and a
GStreamer-Video `gst_caps_is_fixed` assertion.

Without the video setup, `CreateSourceReader` fails: that is the same refusal the game logs as
`Unsupported bytestream type`.

### 2f. In the game

Forever Ago's TV scene played with this setup (the owner's report, 2026-11-28); its other two
videos were not confirmed. Some video messages stay in the logs even when the picture shows
(README section 5). If a video does not play in a game, read, in this order:

1. The game's `Player.log` (`drive_c/users/crossover/AppData/LocalLow/<studio>/<game>/Player.log`)
   for `WindowsVideoMedia error` lines. The old `0xc00d36c4` means the module is not being used.
2. `GST_DEBUG=3` in the title's environment, which makes GStreamer say what it could not
   decode.
3. Whether the title asks Media Foundation for a format Wine cannot convert to (see the RGB32
   line above).

### Undo (video)

- Delete the three `winegstreamer` files from the engine
  (`~/Library/Sake/engine/lib/wine/{x86_64-unix/winegstreamer.so,x86_64-windows/winegstreamer.dll,i386-windows/winegstreamer.dll}`).
- Put the three `.reg` files in `~/Library/Sake/backup-gst/` back in the bottle (with the game
  and sake stopped) and delete the bottle's `system32\winegstreamer.dll` and
  `syswow64\winegstreamer.dll`.
- Put `sake-titles.json` from the same folder back.

## 3. What these steps do not touch

The stuck menu down arrow (README section 3b) has no fix and no test here. The first thing to
try is disconnecting every controller before launching.

## 4. If sake updates

An update or a rerun of the GDK step puts sake's own `xgameruntime.dll` back, which loses the
locale and save fixes until the PRs are merged; run steps 1's two scripts again. A rebuild of
Wine that does not pass `--with-gstreamer` removes the video module the same way (repeat 2b to
2c).
