#!/bin/sh
# Daily check: is there a RAWmakase release newer than the localized build?
# Costs nothing but a curl; notifies the desktop when the answer is yes.
set -eu
marker="$HOME/.local/state/rawmakase-zh"
mkdir -p "$marker"
installed=$(cat /usr/local/share/rawmakase-zh/version 2>/dev/null || echo unknown)
# github.com/releases/latest redirects to the tag; the JSON API is rate limited.
latest=$(curl -fsI --max-time 20 -o /dev/null -w '%{redirect_url}' \
	https://github.com/pch/rawmakase/releases/latest 2>/dev/null | sed 's#.*/tag/##' || true)
[ -n "${latest:-}" ] || latest=$(git -C "$(dirname -- "$0")/../src" ls-remote --tags origin 2>/dev/null |
	awk '{print $2}' | sed 's#refs/tags/##' | grep -v '\^{}' | sort -V | tail -1)
[ -n "${latest:-}" ] || exit 0

if [ "$latest" = "$installed" ]; then
	rm -f "$marker/update-available"
	exit 0
fi

# Only shout once per version.
if [ "$(cat "$marker/update-available" 2>/dev/null)" = "$latest" ]; then
	exit 0
fi
printf '%s\n' "$latest" >"$marker/update-available"
notify-send -a RAWmakase -i rawmakase \
	"RAWmakase $latest 已发布（当前汉化版 $installed）" \
	"运行 /home/kream/rawmakseHANHUA/tools/rebuild-zh.sh 重建中文版，或先继续用现版本。" || true
