#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
SRC="$ROOT_DIR/packages/flutterxel/src/flutterxel.c"
OUT_DIR="$ROOT_DIR/packages/flutterxel/.dart_tool/host_c_scaffold"
CC_BIN="${CC:-cc}"

mkdir -p "$OUT_DIR"

case "$(uname -s)" in
  Darwin)
    OUT="$OUT_DIR/libflutterxel_c_scaffold_host.dylib"
    "$CC_BIN" -std=c11 -O2 -dynamiclib "$SRC" -o "$OUT" -lm
    ;;
  Linux)
    OUT="$OUT_DIR/libflutterxel_c_scaffold_host.so"
    "$CC_BIN" -std=c11 -O2 -shared -fPIC "$SRC" -o "$OUT" -lm
    ;;
  MINGW* | MSYS* | CYGWIN*)
    OUT="$OUT_DIR/flutterxel_c_scaffold_host.dll"
    "$CC_BIN" -std=c11 -O2 -shared "$SRC" -o "$OUT"
    ;;
  *)
    echo "Unsupported host OS: $(uname -s)" >&2
    exit 1
    ;;
esac

echo "$OUT"
