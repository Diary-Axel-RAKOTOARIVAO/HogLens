#!/bin/zsh
# Builds and publishes a release from this machine: three APKs (arm64, armv7,
# x86_64) and a GitHub Release whose notes come from the version's section of
# CHANGELOG.md plus the SHA-256 of each APK. Symbols for the obfuscated build
# stay in dist/.
#
# Asset names carry no version, so these links always serve the newest release:
#
#   https://github.com/Diary-Axel-RAKOTOARIVAO/HogLens/releases/latest/download/hoglens-arm64.apk
#   https://github.com/Diary-Axel-RAKOTOARIVAO/HogLens/releases/latest/download/hoglens-armv7.apk
#   https://github.com/Diary-Axel-RAKOTOARIVAO/HogLens/releases/latest/download/hoglens-x86_64.apk
#
# The app's update check reads this repo's latest release.
#
#   tool/release.sh            # version from pubspec.yaml, tags vX.Y.Z
#
# Needs: android/key.properties (release key), gh signed in, a clean tree
# with the release commit already made.
set -euo pipefail
cd "$(dirname "$0")/.."

V=$(sed -n 's/^version: \([0-9.]*\)+.*/\1/p' pubspec.yaml)
TAG="v$V"
[ -n "$(git status --porcelain)" ] && { echo "working tree not clean"; exit 1; }
[ -f android/key.properties ] || { echo "android/key.properties missing (release key)"; exit 1; }
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && { echo "$TAG already exists"; exit 1; }

echo "== $TAG: building"
flutter pub get >/dev/null
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols

DIST="dist/$TAG"; rm -rf "$DIST"; mkdir -p "$DIST/apk"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   "$DIST/apk/hoglens-arm64.apk"
cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "$DIST/apk/hoglens-armv7.apk"
cp build/app/outputs/flutter-apk/app-x86_64-release.apk      "$DIST/apk/hoglens-x86_64.apk"
tar -czf "$DIST/hoglens-$V-symbols.tar.gz" -C build symbols
ls -la "$DIST" "$DIST/apk"

awk -v v="$V" '
  /^## \[/ { if (found) exit; if (index($0, "## [" v "]") == 1) { found = 1; next } }
  found { print }
' CHANGELOG.md > "$DIST/notes.md"
[ -s "$DIST/notes.md" ] || echo "_No changelog entry for $V._" > "$DIST/notes.md"
{
  print '\n### SHA-256\n```'
  (cd "$DIST/apk" && shasum -a 256 *.apk)
  print '```'
} >> "$DIST/notes.md"

echo "== $TAG: tagging and publishing"
git tag "$TAG"
git push origin main "$TAG"
gh release create "$TAG" --title "HogLens $TAG" --notes-file "$DIST/notes.md" "$DIST"/apk/*.apk
gh release view "$TAG" --json url --jq .url
