#!/bin/zsh
# Publishes a built release to the public download repo,
# Diary-Axel-RAKOTOARIVAO/hoglens-releases: the APKs and the release notes,
# never the code or the symbols. Asset names carry no version, so these links
# always serve the newest release:
#
#   https://github.com/Diary-Axel-RAKOTOARIVAO/hoglens-releases/releases/latest/download/hoglens-arm64.apk
#   https://github.com/Diary-Axel-RAKOTOARIVAO/hoglens-releases/releases/latest/download/hoglens-armv7.apk
#   https://github.com/Diary-Axel-RAKOTOARIVAO/hoglens-releases/releases/latest/download/hoglens-x86_64.apk
#
# The app's update check reads this repo's latest release too.
#
#   tool/publish_public.sh v1.2.3      # run by tool/release.sh; by hand to republish
set -euo pipefail
cd "$(dirname "$0")/.."

TAG=${1:?usage: tool/publish_public.sh vX.Y.Z}
V=${TAG#v}
REPO=Diary-Axel-RAKOTOARIVAO/hoglens-releases
DIST="dist/$TAG"
OUT="$DIST/public"

for f in "hoglens-$V-arm64.apk" "hoglens-$V-armv7.apk" "hoglens-$V-x86_64.apk" notes.md; do
  [ -f "$DIST/$f" ] || { echo "$DIST/$f missing: build the release first"; exit 1; }
done

rm -rf "$OUT"; mkdir -p "$OUT"
for abi in arm64 armv7 x86_64; do cp "$DIST/hoglens-$V-$abi.apk" "$OUT/hoglens-$abi.apk"; done
{
  cat "$DIST/notes.md"
  print '\n### SHA-256\n```'
  (cd "$OUT" && shasum -a 256 *.apk)
  print '```'
} > "$OUT/notes.md"

echo "== $TAG: publishing to $REPO"
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" --repo "$REPO" --clobber "$OUT"/*.apk
  gh release edit "$TAG" --repo "$REPO" --notes-file "$OUT/notes.md"
else
  gh release create "$TAG" --repo "$REPO" --target main --latest \
    --title "HogLens $V" --notes-file "$OUT/notes.md" "$OUT"/*.apk
fi
gh release view "$TAG" --repo "$REPO" --json url --jq .url
