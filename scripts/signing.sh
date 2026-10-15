#!/bin/bash
# Shared by build.sh and release.sh. Never chooses an account automatically.
popvy_configure_signing() {
    local config="${POPVY_SIGNING_CONFIG:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.popvy-signing.plist}"
    if [ "${POPVY_SIGNING_IDENTITY+x}" != x ] && [ -f "$config" ]; then
        POPVY_SIGNING_IDENTITY=$(/usr/bin/plutil -extract identity raw -o - "$config") || return 1
        POPVY_TEAM_ID=$(/usr/bin/plutil -extract teamID raw -o - "$config") || return 1
        if [ -z "$POPVY_SIGNING_IDENTITY" ] || [ "$POPVY_SIGNING_IDENTITY" = - ]; then
            printf 'Saved signing configuration must contain a Developer ID identity.\n' >&2
            return 1
        fi
    fi
    POPVY_SIGNING_IDENTITY="${POPVY_SIGNING_IDENTITY:--}"
    POPVY_TEAM_ID="${POPVY_TEAM_ID:-}"
    if [ "$POPVY_SIGNING_IDENTITY" = - ]; then
        if [ -n "$POPVY_TEAM_ID" ]; then
            printf 'POPVY_TEAM_ID requires a Developer ID Application signing identity.\n' >&2
            return 1
        fi
        return 0
    fi
    case "$POPVY_SIGNING_IDENTITY" in
        'Developer ID Application: '*) ;;
        *) printf 'Use the full Developer ID Application certificate name, not Apple Development or Apple Distribution.\n' >&2; return 1 ;;
    esac
    if [[ ! "$POPVY_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
        printf 'Set POPVY_TEAM_ID to the 10-character team ID for this certificate.\n' >&2
        return 1
    fi
    local identities
    identities="$(security find-identity -v -p codesigning)" || return 1
    if ! printf '%s\n' "$identities" | grep -Fq "\"$POPVY_SIGNING_IDENTITY\""; then
        printf 'The requested Developer ID Application certificate and private key are not available.\n' >&2
        return 1
    fi
    case "$POPVY_SIGNING_IDENTITY" in
        *" ($POPVY_TEAM_ID)") ;;
        *) printf 'Certificate name and POPVY_TEAM_ID do not match.\n' >&2; return 1 ;;
    esac
}

popvy_sign_app() {
    local app="$1"
    if [ "$POPVY_SIGNING_IDENTITY" = - ]; then
        codesign --force --sign - --identifier app.popvy.mac "$app" || return 1
        printf 'WARNING: local ad-hoc signing can require Accessibility permission again after an update.\n' >&2
    else
        codesign --force --sign "$POPVY_SIGNING_IDENTITY" --identifier app.popvy.mac \
            --options runtime --timestamp "$app" || return 1
        local metadata
        metadata="$(codesign -d --verbose=4 "$app" 2>&1)" || return 1
        if ! printf '%s\n' "$metadata" | grep -Fxq "TeamIdentifier=$POPVY_TEAM_ID"; then
            printf 'Signed app team differs from POPVY_TEAM_ID.\n' >&2
            return 1
        fi
        if ! printf '%s\n' "$metadata" | grep -Fxq "Authority=$POPVY_SIGNING_IDENTITY"; then
            printf 'Signed app certificate differs from the requested identity.\n' >&2
            return 1
        fi
    fi
    codesign --verify --deep --strict "$app"
}
