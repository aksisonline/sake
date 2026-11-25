#!/usr/bin/env python3
"""Gives one title in a bottle the environment Wine needs to find GStreamer's plugins.

    set-title-gstreamer-env.py <title id> [bottle] [gst root]

sake keeps a title's own environment in <bottle>/sake-titles.json. Quit sake first, because it
may write that file back. The original is copied to ~/Library/Sake/backup-gst/ once.
"""
import json
import os
import shutil
import sys

title = sys.argv[1]
bottle = sys.argv[2] if len(sys.argv) > 2 else "default"
root = os.path.expanduser(sys.argv[3] if len(sys.argv) > 3 else "~/gst-root")
path = os.path.expanduser(f"~/Library/Sake/bottles/{bottle}/sake-titles.json")
backup = os.path.expanduser("~/Library/Sake/backup-gst")

os.makedirs(backup, exist_ok=True)
if not os.path.exists(f"{backup}/sake-titles.json"):
    shutil.copy(path, f"{backup}/sake-titles.json")

with open(path) as file:
    titles = json.load(file)
for entry in titles:
    if entry["id"] == title:
        entry["environment"].update({
            "GST_PLUGIN_SYSTEM_PATH_1_0": f"{root}/lib/gstreamer-1.0",
            "GST_PLUGIN_SCANNER": f"{root}/libexec/gstreamer-1.0/gst-plugin-scanner",
            "GST_REGISTRY_1_0": os.path.expanduser("~/Library/Caches/Sake/gst-registry-1.0.bin"),
        })
        break
else:
    sys.exit(f"no title with id {title!r} in {path}")
with open(path, "w") as file:
    json.dump(titles, file, indent=2)
print(json.dumps(entry, indent=1))
