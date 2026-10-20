#!/usr/bin/env python3
"""Drive the rawmakase window on workspace 9: launch, keys, screenshots."""
import json
import os
import subprocess
import sys
import time

ENV = dict(
    os.environ,
    XDG_RUNTIME_DIR="/run/user/1000",
    HYPRLAND_INSTANCE_SIGNATURE=sorted(os.listdir("/run/user/1000/hypr"))[0],
    WAYLAND_DISPLAY="wayland-1",
    DISPLAY=":0",
    LANG="zh_CN.UTF-8",
)

WS = "9"


def run(*args, **kw):
    return subprocess.run(args, env=ENV, capture_output=True, text=True, **kw).stdout.strip()


def focus_ws():
    run("hyprctl", "eval", f'hl.dispatch(hl.dsp.focus({{ workspace = "{WS}" }}))')


def launch(binary, extra=(), log="/tmp/rawmakase-zh.log"):
    focus_ws()
    out = open(log, "a")
    proc = subprocess.Popen([binary, *extra], env=ENV, stdout=out, stderr=out, start_new_session=True)
    for _ in range(60):
        time.sleep(0.5)
        clients = json.loads(run("hyprctl", "clients", "-j") or "[]")
        if any("rawmakase" in (c["class"] + c["title"]).lower() for c in clients):
            return proc
    raise SystemExit("rawmakase window did not appear")


def key(*keys):
    """Send keys through wtype, e.g. key('d'), key('shift+w'), key('ctrl+comma')."""
    focus_ws()
    run("wtype", "-M", *[]) if False else None
    for combo in keys:
        run("wtype", "-k", combo) if False else run("wtype", *[f"-{m}" for m in combo.split("+")[:-1]], "-k", combo.split("+")[-1]) if "+" in combo else run("wtype", "-k", combo)
        time.sleep(0.4)


def shot(path):
    focus_ws()
    time.sleep(0.6)
    run("grim", path)
    return path


KEYS = {
    "esc": 1, "tab": 15, "space": 57, "enter": 28, "backspace": 14, "delete": 111,
    "comma": 51, "period": 52, "minus": 12, "equal": 13, "slash": 53,
    "0": 11, "1": 2, "2": 3, "3": 4, "4": 5, "5": 6, "6": 7, "7": 8, "8": 9, "9": 10,
    "a": 30, "b": 48, "c": 46, "d": 32, "e": 18, "f": 33, "g": 34, "h": 35, "i": 23,
    "j": 36, "k": 37, "l": 38, "m": 50, "n": 49, "o": 24, "p": 25, "q": 16, "r": 19,
    "s": 31, "t": 20, "u": 22, "v": 47, "w": 17, "x": 45, "y": 21, "z": 44,
    "up": 103, "down": 108, "left": 105, "right": 106,
    "home": 102, "end": 107, "pgup": 104, "pgdown": 109,
    "f1": 59, "f2": 60, "f3": 61, "f4": 62, "f6": 64, "f7": 65, "f8": 66,
    "ctrl": 29, "shift": 42, "alt": 56,
}


def press(combo, hold=0.12):
    """Press e.g. 'ctrl+shift+e' through uinput.

    Each key event goes in its own ydotoold call with a pause, so egui sees the
    modifier held across a frame boundary (a whole combo inside one frame is
    dropped).
    """
    focus_ws()
    codes = [KEYS[part] for part in combo.split("+")]
    for code in codes:
        run("ydotool", "key", f"{code}:1")
        time.sleep(hold)
    for code in reversed(codes):
        run("ydotool", "key", f"{code}:0")
        time.sleep(hold / 2)
    time.sleep(0.35)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "launch":
        proc = launch(sys.argv[2], sys.argv[3:])
        print("pid", proc.pid)
    elif cmd == "key":
        for combo in sys.argv[2:]:
            press(combo)
    elif cmd == "shot":
        print(shot(sys.argv[2]))
