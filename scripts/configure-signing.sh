#!/bin/bash
# Save certificate selection only. No passwords or private keys are exported.
set -euo pipefail
if [ "$#" -ne 2 ]; then
    printf 'Usage: bash scripts/configure-signing.sh "Developer ID Application: Name (TEAMID)" TEAMID\n' >&2
    exit 1
fi
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/scripts/signing.sh"
POPVY_SIGNING_IDENTITY="$1"
POPVY_TEAM_ID="$2"
if [ "$POPVY_SIGNING_IDENTITY" = - ]; then
    printf 'A Developer ID certificate is required for a saved configuration.\n' >&2
    exit 1
fi
popvy_configure_signing
umask 077
TEMP_CONFIG=$(mktemp "$PROJECT_DIR/.popvy-signing.plist.XXXXXX")
trap 'rm -f "$TEMP_CONFIG"' EXIT
/usr/bin/plutil -create xml1 "$TEMP_CONFIG"
/usr/bin/plutil -insert identity -string "$POPVY_SIGNING_IDENTITY" "$TEMP_CONFIG"
/usr/bin/plutil -insert teamID -string "$POPVY_TEAM_ID" "$TEMP_CONFIG"
/usr/bin/plutil -lint "$TEMP_CONFIG" >/dev/null
mv "$TEMP_CONFIG" "$PROJECT_DIR/.popvy-signing.plist"
printf 'Saved local Developer ID selection. Future builds use this identity. No key material was saved.\n'
