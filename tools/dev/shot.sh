#!/bin/sh
# Launch a rawmakase build on the spare workspace 9 and grab a screenshot.
#   shot.sh <binary> <png> [extra env assignments...]
set -eu
BIN=$1; OUT=$2; shift 2
export XDG_RUNTIME_DIR=/run/user/1000
export HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr | head -1)
export WAYLAND_DISPLAY=wayland-1
export DISPLAY=:0

hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "9" }))' >/dev/null
"$@" "$BIN" >/tmp/rawmakase-zh.log 2>&1 &
PID=$!
sleep 9
hyprctl eval 'hl.dispatch(hl.dsp.focus({ workspace = "9" }))' >/dev/null
grim "$OUT"
echo "pid=$PID"
hyprctl clients -j | python3 -c 'import json,sys
for c in json.load(sys.stdin):
    if "rawmakase" in (c.get("class","")+c.get("title","")).lower():
        print(c["class"], c["title"], c["at"], c["size"], c["workspace"]["id"])'
