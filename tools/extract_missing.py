#!/usr/bin/env python3
"""List UI strings in ./src that the dictionary does not translate yet.

Writes zh_new.txt (one candidate per line, most frequent first) and prints a
summary.  Work through the list, add the ones that are user-visible to
zh_extras.json, rerun build_dict.py — no rebuild needed.
"""
import collections
import json
import pathlib
import re

BASE = pathlib.Path(__file__).resolve().parent.parent
SOURCE = BASE / "src"
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')


def decode(text: str) -> str:
    out, i = [], 0
    escapes = {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}
    while i < len(text):
        char = text[i]
        if char == "\\" and i + 1 < len(text):
            nxt = text[i + 1]
            if nxt == "u" and i + 2 < len(text) and text[i + 2] == "{":
                end = text.find("}", i + 3)
                if end > 0:
                    try:
                        out.append(chr(int(text[i + 3:end], 16)))
                        i = end + 1
                        continue
                    except ValueError:
                        pass
            if nxt in escapes:
                out.append(escapes[nxt])
                i += 2
                continue
        out.append(char)
        i += 1
    return "".join(out)


def looks_ui(text: str) -> bool:
    if len(text) < 2 or len(text) > 160 or "\n" in text:
        return False
    if not re.search(r"[A-Za-z]{3}", text):
        return False
    if re.fullmatch(r"[a-z0-9_\-. /:]+", text):
        return False
    if re.fullmatch(r"[A-Z][A-Z0-9_]*", text):
        return False
    if re.search(r"https?://|\.rs\b", text):
        return False
    if re.search(r"\b(SELECT|INSERT|UPDATE|DELETE|CREATE|PRAGMA)\b", text):
        return False
    if text.count(" ") == 0 and len(text) < 12:
        return False
    return True


def main() -> None:
    known = set()
    for line in (BASE / "zh.tsv").read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#") and "\t" in line:
            known.add(line.split("\t", 1)[0])

    counts = collections.Counter()
    for sub in ("src", "crates"):
        for path in (SOURCE / sub).rglob("*.rs"):
            if path.name == "tests.rs":
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            cut = text.find("#[cfg(test)]")
            if cut > 0:
                text = text[:cut]
            # Rust line continuations join without whitespace.
            text = re.sub(r"\\\n[ \t]*", "", text)
            for match in LITERAL.finditer(text):
                candidate = decode(match.group(1))
                if looks_ui(candidate) and candidate not in known:
                    counts[candidate] += 1

    ordered = sorted(counts, key=lambda s: (-counts[s], s))
    (BASE / "zh_new.txt").write_text("\n".join(ordered) + "\n", encoding="utf-8")
    print(f"{len(ordered)} strings without a translation -> zh_new.txt")


if __name__ == "__main__":
    main()
