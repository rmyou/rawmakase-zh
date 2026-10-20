#!/bin/sh
# Install the Chinese-localized RAWmakase build under /usr/local.
#
# Keeps the packaged (English) rawmakase-bin untouched, so this is reversible:
#   sudo rm -rf /usr/local/lib/rawmakase-zh /usr/local/share/rawmakase-zh \
#               /usr/local/bin/rawmakase-zh \
#               /usr/local/share/applications/rawmakase-zh.desktop \
#               /usr/local/share/icons/hicolor/scalable/apps/rawmakase-zh.svg
#
# The previous binary is kept as rawmakase.prev; roll back by copying it back.
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
src=$here/src/target/release/rawmakase
[ -x "$src" ] || { echo "build first: tools/rebuild-zh.sh" >&2; exit 1; }

# The tag that was built, recorded for tools/check_update.sh.
version=$(git -C "$here/src" describe --tags --exact-match 2>/dev/null || echo unknown)

install -d /usr/local/lib/rawmakase-zh /usr/local/share/rawmakase-zh /usr/local/bin \
	/usr/local/share/applications /usr/local/share/icons/hicolor/scalable/apps
if [ -x /usr/local/lib/rawmakase-zh/rawmakase ]; then
	cp -f /usr/local/lib/rawmakase-zh/rawmakase /usr/local/lib/rawmakase-zh/rawmakase.prev
fi
install -m755 "$src" /usr/local/lib/rawmakase-zh/rawmakase
install -m644 "$here/zh.tsv" /usr/local/share/rawmakase-zh/zh.tsv
printf '%s\n' "$version" >/usr/local/share/rawmakase-zh/version
install -m755 "$here/packaging/rawmakase-zh" /usr/local/bin/rawmakase-zh
install -m644 "$here/packaging/rawmakase-zh.desktop" /usr/local/share/applications/rawmakase-zh.desktop
install -m644 "$here/packaging/rawmakase-zh.svg" \
	/usr/local/share/icons/hicolor/scalable/apps/rawmakase-zh.svg

# The daily release check is a systemd user timer; install it for the user who
# ran sudo, since user units are not looked up under /usr/local.
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
	home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
	install -d "$home/.config/systemd/user"
	install -m644 "$here/packaging/rawmakase-zh-update-check.service" \
		"$here/packaging/rawmakase-zh-update-check.timer" "$home/.config/systemd/user/"
	chown -R "$SUDO_USER:" "$home/.config/systemd/user/rawmakase-zh-update-check."*
	echo "enable the release check with: systemctl --user enable --now rawmakase-zh-update-check.timer"
fi

update-desktop-database /usr/local/share/applications 2>/dev/null || true
gtk-update-icon-cache -q /usr/local/share/icons/hicolor 2>/dev/null || true
echo "installed: /usr/local/bin/rawmakase-zh ($version)"
