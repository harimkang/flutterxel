# Native Artifact Layout

`flutterxel` can load Rust core artifacts from this directory when prebuilt binaries are bundled.

## Android

Place per-ABI shared libraries under:

- `native/android/jniLibs/arm64-v8a/libflutterxel_core.so`
- `native/android/jniLibs/armeabi-v7a/libflutterxel_core.so`
- `native/android/jniLibs/x86_64/libflutterxel_core.so`

## iOS

Use xcframework packaging under the plugin iOS directory:

- `ios/Frameworks/FlutterxelCore.xcframework`

## Runtime Loading Priority

The Dart runtime attempts native-core loading first.

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
- `flutterxel-native-package-overlay.tgz`: direct overlay for repository/package layout
  - Android: `packages/flutterxel/native/android/...`
  - iOS: `packages/flutterxel/ios/Frameworks/...`

To apply the overlay archive in a release branch:

```bash
tar -xzf flutterxel-native-package-overlay.tgz -C .
```
