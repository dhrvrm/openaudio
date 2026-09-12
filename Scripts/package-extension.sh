#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p dist
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
files = ['manifest.json', 'worker.js', 'engine.js', 'report.js', 'media.js', 'device-catalog.js', 'offscreen.html', 'offscreen.js', 'options.html', 'options.js', 'popup.css']
with ZipFile('dist/OpenAudio-Tabs.zip', 'w', ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(Path('BrowserExtension') / name, name)
print('dist/OpenAudio-Tabs.zip — unpack for local browser loading; also suitable for store submission')
PY
