#!/usr/bin/env python3
"""Refresh the sha256sums of the local files in aur/PKGBUILD.

The first entry is the upstream tarball (its sum only changes with pkgver and is
left alone); every later entry is a file this repository ships.
"""
import hashlib
import pathlib
import re

aur = pathlib.Path(__file__).resolve().parent.parent / "aur"
manifest = aur / "PKGBUILD"
text = manifest.read_text(encoding="utf-8")

source = re.search(r"source=\((.*?)\)\n", text, re.S).group(1)
names = re.findall(r"""['"]([^'"]+)['"]""", source)

sums_match = re.search(r"sha256sums=\((.*?)\)\n", text, re.S)
old_sums = re.findall(r"'([^']+)'", sums_match.group(1))

merged = []
for index, name in enumerate(names):
    if "::" in name:
        merged.append(old_sums[index])  # upstream tarball: keep what is there
    else:
        merged.append(hashlib.sha256((aur / name).read_bytes()).hexdigest())

body = "\n".join([f"'{merged[0]}'"] + [f"            '{value}'" for value in merged[1:]])
text = text[: sums_match.start()] + f"sha256sums=({body})\n" + text[sums_match.end():]
manifest.write_text(text, encoding="utf-8")
print(f"updated checksums for {len(names) - 1} local files in {manifest}")
