#!/bin/bash
# Local packaging only: does not publish, install, or change macOS permissions.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
case "$VERSION" in ''|*[!0-9.]*) printf 'Invalid version\n' >&2; exit 1 ;; esac
OUTPUT_DIR="$PROJECT_DIR/dist/v$VERSION"
if [ -e "$OUTPUT_DIR" ]; then
    printf 'Already exists: %s\nMove this release directory aside before rebuilding.\n' "$OUTPUT_DIR" >&2
    exit 1
fi
if [ ! -f LICENSE ]; then printf 'A LICENSE file is required before packaging.\n' >&2; exit 1; fi
bash scripts/build.sh universal
APP_SOURCE="$PROJECT_DIR/build/universal/Popvy.app"
STAGING_DIR=$(mktemp -d "$PROJECT_DIR/build/release.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT
PAYLOAD="$STAGING_DIR/payload"
ARTIFACTS="$STAGING_DIR/artifacts"
mkdir -p "$PAYLOAD" "$ARTIFACTS"
ditto --norsrc --noextattr "$APP_SOURCE" "$PAYLOAD/Popvy.app"
cp docs/INSTALL.txt "$PAYLOAD/설치 안내.txt"
cp LICENSE "$PAYLOAD/LICENSE.txt"
ln -s /Applications "$PAYLOAD/Applications"
codesign --verify --deep --strict "$PAYLOAD/Popvy.app"
NAME="Popvy-$VERSION-macos-universal"
hdiutil create -volname "Popvy $VERSION" -srcfolder "$PAYLOAD" -ov -format UDZO "$ARTIFACTS/$NAME.dmg"
hdiutil verify "$ARTIFACTS/$NAME.dmg"
(
    cd "$ARTIFACTS"
    shasum -a 256 "$NAME.dmg" > SHA256SUMS.txt
    shasum -a 256 -c SHA256SUMS.txt
)
mkdir -p "$PROJECT_DIR/dist"
mv "$ARTIFACTS" "$OUTPUT_DIR"
printf '\nRelease prepared: %s\nAd-hoc signed; NOT notarized. Nothing has been uploaded.\n' "$OUTPUT_DIR"
