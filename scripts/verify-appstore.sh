#!/bin/bash
set -euo pipefail
APP="${1:?Usage: bash scripts/verify-appstore.sh path/to/Popvy.app [unsigned]}"
MODE="${2:-signed}"
case "$MODE" in signed|unsigned) ;; *) printf 'Mode must be signed or unsigned.\n' >&2; exit 1 ;; esac
INFO="$APP/Contents/Info.plist"
BIN="$APP/Contents/MacOS/Popvy"
test "$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$INFO")" = app.popvy.mac.store
test "$(/usr/bin/plutil -extract LSApplicationCategoryType raw -o - "$INFO")" = public.app-category.productivity
/usr/bin/plutil -lint "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
ARCHS=" $(/usr/bin/lipo -archs "$BIN") "
[[ "$ARCHS" == *" arm64 "* && "$ARCHS" == *" x86_64 "* ]]
# A store build must not merely hide buttons while still linking cross-app input APIs.
SYMBOLS="$(/usr/bin/nm -u "$BIN")"
if printf '%s\n' "$SYMBOLS" | /usr/bin/grep -Eq '_AX(IsProcessTrusted|UIElement|Value)|_CGEvent(Post|CreateKeyboardEvent)'; then
    printf 'App Store build still references assistive APIs or synthetic keyboard events.\n' >&2
    exit 1
fi
if [ "$MODE" != unsigned ]; then
    /usr/bin/codesign --verify --deep --strict "$APP"
    ENTITLEMENTS="$(/usr/bin/codesign -d --entitlements :- "$APP" 2>/dev/null)"
    test "$(printf '%s' "$ENTITLEMENTS" | /usr/bin/plutil -extract 'com\.apple\.security\.app-sandbox' raw -o - -)" = true
    DETAILS="$(/usr/bin/codesign -dvv "$APP" 2>&1)"
    printf '%s\n' "$DETAILS" | /usr/bin/grep -q '^TeamIdentifier=NB4ZP7R5G7$'
fi
printf 'App Store checks passed (%s). This does not validate an upload or App Review approval.\n' "$MODE"
