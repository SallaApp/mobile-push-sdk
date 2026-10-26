#!/usr/bin/env bash
# Regenerates the Pigeon bridge from pigeons/messages.dart: lib/src/messages.g.dart, Messages.g.swift and
# Messages.g.kt. Uses $FLUTTER when set, else flutter on PATH, and the dart next to it.
set -euo pipefail

cd "$(dirname "$0")/.."

FLUTTER="${FLUTTER:-$(command -v flutter || true)}"
if [ -z "$FLUTTER" ]; then
  echo "generate-pigeon.sh: set FLUTTER to the flutter executable, or put flutter on PATH" >&2
  exit 1
fi
DART="$(dirname "$FLUTTER")/dart"

"$FLUTTER" pub get >/dev/null
"$DART" run pigeon --input pigeons/messages.dart
"$DART" format lib/src/messages.g.dart >/dev/null
