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

## Maintainer Build Command

From repository root:

```bash
./packages/flutterxel_tools/tool/build_rust_core_artifacts.sh --all
```

Or via CLI:

```bash
dart run flutterxel_tools:flutterxel_tools build-native --all
```

## Release Artifacts

On tag push (`v*`), GitHub Actions `native-artifacts` publishes two assets:

- `flutterxel-native-artifacts.tgz`: platform-split bundle (`android/`, `ios/`)
- `flutterxel-native-package-overlay.tgz`: direct overlay for repository/package layout (`packages/flutterxel/native/...`)

To apply the overlay archive in a release branch:

```bash
tar -xzf flutterxel-native-package-overlay.tgz -C .
```
