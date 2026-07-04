#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Extra AI"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
APP_BUNDLE="$ROOT_DIR/build/macos/Build/Products/Release/$APP_NAME.app"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

dart_defines=()
if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  dart_defines+=(--dart-define=GEMINI_API_KEY="$GEMINI_API_KEY")
fi
dart_defines+=(--dart-define=GEMINI_MODEL="${GEMINI_MODEL:-gemini-2.5-flash}")
if [[ -n "${AZURE_OPENAI_ENDPOINT:-}" ]]; then
  dart_defines+=(--dart-define=AZURE_OPENAI_ENDPOINT="$AZURE_OPENAI_ENDPOINT")
fi
if [[ -n "${AZURE_OPENAI_KEY:-}" ]]; then
  dart_defines+=(--dart-define=AZURE_OPENAI_KEY="$AZURE_OPENAI_KEY")
fi
if [[ -n "${AZURE_OPENAI_DEPLOYMENT:-}" ]]; then
  dart_defines+=(--dart-define=AZURE_OPENAI_DEPLOYMENT="$AZURE_OPENAI_DEPLOYMENT")
fi
if [[ -n "${DEMO_FALLBACK:-}" ]]; then
  dart_defines+=(--dart-define=DEMO_FALLBACK="$DEMO_FALLBACK")
fi
if [[ -n "${MOCK_DATA:-}" ]]; then
  dart_defines+=(--dart-define=MOCK_DATA="$MOCK_DATA")
  dart_defines+=(--dart-define=MOCK_PROJECT_PATH="${MOCK_PROJECT_PATH:-$ROOT_DIR}")
fi

flutter build macos "${dart_defines[@]}"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    open_app
    sleep 1
    lldb -p "$(pgrep -x "$APP_NAME" | head -n 1)"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
