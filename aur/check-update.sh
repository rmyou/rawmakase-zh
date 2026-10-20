#!/bin/sh
# Daily check: is there a RAWmakase release newer than the localized build?
#
# Installed by the rawmakase-zh package (or packaging/install.sh) and run by
# rawmakase-zh-update-check.timer. Costs one redirect request; no API quota.
set -eu
marker="${XDG_STATE_HOME:-$HOME/.local/state}/rawmakase-zh"
mkdir -p "$marker"

installed=unknown
for path in /usr/share/rawmakase-zh/version /usr/local/share/rawmakase-zh/version; do
	[ -r "$path" ] && installed=$(cat "$path") && break
done

# github.com/releases/latest redirects to the newest tag; the JSON API answers
# 403 to unauthenticated callers often enough to not rely on it.
latest=$(curl -fsI --max-time 20 -o /dev/null -w '%{redirect_url}' \
	https://github.com/pch/rawmakase/releases/latest 2>/dev/null | sed 's#.*/tag/##' || true)
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
	"用 tools/rebuild-zh.sh 重建中文版，或继续使用当前版本。" || true
