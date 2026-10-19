#!/bin/zsh
# Builds and publishes a release from this machine: three APKs (arm64, armv7,
# x86_64) and a GitHub Release whose notes come from the version's section of
# CHANGELOG.md. Symbols for the obfuscated build stay in dist/.
#
#   tool/release.sh            # version from pubspec.yaml, tags vX.Y.Z
#
# Then publishes the APKs to the public download repo (tool/publish_public.sh).
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

DIST="dist/$TAG"; rm -rf "$DIST"; mkdir -p "$DIST"
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   "$DIST/hoglens-$V-arm64.apk"
cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk "$DIST/hoglens-$V-armv7.apk"
cp build/app/outputs/flutter-apk/app-x86_64-release.apk      "$DIST/hoglens-$V-x86_64.apk"
tar -czf "$DIST/hoglens-$V-symbols.tar.gz" -C build symbols
ls -la "$DIST"

awk -v v="$V" '
  /^## \[/ { if (found) exit; if (index($0, "## [" v "]") == 1) { found = 1; next } }
  found { print }
' CHANGELOG.md > "$DIST/notes.md"
[ -s "$DIST/notes.md" ] || echo "_No changelog entry for $V._" > "$DIST/notes.md"

echo "== $TAG: tagging and publishing"
git tag "$TAG"
git push origin main "$TAG"
gh release create "$TAG" --title "HogLens $TAG" --notes-file "$DIST/notes.md" \
  "$DIST/hoglens-$V-arm64.apk" "$DIST/hoglens-$V-armv7.apk" "$DIST/hoglens-$V-x86_64.apk"
gh release view "$TAG" --json url --jq .url

# Public download repo: APKs and notes only (never code or symbols).
tool/publish_public.sh "$TAG"
