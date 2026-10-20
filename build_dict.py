#!/usr/bin/env python3
"""Generate zh.tsv from the translation sources.

  zh_map.json     {"English": "中文"} — the bulk of the UI, keyed by the exact
                  source string, so entries survive upstream releases that move
                  code around; a string that disappears just stops matching.
  zh_extras.json  {"English": "中文"} — model labels, white-balance presets,
                  panel names, common words, anything not in the extracted list.

Writes zh.tsv (English<TAB>Chinese) plus capitalised twins, because panel headers
reach the text layer upper-cased. Placeholder counts are checked: a template must
carry the same `{...}` slots on both sides.
"""
import json
import pathlib
import re

BASE = pathlib.Path(__file__).resolve().parent
PLACEHOLDER = re.compile(r"\{[^}]*\}")


def load(name: str) -> dict[str, str]:
    return json.loads((BASE / name).read_text(encoding="utf-8"))


def check(english: str, chinese: str) -> bool:
    if len(PLACEHOLDER.findall(english)) != len(PLACEHOLDER.findall(chinese)):
        print(f"  ! placeholder count differs, skipped: {english!r} -> {chinese!r}")
        return False
    return True


def main() -> None:
    rows: dict[str, str] = {}
    for source in ("zh_map.json", "zh_extras.json"):
        for english, chinese in load(source).items():
            english = english.replace("\\n", "\n").replace("\\t", "\t")
            if not english.strip() or not chinese.strip():
                continue
            if check(english, chinese):
                rows[english] = chinese

    twins = {
        english.upper(): chinese
        for english, chinese in rows.items()
        if "{" not in english and english.upper() != english and english.upper() not in rows
    }
    rows.update(twins)

    with (BASE / "zh.tsv").open("w", encoding="utf-8") as file:
        file.write("# RAWmakase Chinese dictionary: English<TAB>Chinese.\n")
        file.write("# {placeholders} keep their order between the two sides.\n")
        for english, chinese in sorted(rows.items()):
            file.write(english.replace("\t", "\\t").replace("\n", "\\n") + "\t" + chinese + "\n")
    print(f"{len(rows)} entries ({len(twins)} capitalised twins) -> {BASE / 'zh.tsv'}")


if __name__ == "__main__":
    main()
