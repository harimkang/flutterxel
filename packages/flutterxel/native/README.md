# Native Artifact Layout

`flutterxel` can load Rust core artifacts from this directory when prebuilt binaries are bundled.

## Android

Place per-ABI shared libraries under:

- `native/android/jniLibs/arm64-v8a/libflutterxel_core.so`
- `native/android/jniLibs/armeabi-v7a/libflutterxel_core.so`
- `native/android/jniLibs/x86_64/libflutterxel_core.so`

## iOS

Prefer xcframework packaging:

- `native/ios/FlutterxelCore.xcframework`

Alternative static library packaging (advanced):

- `native/ios/libflutterxel_core.a`

## Runtime Loading Priority

The Dart runtime attempts to load `flutterxel_core` first and falls back to the C scaffold library `flutterxel`.
