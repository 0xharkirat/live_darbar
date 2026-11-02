#!/bin/bash
# Rebuilds the fonts and the icon of the landing page in site/.
#
#     tool/site_assets.sh path/to/Geist-Variable.ttf
#
# Geist is not one of the app's fonts. Take Geist-Variable.ttf from the npm
# package `geist` (dist/fonts/geist-sans/), and its LICENSE.TXT, which the
# script does not copy: site/fonts/GEIST-OFL.txt holds it. The Gurmukhi fonts
# and the icon come from the app's own files.
#
# Needs `pyftsubset` (pip install fonttools brotli) and `cwebp` (brew install webp).
# Not made here:
#   site/img/film*.mp4, .webm, .json and the posters: tool/site_film.dart
#   site/img/shot-*.webp: the screenshots, from `flutter test test/screens
#     --tags screens` (build/screens/), cut to 360 px wide with cwebp
#   site/img/badge-*: the stores' own badges, downloaded as they are from
#     https://toolbox.marketingtools.apple.com (Apple, the page that replaced
#     tools.applemarketingtools.com) and https://play.google.com/intl/en_us/badges/
#   site/img/og.jpg: 1200x630, drawn once from assets/images/0.jpg with the
#     title set in Noto Serif.
set -euo pipefail
cd "$(dirname "$0")/.."

GEIST=${1:?Pass the path of Geist-Variable.ttf.}
FONTS=assets/fonts
OUT=site

# Geist is Latin only, and comes first in the font stack of both pages.
LATIN="U+0020-007E,U+00A0,U+00A9,U+00B7,U+2013,U+2014,U+2018,U+2019,U+201C,U+201D,U+2022,U+2026,U+2192,U+2197"
# The Gurmukhi files hold the Gurmukhi block, the dandas and basic
# punctuation. No Latin letters: Geist sets them. No hinting.
GURMUKHI="U+0A00-0A7F,U+0964-0965,U+0020-003F,U+00A0,U+200C-200D,U+2013-2014,U+2018-201D,U+2026,U+2212,U+25CC"

mkdir -p "$OUT/fonts" "$OUT/img"

subset() { # font file, unicodes, output name, extra flags
  pyftsubset "$FONTS/$1" --unicodes="$2" --flavor=woff2 --no-hinting \
    --output-file="$OUT/fonts/$3.woff2" ${4:+"$4"}
}
# The variable file holds every weight, so one file does.
pyftsubset "$GEIST" --unicodes="$LATIN" --flavor=woff2 --no-hinting \
  --layout-features='kern,liga,calt,ccmp,locl,mark,mkmk,ss01,tnum,case' \
  --output-file="$OUT/fonts/geist-variable.woff2"
for w in 400 700; do
  subset "NotoSansGurmukhi-$w.ttf" "$GURMUKHI" "noto-sans-gurmukhi-$w" --layout-features='*'
done
# The /pa/ headings. Tiro Gurmukhi has 1 weight, 400. Its licence is
# site/fonts/TIRO-GURMUKHI-OFL.txt.
subset "TiroGurmukhi-400.ttf" "$GURMUKHI" "tiro-gurmukhi-400" --layout-features='*'

cwebp -quiet -q 90 -m 6 -resize 192 0 \
  macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png -o "$OUT/img/icon.webp"
