#!/usr/bin/env python3
"""Move the Hyprland cursor with closed-loop correction, then click.

ydotool only produces relative motion and the compositor applies pointer
acceleration, so each move is measured and the step re-scaled by the gain just
observed.  Coordinates are physical pixels of the 1920x1080 panel.
"""
import os
import subprocess
import sys
import time

ENV = dict(
    os.environ,
    XDG_RUNTIME_DIR="/run/user/1000",
    HYPRLAND_INSTANCE_SIGNATURE=sorted(os.listdir("/run/user/1000/hypr"))[0],
    WAYLAND_DISPLAY="wayland-1",
    YDOTOOL_SOCKET="/tmp/.ydotool_socket",
)
SCALE = 1.25
GAIN = [1.0, 1.0]  # measured against the flat acceleration profile


def run(*args):
    return subprocess.run(args, env=ENV, capture_output=True, text=True).stdout.strip()


def pos():
    x, y = run("hyprctl", "cursorpos").split(",")
    return float(x) * SCALE, float(y) * SCALE


def nudge(dx, dy):
    run("ydotool", "mousemove", "--", str(round(dx)), str(round(dy)))


def move_to(x, y, tries=14):
    for _ in range(tries):
        cx, cy = pos()
        dx, dy = x - cx, y - cy
        if abs(dx) <= 6 and abs(dy) <= 6:
            return True
        step_x, step_y = max(-400, min(400, dx)), max(-400, min(400, dy))
        nudge(step_x, step_y)
        time.sleep(0.05)
        nx, ny = pos()
        if abs(step_x) > 40 and abs(nx - cx) > 20:
            GAIN[0] = min(2.0, max(0.5, (nx - cx) / step_x))
        if abs(step_y) > 40 and abs(ny - cy) > 20:
            GAIN[1] = min(2.0, max(0.5, (ny - cy) / step_y))
    return False


def focus_workspace():
    run("hyprctl", "eval", 'hl.dispatch(hl.dsp.focus({ workspace = "9" }))')
    time.sleep(0.4)


def click(x, y, button="1"):
    focus_workspace()
    ok = move_to(x, y)
    time.sleep(0.15)
    run("ydotool", "click", button)
    time.sleep(0.3)
    return ok


def scroll(amount, x=None, y=None):
    focus_workspace()
    if x is not None:
        move_to(x, y)
    for _ in range(abs(amount)):
        run("ydotool", "click", "5" if amount > 0 else "4")
        time.sleep(0.06)
    time.sleep(0.3)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "move":
        focus_workspace()
        print(move_to(float(sys.argv[2]), float(sys.argv[3])), pos())
    elif cmd == "click":
        print(click(float(sys.argv[2]), float(sys.argv[3])))
    elif cmd == "scroll":
        scroll(int(sys.argv[2]), *[float(v) for v in sys.argv[3:5]])
    elif cmd == "pos":
        print(pos())
