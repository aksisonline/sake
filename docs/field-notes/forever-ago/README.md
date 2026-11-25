# Forever Ago on sake: field notes

What it took to run *Forever Ago* (a Unity title built on Microsoft's GDK) on sake 0.2.1:
what broke, why, what was changed, what was proven and what was not. Written 2026-11-26 from
one session on one Mac (Apple M4 Pro, macOS 27.2.1). Steps to reproduce everything are in
[INSTRUCTIONS.md](INSTRUCTIONS.md).

These notes are a record, not a claim that sake supports the game. Nothing here is verified
on a second machine.

## Where each change lives

| Change | Where | State |
|---|---|---|
| `XPackage` answers the user's locale, so the game gets past its first screen | PR [typester/sake#27](https://github.com/typester/sake/pull/27), branch `fix/xpackage-user-locale` | Open. Played about two to three hours with it. |
| A docs note that a video can have sound and no picture | the same PR | Open. |
| `XGameSave` kept as files in the bottle, so progress is saved | PR [typester/sake#28](https://github.com/typester/sake/pull/28), branch `feat/xgamesave` | Draft, stacked on #27. Saved and reloaded in the game. |
| Video: Wine rebuilt with GStreamer | **Nowhere in sake's code.** Scripts in [tools/](tools/) and the steps in INSTRUCTIONS.md | Local only. Decodes the game's clip in a test program. **Not seen working inside the game.** |
| These notes | branch `docs/forever-ago-field-notes` in the fork | Not a pull request. |

## Timeline and findings

### 1. Setup

sake 0.2.1 from the Homebrew cask. The first `brew install` stopped half way over a leftover
app in `/Applications`; `brew reinstall --cask --force typester/sake/sake` finished it. The app
is ad-hoc signed, so Gatekeeper's first-launch prompt has to be allowed by hand in System
Settings > Privacy & Security. The wizard builds Wine from CrossOver's sources and needs
Apple's Game Porting Toolkit image for D3DMetal, which sake guides in and never ships.

The game was installed into the `default` bottle (`C:\Forever Ago`) and added as a title.

### 2. The game hung before its menu

**Symptom.** The process ran at about 6% CPU for minutes. Unity, DXVK and Metal had all
initialised and the log stopped after the Vulkan instance was created.

**Cause, from the game's own log.** `Player.log` held an unhandled exception from the game's
start-up code:

```
GameCoreApiException: Could not retrieve the user locale
Underlying Return Code: -2147467262 (0x80004002)
  at GameState.GetGameSupportedLanguageCode ()
  at GameInit.Awake ()
```

`%TEMP%\xgameruntime.log` in the bottle showed the matching refusal:

```
QueryApiImpl refused class af406016-e850-4aa8-a88d-2f3dcb9dac7e iid e2a4734b-2f4a-456d-aa8f-d065e04fb209
```

That class is `XPackage`, which sake's `xgameruntime.dll` did not have, so
`XPackageGetUserLocale` returned `E_NOINTERFACE` (0x80004002) and the title's init threw.

**How the interface was found.** WineGDK has no `XPackage`. The title ships
`ForeverAgo_Data/Plugins/x86_64/XGameRuntime.Thunks.dll`, and each `XPackage*` thunk loads the
class and interface from `.rdata` and calls one slot of the object's vtable at a fixed offset.
`objdump -d` on that DLL gave:

- class and interface IDs above, shared by every `XPackage*` thunk;
- slot = offset / 8, from 3 to 40 (38 slots); `GetUserLocale` at offset `0x58` (slot 11) with
  `(self, size, buffer)`; `IsPackagedProcess` at `0x20` (slot 4), returning a byte.

**The fix** (PR #27). An `XPackage` object with slot 11 returning the user's locale name
(`GetUserDefaultLocaleName`, falling back to `en-US`) and slot 4 returning false. Every other
slot logs and returns `E_NOTIMPL`.

**Result.** The game reached its menu and was played for about two to three hours. The game's
log spans 00:21 to 02:25 on 2026-11-25; the player remembers about three.

### 3. What was wrong during that session

Two things the player noticed, and one they did not.

**a. No video on an in-game TV (sound only).** `Player.log`:

```
WindowsVideoMedia error 0xc00d36c4 while reading C:\Forever Ago\ForeverAgo_Data\sharedassets8.resource
Error details: Unsupported bytestream type.
```

`0xc00d36c4` is Media Foundation refusing the container. sake builds Wine with
`--without-gstreamer` (`Sources/SakeKit/WineBuilder.swift`), and Wine's Media Foundation hands
MP4 parsing and H.264 decoding to GStreamer, so nothing can open an MP4. Audio is FMOD, which
is why the sound played. The game's three videos are MP4s with H.264 video (one with AAC audio),
stored whole in `sharedassets6/8/10.resource`:

| File | Content | Video | Size |
|---|---|---|---|
| `sharedassets8.resource` | the TV news broadcast, with audio | 596x336, 12 fps, 136 s | 78 MB |
| `sharedassets6.resource` | a short animation | 640x480, 12 fps, 148 s | 3.5 MB |
| `sharedassets10.resource` | a cartoon car scene | 1920x1080, 30 fps, 49 s | 30 MB |

**b. A menu "down arrow" that always seemed pressed**, with keyboard and mouse and with a
DualSense. **Not diagnosed.** The game logged one controller (`Joystick connected ("Wireless
Controller")`) and nothing about input state. The guess, not evidence, is a phantom device
merged by the game's input layer. The first test to run: disconnect the DualSense completely
and relaunch.

**c. No progress had been saved.** Neither the bottle, the game folder, the registry nor the
external drive held anything the session wrote, apart from a 672-byte `GameOptions.sav` and a
`savedgame_lastSlotNum = 1` registry pointer. See the next section.

### 4. Saves: the game saves through XGameSave

The game's own assemblies carry the connected-storage API (`BitCode.Platform.GDK.dll` has
`XGameSaveApi`, `XGameSaveContainer`, and so on, wrapping `Unity.Microsoft.GDK.dll`). Every
launch, `xgameruntime.log` showed:

```
QueryApiImpl #1 refused class 704c3f58-e629-4cc2-b197-30511b996fe2 iid 1bfff3af-f14a-40a3-8e35-9ada906593f9
```

So the game played fine and its saves went nowhere. The player's two to three hours of
progress were not recoverable: no file, no registry value, no recording.

**What the thunks gave.** `XGameSave*` thunks all use the class and interface above; slots
3 to 32 in this order: `InitializeProvider`, `InitializeProviderAsync`,
`InitializeProviderResult`, `CloseProvider`, `GetRemainingQuota` (+Async, +Result),
`DeleteContainer` (+Async, +Result), `GetContainerInfo`, `EnumerateContainerInfo`,
`EnumerateContainerInfoByName`, `CreateContainer`, `CloseContainer`, `EnumerateBlobInfo`,
`EnumerateBlobInfoByName`, `ReadBlobData` (+Async, +Result), `CreateUpdate`, `CloseUpdate`,
`SubmitBlobWrite`, `SubmitBlobDelete`, `SubmitUpdate` (+Async, +Result), then the three
`XGameSaveFiles` calls.

**What Microsoft's public reference gave** (learn.microsoft.com, read 2026-11-26): every
signature; the layouts of `XGameSaveContainerInfo` (48 bytes), `XGameSaveBlobInfo` and
`XGameSaveBlob` (24 bytes); the `E_GS_*` values (`0x80830001`..`0x8083000F`); the 16 MB update
limit; and that an enumeration callback returns false to stop. Two error values first
remembered from memory were wrong, which is why they were looked up.

Search results for other projects' copies of Microsoft's headers were deliberately not used.

**The fix** (PR #28). Containers and blobs are plain files under the title's folder in the
bottle: `AppData/Local/Sake/<title ID>/GameSave/<container>/<blob>`. Names are percent-encoded
into file names, so nothing leaves the folder, and none starts with a dot, which leaves
`.name` and `.tmp-` files to the runtime. An update is written to temporary files and renamed
over the blobs only when all of them were written. No sync, a fixed 256 MiB quota, `XGameSaveFiles`
left unanswered.

**Proof, in three steps.**

1. A small Windows program ([tools/savetest.c](tools/savetest.c)) called slots 3 to 27 the way
   the thunks do: wrote two blobs, listed them, read them back from a separate process, got
   `0x80830008` for a missing blob, deleted the container. All as expected.
2. In the game: no more refusals, eight updates in the runtime log, and files on disk
   (`save/save_1.sav`, `save/PlayerProfile.sav`, `save/PlayerPhotoManifest.sav`).
3. The player quit completely, relaunched, and the progress was there.

That also covers the async calls the game uses, which the test program did not.

### 5. Video: a local fix that decodes in a test and is not yet seen in the game

sake's own build has no GStreamer, so the fix is to give Wine one. A source build of GStreamer
under Rosetta is hours; GStreamer publishes universal (x86_64 + arm64) macOS packages, so those
were used instead.

1. GStreamer 1.28.9 `gstreamer-1.0` and `gstreamer-1.0-devel` universal `.pkg` files from
   gstreamer.freedesktop.org, **unsigned** (`pkgutil --check-signature` says so). They were
   unpacked with `pkgutil --expand-full` and the payloads merged into one tree. They were never
   run as installers and nothing went into `/Library`. Their libraries use `@rpath` and their
   pkg-config files are relative to themselves, so the tree works from where it is. It carries
   514 plugins, including `isomp4`, `applemedia` (VideoToolbox), `libav` and `vpx`.
2. Wine was built again from the same patched source sake uses, in a separate build folder and
   with the same flags except `--with-gstreamer`, installed into a staging prefix. The build
   output was `winegstreamer.so` and two `winegstreamer.dll` (x86_64 and i386); it links
   GStreamer by an rpath into the unpacked tree.
3. Those three files were added to the engine (it had no `winegstreamer` at all) and
   `wineboot -u` installed and registered the module in the bottle.
4. The title got three environment variables so Wine finds the plugins (sake's titles carry
   their own environment): `GST_PLUGIN_SYSTEM_PATH_1_0`, `GST_PLUGIN_SCANNER`,
   `GST_REGISTRY_1_0`.

**What was shown.** A test program ([tools/mftest.c](tools/mftest.c)) opened the TV broadcast
(`sharedassets8.resource`, which is a whole MP4) through Media Foundation's source reader in
the bottle and decoded 30 frames, with the right timestamps and an AAC audio stream. Before the
change the same file did not open.

**What was not shown.**

- That it plays inside the game. The player was already past the TV scene and had no other
  video to reach, so the in-game result is unknown.
- The test asked for RGB32 and Wine answered `0xC00D5212`; frames came back as NV12 (the
  decoder's format). Whether Unity asks for something Wine can give is unknown.
- GStreamer printed `gst_video_info_from_caps: assertion 'gst_caps_is_fixed (caps)' failed`.
  Its meaning is unknown.
- VP9: `libvpx` loads, but no clip here needs it (`ffprobe` says all three are H.264), so it was
  not exercised.

## Risks and things that will bite

- **sake updates replace `xgameruntime.dll`.** sake puts its own copy in the engine and the
  bottle, replacing a bottle copy that carries its marker string. A sake update or a rerun of
  the GDK step goes back to the version without these fixes until the PRs are merged.
- **The video setup depends on a folder outside sake.** The new `winegstreamer.so` loads
  GStreamer from the unpacked tree by absolute rpath. Move or delete that tree and every
  title that plays video breaks; so would a Wine rebuild that did not carry the same flags.
- **The GStreamer packages are unsigned.** The hashes of the files used are in
  INSTRUCTIONS.md; a download of a different build has not been checked.
- **Saves are inside the bottle.** Deleting the bottle or uninstalling sake deletes them.
- **XGameSave limits.** No sync (`needsSync` is always false), no `XGameSaveFiles`, and the
  behaviour of a title that returns false from an enumeration callback was not tried.
- **The slot layouts were read from one title.** Another title's thunks could ask for an
  interface version this table does not have; the runtime refuses and logs that.

## Not done

- The stuck down arrow (section 3b).
- Video inside the game (section 5).
- Turning the video setup into sake's own build: a pinned GStreamer fetch, bundling the
  libraries so the engine stays movable, `--with-gstreamer`, and the soname pinning the rest of
  the engine has. That is a design change to `BuildRecipe.swift` and `WineBuilder.swift` and
  was not attempted.

## Unrelated to sake, left out

The same session cleared disk space on the machine (simulators, other apps' data, old
CrossOver bottles). It is personal housekeeping, not part of getting this game to run, and is
not recorded here.
