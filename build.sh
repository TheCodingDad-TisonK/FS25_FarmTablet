#!/usr/bin/env bash
# FS25_FarmTablet build script
# Uses Python to create a zip with forward-slash paths (required by FS25)

MOD_NAME="FS25_FarmTablet"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
WIN_SRC_DIR="$(cygpath -w "$SRC_DIR" 2>/dev/null || echo "$SRC_DIR")"
MODS_DIR="/c/Users/tison/Documents/My Games/FarmingSimulator2025/mods"
WIN_MODS_DIR="$(cygpath -w "$MODS_DIR" 2>/dev/null || echo "$MODS_DIR")"
ZIP_NAME="${MOD_NAME}.zip"

echo "============================================"
echo "  Building ${MOD_NAME}"
echo "============================================"

py -c "
import zipfile, os, sys

src = r'${WIN_SRC_DIR}'
out = r'${WIN_SRC_DIR}/${ZIP_NAME}'

with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zf:
    for f in ['modDesc.xml', 'icon.dds']:
        path = os.path.join(src, f)
        if os.path.exists(path):
            zf.write(path, f)
    for d in ['src', 'hud']:
        dpath = os.path.join(src, d)
        if not os.path.isdir(dpath):
            continue
        for root, dirs, files in os.walk(dpath):
            for file in files:
                full = os.path.join(root, file)
                rel = os.path.relpath(full, src).replace(os.sep, '/')
                zf.write(full, rel)

print('Built: ' + out)
"

if [ $? -ne 0 ]; then
    echo "Build FAILED."
    exit 1
fi

echo "Built: ${SRC_DIR}/${ZIP_NAME}"

if [[ "$1" == "--deploy" ]]; then
    cp "${SRC_DIR}/${ZIP_NAME}" "${MODS_DIR}/${ZIP_NAME}"
    echo "Deployed to: ${MODS_DIR}"
fi

echo "Log:         ${MODS_DIR}/../log.txt"
echo "============================================"
echo "  Done."
echo "============================================"
