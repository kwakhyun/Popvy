#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
MODE="${1:-check}"
DERIVED="$PROJECT_DIR/build/appstore-derived"
ARCHIVE="$PROJECT_DIR/build/appstore/Popvy.xcarchive"
ARGS=(-project Popvy.xcodeproj -scheme PopvyAppStore -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED")
case "$MODE" in
    check)
        xcodebuild "${ARGS[@]}" CODE_SIGNING_ALLOWED=NO build
        bash scripts/verify-appstore.sh "$DERIVED/Build/Products/Release/Popvy.app" unsigned
        ;;
    archive)
        if [ -e "$ARCHIVE" ]; then
            printf 'Archive already exists: %s. Move it before creating another archive.\n' "$ARCHIVE" >&2
            exit 1
        fi
        # Sign into the selected team in Xcode and prepare its certificates beforehand.
        xcodebuild "${ARGS[@]}" -archivePath "$ARCHIVE" -allowProvisioningUpdates archive
        bash scripts/verify-appstore.sh "$ARCHIVE/Products/Applications/Popvy.app"
        printf '\nArchive ready for Xcode Organizer: %s\n' "$ARCHIVE"
        ;;
    export)
        bash scripts/verify-appstore.sh "$ARCHIVE/Products/Applications/Popvy.app"
        xcodebuild -exportArchive -archivePath "$ARCHIVE" \
            -exportPath "$PROJECT_DIR/build/appstore/export" \
            -exportOptionsPlist Resources/AppStore/ExportOptions.plist -allowProvisioningUpdates
        ;;
    *) printf 'Usage: bash scripts/appstore.sh [check|archive|export]\n' >&2; exit 1 ;;
esac
