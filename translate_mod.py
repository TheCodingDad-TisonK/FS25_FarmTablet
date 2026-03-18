#!/usr/bin/env python3
"""
FarmTablet Translation Generator
Run this from inside the mod folder (where modDesc.xml lives).
Requires: pip install deep-translator
Usage:   python translate_mod.py
"""

import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# ── Check dependency ──────────────────────────────────────────────────────────
try:
    from deep_translator import GoogleTranslator
except ImportError:
    print("Installing deep-translator...")
    os.system(f"{sys.executable} -m pip install deep-translator")
    from deep_translator import GoogleTranslator

# ── Language config ───────────────────────────────────────────────────────────
# FS25 language code  →  Google Translate code
LANGUAGES = {
    "de": "de",   # German
    "fr": "fr",   # French
    "fc": "fr",   # French Canadian  (use FR, no separate Google code)
    "es": "es",   # Spanish
    "ea": "es",   # Spanish LatAm    (use ES)
    "it": "it",   # Italian
    "pt": "pt",   # Portuguese
    "br": "pt",   # Portuguese BR    (use PT)
    "pl": "pl",   # Polish
    "cz": "cs",   # Czech            (Google uses "cs")
    "ru": "ru",   # Russian
    "uk": "uk",   # Ukrainian
    "nl": "nl",   # Dutch
    "hu": "hu",   # Hungarian
    "tr": "tr",   # Turkish
    "jp": "ja",   # Japanese         (Google uses "ja")
    "kr": "ko",   # Korean           (Google uses "ko")
    "da": "da",   # Danish
    "id": "id",   # Indonesian
    "no": "no",   # Norwegian
    "ro": "ro",   # Romanian
    "sv": "sv",   # Swedish
    "vi": "vi",   # Vietnamese
    "fi": "fi",   # Finnish
    "ct": "zh-TW",# Chinese Traditional
}

# ── Locate modDesc.xml ────────────────────────────────────────────────────────
MOD_ROOT = Path(__file__).parent
MODDESC  = MOD_ROOT / "modDesc.xml"

if not MODDESC.exists():
    print(f"ERROR: modDesc.xml not found in {MOD_ROOT}")
    sys.exit(1)

# ── Parse all English strings ─────────────────────────────────────────────────
tree = ET.parse(MODDESC)
root = tree.getroot()

ui_strings   = {}  # key -> english text  (element-child style)
help_strings = {}  # key -> english text  (inline text= attribute style)

for t in root.findall(".//l10n/text"):
    name   = t.get("name", "")
    inline = t.get("text", "")
    if inline:
        help_strings[name] = inline
    else:
        en = t.find("en")
        if en is not None and en.text:
            ui_strings[name] = en.text.strip()

print(f"Found {len(ui_strings)} UI strings and {len(help_strings)} help strings")

# ── Create translations folder ────────────────────────────────────────────────
TRANS_DIR = MOD_ROOT / "translations"
TRANS_DIR.mkdir(exist_ok=True)

