#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SOURCE="$PROJECT_DIR/build/Popvy.app"
APP_DESTINATION="$HOME/Applications/Popvy.app"
if pgrep -x Popvy >/dev/null || pgrep -x ClipShelf >/dev/null; then
    printf '실행 중인 Popvy 또는 이전 버전을 메뉴 막대에서 종료한 뒤 다시 설치해 주세요.\n'
    exit 1
fi
/bin/bash "$PROJECT_DIR/scripts/build.sh"
mkdir -p "$HOME/Applications"
ditto "$APP_SOURCE" "$APP_DESTINATION"
open "$APP_DESTINATION"
printf '\n설치했습니다: %s\nOption + V로 클립보드 기록을 여세요.\n' "$APP_DESTINATION"
