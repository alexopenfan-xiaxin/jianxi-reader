"""Subset the bundled LXGW WenKai to the characters this app can show.

Why subset at all: the full TTF is 24.4 MiB and is ~98% of the app's assets,
which puts the APK at ~35 MiB for a text reader.

Why rename: the OFL text shipped in assets/fonts/OFL.txt reserves the names
'霞鹜', '霞鶩', '落霞孤鹜', '落霞孤鶩' and 'LXGW', and its additional permission
only covers web-font delivery. A subset embedded in an APK is a Modified
Version, so the internal family/postscript names must not be the reserved
ones. The glyphs and the licence terms are unchanged.

Run from the repository root:  python3 tool/subset_font.py
"""

from __future__ import annotations

import glob
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/fonts/LXGWWenKai-Regular.ttf"
TARGET = ROOT / "assets/fonts/JianxiWenKai-Regular.ttf"

NEW_FAMILY = "JianxiWenKai"
NEW_POSTSCRIPT = "JianxiWenKai-Regular"

# Extra punctuation the reader renders even though it is not in GB2312.
EXTRA_PUNCTUATION = "　、。〃々〈〉《》「」『』【】〔〕〖〗〘〙〚〛〜〝〞〟～—–…·‘’‛“”„‟•‣‰′″‹›※"
# Symbols the UI uses directly.
EXTRA_SYMBOLS = "\ufffd\u00a0\u200b\u3000"


def gb2312_characters() -> set[str]:
    """All 6763 hanzi plus the symbol rows of GB2312, decoded exactly."""
    characters: set[str] = set()
    for high in list(range(0xA1, 0xAA)) + list(range(0xB0, 0xF8)):
        for low in range(0xA1, 0xFF):
            try:
                characters.add(bytes([high, low]).decode("gb2312"))
            except UnicodeDecodeError:
                continue
    return characters


def source_text_characters() -> set[str]:
    """Every character the app itself can draw: UI strings and docs."""
    patterns = ["lib/**/*.dart", "*.md", "docs/*.md", "assets/emoji.json"]
    characters: set[str] = set()
    for pattern in patterns:
        for name in glob.glob(str(ROOT / pattern), recursive=True):
            try:
                characters |= set(Path(name).read_text(encoding="utf-8"))
            except (UnicodeDecodeError, OSError) as error:
                print(f"skip {name}: {error}", file=sys.stderr)
    return characters


def build_character_set() -> str:
    characters = gb2312_characters()
    characters |= source_text_characters()
    characters |= {chr(code) for code in range(0x20, 0x7F)}
    characters |= set(EXTRA_PUNCTUATION)
    characters |= set(EXTRA_SYMBOLS)
    characters.discard("\r")
    characters.discard("\n")
    characters.discard("\t")
    return "".join(sorted(characters))


def main() -> int:
    if not SOURCE.exists():
        print(f"missing source font: {SOURCE}", file=sys.stderr)
        return 1

    text = build_character_set()
    print(f"requesting {len(text)} characters")

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.symbol_cmap = True
    options.legacy_cmap = True
    options.glyph_names = True
    options.drop_tables += ["DSIG"]

    font = TTFont(SOURCE)
    coverage = font.getBestCmap()
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text=text)
    subsetter.subset(font)

    for record in font["name"].names:
        if record.nameID in (1, 16):
            record.string = NEW_FAMILY
        elif record.nameID == 4:
            record.string = f"{NEW_FAMILY} Regular"
        elif record.nameID == 6:
            record.string = NEW_POSTSCRIPT
        elif record.nameID == 3:
            record.string = f"{NEW_POSTSCRIPT};OFL"

    font.save(TARGET)

    kept = set(TTFont(TARGET).getBestCmap())
    missing = sorted({ord(character) for character in text} - kept)
    size = TARGET.stat().st_size
    print(f"wrote {TARGET.name}: {size:,} bytes ({size / 1024 / 1024:.1f} MiB)")
    print(f"glyphs kept: {len(kept):,} (source cmap had {len(coverage):,})")
    if missing:
        printable = ", ".join(f"U+{code:04X}" for code in missing[:20])
        print(f"not in the source font: {len(missing)} ({printable}…)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
