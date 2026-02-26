#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
CORE_DIR="$ROOT_DIR/native/flutterxel_core"
OUT_ANDROID_DIR="$ROOT_DIR/packages/flutterxel/native/android/jniLibs"

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not found. Install Rust toolchain for maintainer builds." >&2
  exit 1
fi

echo "[flutterxel_tools] building host rust core (sanity check)"
(cd "$CORE_DIR" && cargo build --release)

echo "[flutterxel_tools] host build complete"
echo "[flutterxel_tools] android/ios cross-build is maintainer task (NDK/Xcode toolchain required)."
echo "[flutterxel_tools] expected android output layout: $OUT_ANDROID_DIR/<abi>/libflutterxel_core.so"
