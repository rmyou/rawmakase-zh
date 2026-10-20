#!/usr/bin/env python3
"""Insert the Chinese text layer into a copy of the epaint crate.

Idempotent: running it twice changes nothing.  Usage:
    python3 tools/patch_epaint.py <epaint-dir> <zh.rs>

It adds `pub mod zh;` to lib.rs and hooks `Fonts::layout_job`.  If the crate no
longer has a `layout_job` whose signature matches, it fails loudly instead of
producing a build that silently ignores the dictionary.
"""
import pathlib
import re
import shutil
import sys

HOOK = "let job = crate::zh::translate_job(job);"
MOD = "pub mod zh;"


def main() -> int:
    epaint = pathlib.Path(sys.argv[1])
    zh = pathlib.Path(sys.argv[2])

    lib = epaint / "src" / "lib.rs"
    fonts = epaint / "src" / "text" / "fonts.rs"
    for path in (lib, fonts):
        if not path.is_file():
            print(f"error: {path} not found; the crate layout changed", file=sys.stderr)
            return 1

    shutil.copyfile(zh, epaint / "src" / "zh.rs")

    lib_text = lib.read_text(encoding="utf-8")
    if MOD not in lib_text:
        if "mod viewport;" in lib_text:
            lib_text = lib_text.replace("mod viewport;", "mod viewport;\npub mod zh;", 1)
        else:
            lib_text = lib_text.replace("pub mod text;", "pub mod text;\npub mod zh;", 1)
        lib.write_text(lib_text, encoding="utf-8")
        print(f"patched {lib}")
    else:
        print(f"{lib} already carries the module")

    fonts_text = fonts.read_text(encoding="utf-8")
    if HOOK in fonts_text:
        print(f"{fonts} already calls the dictionary")
        return 0

    # `pub fn layout_job(&mut self, job: LayoutJob) -> Arc<Galley> {`
    pattern = re.compile(r"(pub fn layout_job\(\s*&mut self,\s*job: LayoutJob,?\s*\)\s*->\s*Arc<Galley>\s*\{\n)")
    if not pattern.search(fonts_text):
        print(
            "error: no `layout_job(&mut self, job: LayoutJob) -> Arc<Galley>` in "
            f"{fonts}; the text API changed, adapt zh.rs by hand",
            file=sys.stderr,
        )
        return 1
    fonts_text = pattern.sub(r"\1    " + HOOK + "\n", fonts_text, count=1)
    fonts.write_text(fonts_text, encoding="utf-8")
    print(f"patched {fonts}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
