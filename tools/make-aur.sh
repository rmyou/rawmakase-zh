#!/bin/sh
# Assemble the AUR package directory: aur/ holds exactly what the AUR git repo
# must contain — PKGBUILD plus the auxiliary files it lists in `source`.
#
#   tools/make-aur.sh            # sync aur/ from the canonical files
#   tools/make-aur.sh --srcinfo  # also regenerate .SRCINFO (needs makepkg)
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
aur=$root/aur

cp "$root/patches/zh.rs" "$aur/zh.rs"
cp "$root/zh.tsv" "$aur/zh.tsv"
cp "$root/tools/patch_epaint.py" "$aur/patch_epaint.py"
cp "$root/tools/patch_cargo.py" "$aur/patch_cargo.py"
cp "$root/packaging/rawmakase-zh" "$aur/rawmakase-zh"
cp "$root/packaging/rawmakase-zh.desktop" "$aur/rawmakase-zh.desktop"
cp "$root/packaging/rawmakase-zh.svg" "$aur/rawmakase-zh.svg"
cp "$root/packaging/rawmakase-zh-update-check.service" "$aur/"
cp "$root/packaging/rawmakase-zh-update-check.timer" "$aur/"

python3 "$root/tools/update-sums.py"
echo "aur/ synced"

if [ "${1:-}" = --srcinfo ]; then
	(cd "$aur" && makepkg --printsrcinfo >.SRCINFO)
	echo "aur/.SRCINFO regenerated"
fi
