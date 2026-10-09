#!/usr/bin/env python3
"""Bundle the Google Fonts variants Nexus uses into assets/fonts/.

google_fonts loads bundled files first (matched by `Family-Variant.ttf`), so
release builds never fetch fonts at runtime and tests render real glyphs.
Re-run after upgrading google_fonts: `python3 tool/fetch_fonts.py`.
"""

import hashlib
import pathlib
import re
import urllib.request

WEIGHTS = {100: 'Thin', 200: 'ExtraLight', 300: 'Light', 400: 'Regular', 500: 'Medium',
           600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold', 900: 'Black'}

# family (as google_fonts names it) -> [(weight, italic)]
WANTED = {
    'Inter': [(400, False), (500, False), (600, False), (700, False), (800, False)],
    'InstrumentSerif': [(400, False), (400, True)],
    'BricolageGrotesque': [(800, False)],
    'JetBrainsMono': [(400, False), (500, False), (600, False), (700, False)],
}

# OFL texts ship with the fonts and are registered in LicenseRegistry.
LICENSES = {
    'Inter': 'ofl/inter/OFL.txt',
    'InstrumentSerif': 'ofl/instrumentserif/OFL.txt',
    'BricolageGrotesque': 'ofl/bricolagegrotesque/OFL.txt',
    'JetBrainsMono': 'ofl/jetbrainsmono/OFL.txt',
}

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'fonts'


def package_dir() -> pathlib.Path:
    config = (ROOT / '.dart_tool' / 'package_config.json').read_text()
    match = re.search(r'"rootUri":\s*"file://([^"]*google_fonts-[^"]+)"', config)
    if not match:
        raise SystemExit('google_fonts not found; run flutter pub get first')
    return pathlib.Path(match.group(1))


def variants(parts: pathlib.Path, family: str) -> dict:
    for part in sorted((parts / 'lib' / 'src' / 'google_fonts_parts').glob('part_*.dart')):
        source = part.read_text()
        anchor = source.find(f"fontFamily: '{family}'")
        if anchor < 0:
            continue
        start = source.rfind('final fonts = <GoogleFontsVariant, GoogleFontsFile>{', 0, anchor)
        block = source[start:anchor]
        found = {}
        for weight, style, digest, length in re.findall(
            r'fontWeight: FontWeight\.w(\d00),\s*fontStyle: FontStyle\.(normal|italic),\s*\):\s*'
            r"GoogleFontsFile\(\s*'([0-9a-f]{64})',\s*(\d+),",
            block,
        ):
            found[(int(weight), style == 'italic')] = (digest, int(length))
        return found
    raise SystemExit(f'{family} not found in google_fonts')


def filename(family: str, weight: int, italic: bool) -> str:
    name = WEIGHTS[weight]
    if italic:
        name = 'Italic' if name == 'Regular' else f'{name}Italic'
    return f'{family}-{name}.ttf'


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    pkg = package_dir()
    for family, wanted in WANTED.items():
        files = variants(pkg, family)
        for weight, italic in wanted:
            digest, length = files[(weight, italic)]
            target = OUT / filename(family, weight, italic)
            if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == digest:
                continue
            data = urllib.request.urlopen(f'https://fonts.gstatic.com/s/a/{digest}.ttf').read()
            if len(data) != length or hashlib.sha256(data).hexdigest() != digest:
                raise SystemExit(f'checksum mismatch for {target.name}')
            target.write_bytes(data)
            print(f'fetched {target.name} ({length // 1024} KB)')
        licence = OUT / f'{family}-OFL.txt'
        if not licence.exists():
            url = f'https://raw.githubusercontent.com/google/fonts/main/{LICENSES[family]}'
            licence.write_bytes(urllib.request.urlopen(url).read())
            print(f'fetched {licence.name}')


if __name__ == '__main__':
    main()
