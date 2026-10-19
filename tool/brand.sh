#!/bin/zsh
# Builds the app's icon and splash inputs (assets/brand) from the brand
# source files (brand/), then regenerates launcher icons and splash screens.
#
#   tool/brand.sh
#
# The full icon and splash images are used as designed. The adaptive icon
# layers are re-rendered edge to edge from brand/logo.svg, because the icon
# generator already insets them by 16%; extra padding makes the mark small.
# Needs rsvg-convert (brew install librsvg).
set -euo pipefail
cd "$(dirname "$0")/.."
command -v rsvg-convert >/dev/null || { echo "rsvg-convert missing: brew install librsvg"; exit 1; }

out=assets/brand
mkdir -p "$out"
cp brand/logo.svg "$out/logo.svg"
for f in icon_full splash_light splash_dark splash12_light splash12_dark; do
  cp "brand/$f.png" "$out/$f.png"
done

inner=$(sed -E 's#^<svg[^>]*>##; s#</svg>$##' brand/logo.svg)
layer() { # name, ink color, glint color
  print -r -- "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1024\" height=\"1024\" viewBox=\"0 0 100 100\">${inner//currentColor/$2}</svg>" \
    | sed "s/#FF6600/$3/g" > "$out/$1.svg"
  rsvg-convert -w 1024 -h 1024 "$out/$1.svg" -o "$out/$1.png"
  rm "$out/$1.svg"
}
layer icon_foreground '#111111' '#FF6600'
layer icon_monochrome '#000000' '#000000'

dart run flutter_launcher_icons
dart run flutter_native_splash:create