# ── Write English base files first ───────────────────────────────────────────
def xml_escape(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

def write_translation_file(lang_code, ui_dict, help_dict):
    path = TRANS_DIR / f"translation_{lang_code}.xml"

    lines = ['<?xml version="1.0" encoding="utf-8" standalone="no"?>', "<l10n>", "    <texts>"]

    lines.append("")
    lines.append("        <!-- ═══════════════════════════════════════════════ -->")
    lines.append("        <!-- UI STRINGS                                      -->")
    lines.append("        <!-- ═══════════════════════════════════════════════ -->")
    lines.append("")

    for key, val in ui_dict.items():
        safe = xml_escape(val)
        lines.append(f'        <text name="{key}" text="{safe}"/>')

    lines.append("")
    lines.append("        <!-- ═══════════════════════════════════════════════ -->")
    lines.append("        <!-- HELP STRINGS                                    -->")
    lines.append("        <!-- ═══════════════════════════════════════════════ -->")
    lines.append("")

    for key, val in help_dict.items():
        safe = xml_escape(val)
        lines.append(f'        <text name="{key}" text="{safe}"/>')

    lines.append("")
    lines.append("    </texts>")
    lines.append("</l10n>")

    path.write_text("\n".join(lines), encoding="utf-8")
    print(f"  Written: {path.name}")

# ── Rename keys to use ft_ui_ and ft_help_ prefixes ──────────────────────────
# Map old key names to new prefixed names
def remap_keys(strings, prefix):
    remapped = {}
    for key, val in strings.items():
        # strip existing prefix fragments and apply clean one
        new_key = key
        if key.startswith("ft_app_"):
            new_key = f"ft_ui_app_{key[len('ft_app_'):]}"
        elif key.startswith("ft_") and not key.startswith("ft_ui_"):
            new_key = f"ft_ui_{key[len('ft_'):]}"
        elif key.startswith("helpLine_ft_"):
            new_key = f"ft_help_{key[len('helpLine_ft_'):]}"
        remapped[new_key] = val
    return remapped

ui_strings_new   = remap_keys(ui_strings,   "ft_ui_")
help_strings_new = remap_keys(help_strings, "ft_help_")

print("\nWriting English base files...")
write_translation_file("en", ui_strings_new, help_strings_new)

# ── Translate and write all other languages ───────────────────────────────────
def translate_dict(strings, google_lang):
    translated = {}
    translator = GoogleTranslator(source="en", target=google_lang)
    total = len(strings)
    for i, (key, val) in enumerate(strings.items(), 1):
        try:
            result = translator.translate(val)
            translated[key] = result if result else val
        except Exception as e:
            print(f"    WARNING: could not translate '{key}': {e}")
            translated[key] = val  # fallback to English
        if i % 10 == 0:
            print(f"    {i}/{total} strings done...")
    return translated

print(f"\nTranslating into {len(LANGUAGES)} languages...\n")

for fs_code, google_code in LANGUAGES.items():
    print(f"[{fs_code}] Translating (Google: {google_code})...")
    try:
        ui_trans   = translate_dict(ui_strings_new,   google_code)
        help_trans = translate_dict(help_strings_new, google_code)
        write_translation_file(fs_code, ui_trans, help_trans)
    except Exception as e:
        print(f"  ERROR on {fs_code}: {e}")

# ── Update modDesc.xml ────────────────────────────────────────────────────────
# 1. Replace inline l10n block with filenamePrefix reference
# 2. Rename all $l10n_ references throughout modDesc to use new key names
print("\nUpdating modDesc.xml...")

moddesc_text = MODDESC.read_text(encoding="utf-8")

# Build key rename map for $l10n_ references in modDesc
rename_map = {}
for key in ui_strings:
    new_key = key
    if key.startswith("ft_app_"):
        new_key = f"ft_ui_app_{key[len('ft_app_'):]}"
    elif key.startswith("ft_") and not key.startswith("ft_ui_"):
        new_key = f"ft_ui_{key[len('ft_'):]}"
    if new_key != key:
        rename_map[key] = new_key

for key in help_strings:
    new_key = f"ft_help_{key[len('helpLine_ft_'):]}"
    if new_key != key:
        rename_map[key] = new_key

# Apply renames to all $l10n_ references in modDesc
for old, new in rename_map.items():
    moddesc_text = moddesc_text.replace(f"$l10n_{old}", f"$l10n_{new}")

# Replace the entire <l10n> block (inline strings) with a filenamePrefix reference
import re

# Remove old inline l10n block
moddesc_text = re.sub(
    r'\s*<l10n>.*?</l10n>',
    '',
    moddesc_text,
    flags=re.DOTALL
)

# Insert filenamePrefix l10n tag before </modDesc>
moddesc_text = moddesc_text.replace(
    "</modDesc>",
    '    <l10n filenamePrefix="translations/translation" defaultLanguage="en"/>\n</modDesc>'
)

MODDESC.write_text(moddesc_text, encoding="utf-8")
print("  modDesc.xml updated.")

print("\nDone! Files written to: translations/")
print("  translation_en.xml   (base)")
for code in LANGUAGES:
    print(f"  translation_{code}.xml")
