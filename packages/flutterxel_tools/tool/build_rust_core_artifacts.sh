#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: build_rust_core_artifacts.sh [--android] [--ios] [--all] [--out-dir <dir>] [--skip-host-check]

Options:
  --android          Build Android .so artifacts (jniLibs layout)
  --ios              Build iOS static libs + FlutterxelCore.xcframework
  --all              Build both Android and iOS artifacts (default when no platform flag is given)
  --out-dir <dir>    Optional directory to copy packaged outputs into
  --skip-host-check  Skip host rust test sanity check
  -h, --help         Show this help
USAGE
}

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
CORE_DIR="$ROOT_DIR/native/flutterxel_core"
HEADER_DIR="$CORE_DIR/include"
ANDROID_OUT_DIR="$ROOT_DIR/packages/flutterxel/native/android/jniLibs"
IOS_FRAMEWORKS_OUT_DIR="$ROOT_DIR/packages/flutterxel/ios/Frameworks"
IOS_BUILD_DIR="$ROOT_DIR/packages/flutterxel/.dart_tool/native_ios_build"
IOS_LEGACY_NATIVE_OUT_DIR="$ROOT_DIR/packages/flutterxel/native/ios"

BUILD_ANDROID=0
BUILD_IOS=0
SKIP_HOST_CHECK=0
OUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --android)
      BUILD_ANDROID=1
      ;;
    --ios)
      BUILD_IOS=1
      ;;
    --all)
      BUILD_ANDROID=1
      BUILD_IOS=1
      ;;
    --out-dir)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --out-dir" >&2
        exit 64
      fi
      OUT_DIR="$2"
      shift
      ;;
    --skip-host-check)
      SKIP_HOST_CHECK=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

if [[ "$BUILD_ANDROID" -eq 0 && "$BUILD_IOS" -eq 0 ]]; then
  BUILD_ANDROID=1
  BUILD_IOS=1
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo not found. Install Rust toolchain for maintainer builds." >&2
  exit 1
fi
if ! command -v rustup >/dev/null 2>&1; then
  echo "rustup not found. Install rustup to manage cross-compilation targets." >&2
  exit 1
fi

if [[ "$SKIP_HOST_CHECK" -eq 0 ]]; then
  echo "[flutterxel_tools] host rust core test sanity check"
  (cd "$CORE_DIR" && cargo test)
fi

build_android() {
  echo "[flutterxel_tools] building Android artifacts"

  if [[ -z "${ANDROID_NDK_HOME:-}" && -z "${ANDROID_NDK_ROOT:-}" ]]; then
    echo "ANDROID_NDK_HOME (or ANDROID_NDK_ROOT) is not set." >&2
    echo "Set Android NDK path before running Android cross-build." >&2
    exit 1
  fi

  if ! command -v cargo-ndk >/dev/null 2>&1; then
    echo "cargo-ndk is required. Install with: cargo install cargo-ndk --locked" >&2
    exit 1
  fi

  rustup target add \
    aarch64-linux-android \
    armv7-linux-androideabi \
    x86_64-linux-android

  mkdir -p "$ANDROID_OUT_DIR"

  (
    cd "$CORE_DIR"
    cargo ndk \
      -t arm64-v8a \
      -t armeabi-v7a \
      -t x86_64 \
      -o "$ANDROID_OUT_DIR" \
      build --release
  )

  local expected=(
    "$ANDROID_OUT_DIR/arm64-v8a/libflutterxel_core.so"
    "$ANDROID_OUT_DIR/armeabi-v7a/libflutterxel_core.so"
    "$ANDROID_OUT_DIR/x86_64/libflutterxel_core.so"
  )
  for file in "${expected[@]}"; do
    if [[ ! -f "$file" ]]; then
      echo "Missing Android artifact: $file" >&2
      exit 1
    fi
  done

  echo "[flutterxel_tools] Android artifacts ready at $ANDROID_OUT_DIR"
}

build_ios() {
  echo "[flutterxel_tools] building iOS artifacts"

  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "iOS build requires macOS (xcodebuild/lipo)." >&2
    exit 1
  fi
  if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "xcodebuild not found. Install Xcode command line tools." >&2
    exit 1
  fi
  if ! command -v lipo >/dev/null 2>&1; then
    echo "lipo not found. Install Xcode command line tools." >&2
    exit 1
  fi

  rustup target add \
    aarch64-apple-ios \
    aarch64-apple-ios-sim \
    x86_64-apple-ios

  (
    cd "$CORE_DIR"
    cargo build --release --target aarch64-apple-ios
    cargo build --release --target aarch64-apple-ios-sim
    cargo build --release --target x86_64-apple-ios
  )

  local ios_build_dir="$IOS_BUILD_DIR"
  local device_dir="$ios_build_dir/ios-arm64"
  local sim_dir="$ios_build_dir/ios-arm64_x86_64-simulator"
  local device_lib="$device_dir/libflutterxel_core.a"
  local sim_universal_lib="$sim_dir/libflutterxel_core.a"
  local xcframework_path="$IOS_FRAMEWORKS_OUT_DIR/FlutterxelCore.xcframework"

  rm -rf "$ios_build_dir"
  mkdir -p "$device_dir" "$sim_dir" "$IOS_FRAMEWORKS_OUT_DIR"

  cp "$CORE_DIR/target/aarch64-apple-ios/release/libflutterxel_core.a" "$device_lib"

  lipo -create \
    "$CORE_DIR/target/aarch64-apple-ios-sim/release/libflutterxel_core.a" \
    "$CORE_DIR/target/x86_64-apple-ios/release/libflutterxel_core.a" \
    -output "$sim_universal_lib"

  rm -rf "$xcframework_path" \
         "$IOS_LEGACY_NATIVE_OUT_DIR/FlutterxelCore.xcframework" \
         "$IOS_LEGACY_NATIVE_OUT_DIR/libflutterxel_core.a" \
         "$IOS_LEGACY_NATIVE_OUT_DIR/build"
  xcodebuild -create-xcframework \
    -library "$device_lib" -headers "$HEADER_DIR" \
    -library "$sim_universal_lib" -headers "$HEADER_DIR" \
    -output "$xcframework_path"

  if [[ ! -d "$xcframework_path" ]]; then
    echo "Missing iOS xcframework output: $xcframework_path" >&2
    exit 1
  fi

  echo "[flutterxel_tools] iOS artifacts ready at $IOS_FRAMEWORKS_OUT_DIR"
}

if [[ "$BUILD_ANDROID" -eq 1 ]]; then
  build_android
fi
if [[ "$BUILD_IOS" -eq 1 ]]; then
  build_ios
fi

if [[ -n "$OUT_DIR" ]]; then
  echo "[flutterxel_tools] exporting artifacts to $OUT_DIR"
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"

  if [[ "$BUILD_ANDROID" -eq 1 ]]; then
    mkdir -p "$OUT_DIR/android"
    cp -R "$ANDROID_OUT_DIR" "$OUT_DIR/android/jniLibs"
  fi

  if [[ "$BUILD_IOS" -eq 1 ]]; then
    mkdir -p "$OUT_DIR/ios"
    if [[ -d "$IOS_FRAMEWORKS_OUT_DIR/FlutterxelCore.xcframework" ]]; then
      cp -R "$IOS_FRAMEWORKS_OUT_DIR/FlutterxelCore.xcframework" "$OUT_DIR/ios/"
    fi
  fi
fi

echo "[flutterxel_tools] done"
