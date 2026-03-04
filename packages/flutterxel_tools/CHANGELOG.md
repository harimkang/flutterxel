## 0.0.9

- No functional CLI/tooling behavior changes in this release.
- Updated release metadata to align workspace/package versions with `flutterxel` `0.0.9`.

## 0.0.8

- Updated native artifact build script output layout for iOS to:
  - `packages/flutterxel/ios/Frameworks/FlutterxelCore.xcframework`
- Updated iOS xcframework packaging to emit consistent slice library names for CocoaPods compatibility.
- Updated release workflow artifact paths and overlay packaging to match the new iOS framework location.
- Updated release metadata to align workspace/package versions with `flutterxel` `0.0.8`.

## 0.0.7

- No functional CLI behavior changes in this release.
- Updated release metadata to align workspace/package versions with `flutterxel` `0.0.7`.

## 0.0.6

- No functional CLI/tooling behavior changes in this release.
- Updated release metadata to align workspace/package versions with `flutterxel` `0.0.6`.
- Maintainer release path is CI dry-run validation on tag plus manual pub.dev publish.

## 0.0.5

- Added CI publish workflow support for tagged releases to publish `flutterxel` and `flutterxel_tools` to pub.dev.
- Updated release metadata to align workspace/package versions with `flutterxel` `0.0.5`.

## 0.0.4

- No functional tooling changes in this release.
- Version updated to keep workspace/package release metadata aligned with `flutterxel` `0.0.4`.

## 0.0.3

- Added `pixel-snap` CLI command for asset preprocessing from raw images to palette-quantized pixel-art output.
- Added `packages/flutterxel_tools/tool/pixel_snap_image.sh` wrapper that runs the vendored SpriteFusion reference implementation via Cargo.
- Added argument validation and forwarding for `--input`, `--output`, `--colors`, and `--overwrite`.
- Added command coverage tests and usage/help updates for command discoverability.

## 0.0.2

- No functional package code changes in this release.
- Version updated to keep workspace/package release metadata aligned.

## 0.0.1

* TODO: Describe initial release.
