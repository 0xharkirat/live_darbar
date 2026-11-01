#!/bin/bash
# Rebuilds the binary assets of the landing page in site/ from the app's own files.
#
#     flutter test test/screens --tags screens   # writes build/screens/*.png
#     tool/site_assets.sh
#
# Needs `pyftsubset` (pip install fonttools brotli) and `cwebp` (brew install webp).
# site/img/og.jpg is not made here. It is 1200x630, drawn once from
# assets/images/0.jpg with the title set in the same serif.
set -euo pipefail
cd "$(dirname "$0")/.."

SHOTS=build/screens
FONTS=assets/fonts
OUT=site

# Latin, and the Gurmukhi block with the signs Gurmukhi needs. The Gurmukhi
# files carry Latin too, so a /pa/ page loads those 3 files and no others.
LATIN="U+0020-007E,U+00A0,U+00A9,U+00B7,U+2013,U+2018,U+2019,U+201C,U+201D,U+2026,U+2192,U+2197"
GURMUKHI="$LATIN,U+0A00-0A7F,U+0964-0965,U+200C-200D,U+25CC"

mkdir -p "$OUT/fonts" "$OUT/img"

subset() { # font file, unicodes, output name, extra flags
  pyftsubset "$FONTS/$1" --unicodes="$2" --flavor=woff2 --no-hinting \
    --output-file="$OUT/fonts/$3.woff2" ${4:+"$4"}
}
for w in 400 700; do
  subset "Manrope-$w.ttf" "$LATIN" "manrope-$w"
  subset "NotoSansGurmukhi-$w.ttf" "$GURMUKHI" "noto-sans-gurmukhi-$w" --layout-features='*'
done
subset NotoSerif-600.ttf "$LATIN" noto-serif-600
subset NotoSerifGurmukhi-600.ttf "$GURMUKHI" noto-serif-gurmukhi-600 --layout-features='*'

shot() { # render-test name, output name
  cwebp -quiet -q 68 -m 6 -sns 70 -resize 540 0 "$SHOTS/$1.png" -o "$OUT/img/$2.webp"
}
shot home_idle_en home-en
shot now_playing_live_en player-en
shot hukamnama_en hukamnama-en
shot home_idle_pa home-pa
shot now_playing_live_pa player-pa
shot hukamnama_pa hukamnama-pa

cwebp -quiet -q 72 -m 6 assets/images/1.jpg -o "$OUT/img/hero.webp"
cwebp -quiet -q 90 -m 6 -resize 192 0 \
  macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png -o "$OUT/img/icon.webp"
