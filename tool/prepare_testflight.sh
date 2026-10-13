#!/bin/sh
set -eu

# Resolve the project directory so the script works from any directory.
PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_DIR"

# Prefer an explicitly selected SDK, then PATH and common persistent locations.
if [ -n "${FLUTTER_ROOT:-}" ]; then
  FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"
  if [ ! -x "$FLUTTER_BIN" ]; then
    printf 'Flutter не найден в FLUTTER_ROOT: %s\n' "$FLUTTER_ROOT" >&2
    exit 1
  fi
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN=$(command -v flutter)
else
  FLUTTER_BIN=''
  for SDK_DIR in \
    "$PROJECT_DIR/.fvm/flutter_sdk" \
    "$HOME/develop/flutter" \
    "$HOME/development/flutter" \
    "$HOME/flutter" \
    /opt/homebrew/share/flutter \
    /opt/homebrew/Caskroom/flutter/latest/flutter; do
    if [ -x "$SDK_DIR/bin/flutter" ]; then
      FLUTTER_BIN="$SDK_DIR/bin/flutter"
      break
    fi
  done

  if [ -z "$FLUTTER_BIN" ]; then
    SDK_DIR="$HOME/develop/flutter"
    if [ -e "$SDK_DIR" ]; then
      printf 'В %s уже есть файлы, но SDK не найден. Укажите FLUTTER_ROOT.\n' "$SDK_DIR" >&2
      exit 1
    fi
    printf 'Устанавливаю официальный Flutter SDK в %s…\n' "$SDK_DIR"
    mkdir -p "$HOME/develop"
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$SDK_DIR"
    FLUTTER_BIN="$SDK_DIR/bin/flutter"
  fi
fi

export PATH="$(dirname -- "$FLUTTER_BIN"):$PATH"
printf 'Flutter: %s\n' "$FLUTTER_BIN"

"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build ios --release --config-only \
  --build-name=1.0.0 \
  --build-number=6 \
  --dart-define=API_ORIGIN=https://selfcheck.pro \
  --target=lib/main.dart

open ios/Runner.xcworkspace
