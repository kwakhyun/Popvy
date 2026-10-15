#!/bin/bash
# Local packaging only: does not publish, install, or change macOS permissions.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
source "$PROJECT_DIR/scripts/signing.sh"
popvy_configure_signing
if [ "$POPVY_SIGNING_IDENTITY" = - ] && [ "${POPVY_ALLOW_ADHOC_RELEASE:-0}" != 1 ]; then
    printf 'Release requires POPVY_SIGNING_IDENTITY and POPVY_TEAM_ID.\nFor an explicitly unsigned-by-Apple test release only, set POPVY_ALLOW_ADHOC_RELEASE=1.\n' >&2
    exit 1
fi
export POPVY_SIGNING_IDENTITY POPVY_TEAM_ID
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
if [ -n "${POPVY_PREVIOUS_APP:-}" ]; then
    bash "$PROJECT_DIR/scripts/verify-update-signature.sh" "$POPVY_PREVIOUS_APP" "$APP_SOURCE"
fi
STAGING_DIR=$(mktemp -d "$PROJECT_DIR/build/release.XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT
PAYLOAD="$STAGING_DIR/payload"
ARTIFACTS="$STAGING_DIR/artifacts"
mkdir -p "$PAYLOAD" "$ARTIFACTS"
ditto --norsrc --noextattr "$APP_SOURCE" "$PAYLOAD/Popvy.app"
if [ "$POPVY_SIGNING_IDENTITY" = - ]; then
    cp docs/INSTALL.txt "$PAYLOAD/설치 안내.txt"
else
    sed 's/현재 배포본은 Apple Developer ID 서명과 공증이 없는 임시 서명 빌드입니다./이 배포본은 Developer ID로 서명했지만 Apple 공증은 아직 받지 않았습니다./' \
        docs/INSTALL.txt > "$PAYLOAD/설치 안내.txt"
fi
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
printf '\nRelease prepared: %s\n' "$OUTPUT_DIR"
if [ "$POPVY_SIGNING_IDENTITY" = - ]; then
    printf 'Ad-hoc signed; Accessibility permission may need reapproval after updates.\n'
else
    printf 'Developer ID signed, team: %s\n' "$POPVY_TEAM_ID"
fi
printf 'NOT notarized. Nothing has been uploaded.\n'
