#!/usr/bin/env python3
"""Point the app's [patch.crates-io] at the patched epaint copy.

    python3 tools/patch_cargo.py <Cargo.toml> <relative-path-to-epaint>
"""
import pathlib
import sys

manifest = pathlib.Path(sys.argv[1])
relative = sys.argv[2]

text = manifest.read_text(encoding="utf-8")
if "[patch.crates-io]" in text:
    text = text.split("\n[patch.crates-io]", 1)[0].rstrip("\n") + "\n"

block = (
    "\n# Local Chinese (zh-CN) translation layer: a patched epaint translates every\n"
    f"# laid-out string through a dictionary (see {relative}/src/zh.rs).\n"
    "[patch.crates-io]\n"
    f'epaint = {{ path = "{relative}" }}\n'
)
manifest.write_text(text + block, encoding="utf-8")
print(f"{manifest}: epaint -> {relative}")
