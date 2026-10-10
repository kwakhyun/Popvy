#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/module-cache"
BUILD_ARGS=(--configuration release --disable-sandbox)
case "${1:-native}" in
    native) APP_DIR="$PROJECT_DIR/build/Popvy.app" ;;
    universal)
        BUILD_ARGS+=(--arch arm64 --arch x86_64)
        APP_DIR="$PROJECT_DIR/build/universal/Popvy.app"
        ;;
    *) printf 'Usage: bash scripts/build.sh [native|universal]\n' >&2; exit 1 ;;
esac
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
if [ -d "$APP_DIR" ]; then rm -rf "$APP_DIR"; fi
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/Popvy" "$APP_DIR/Contents/MacOS/Popvy"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/LICENSE" "$APP_DIR/Contents/Resources/LICENSE.txt"
swift "$PROJECT_DIR/scripts/make-icon.swift" "$PROJECT_DIR/build"
iconutil -c icns "$PROJECT_DIR/build/Popvy.iconset" -o "$APP_DIR/Contents/Resources/Popvy.icns"
codesign --force --deep --sign - --identifier app.popvy.mac "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
if [ "${1:-native}" = universal ]; then
    ARCHITECTURES=" $(lipo -archs "$APP_DIR/Contents/MacOS/Popvy") "
    if [[ "$ARCHITECTURES" != *" arm64 "* || "$ARCHITECTURES" != *" x86_64 "* ]]; then
        printf 'Universal build is missing an architecture: %s\n' "$ARCHITECTURES" >&2
        exit 1
    fi
fi
printf '\n완료: %s\n' "$APP_DIR"
