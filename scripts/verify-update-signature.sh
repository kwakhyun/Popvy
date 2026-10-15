#!/bin/bash
# Compare OS signing identities without changing TCC or custom signing requirements.
set -euo pipefail
if [ "$#" -ne 2 ]; then
    printf 'Usage: bash scripts/verify-update-signature.sh previous.app updated.app\n' >&2
    exit 1
fi
PREVIOUS_APP="$1"
UPDATED_APP="$2"
for app in "$PREVIOUS_APP" "$UPDATED_APP"; do
    test -d "$app" || { printf 'App not found: %s\n' "$app" >&2; exit 1; }
    codesign --verify --deep --strict "$app"
    identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")
    test "$identifier" = app.popvy.mac || { printf 'Unexpected bundle identifier.\n' >&2; exit 1; }
    metadata=$(codesign -d --verbose=4 "$app" 2>&1)
    if ! printf '%s\n' "$metadata" | grep -q '^Authority=Developer ID Application: '; then
        printf 'Both apps must be Developer ID signed. An ad-hoc-to-Developer-ID transition needs a fresh permission grant.\n' >&2
        exit 1
    fi
done
old_metadata=$(codesign -d --verbose=4 "$PREVIOUS_APP" 2>&1)
new_metadata=$(codesign -d --verbose=4 "$UPDATED_APP" 2>&1)
old_team=$(printf '%s\n' "$old_metadata" | sed -n 's/^TeamIdentifier=//p')
new_team=$(printf '%s\n' "$new_metadata" | sed -n 's/^TeamIdentifier=//p')
if [ -z "$old_team" ] || [ "$old_team" = not\ set ] || [ "$old_team" != "$new_team" ]; then
    printf 'Developer team changed; permission continuity cannot be assumed.\n' >&2
    exit 1
fi
old_requirement=$(codesign -d -r- "$PREVIOUS_APP" 2>&1 | sed -n 's/^designated => //p; s/^# designated => //p')
new_requirement=$(codesign -d -r- "$UPDATED_APP" 2>&1 | sed -n 's/^designated => //p; s/^# designated => //p')
test -n "$old_requirement" && test -n "$new_requirement"
codesign --verify --strict -R "$old_requirement" "$UPDATED_APP"
codesign --verify --strict -R "$new_requirement" "$PREVIOUS_APP"
printf 'Matching Developer ID signing identities, team %s. macOS still controls permission retention.\n' "$old_team"
