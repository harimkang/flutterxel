## 0.0.8

- Fixed iOS backend symbol shadowing by replacing `ios/Classes/flutterxel.c` with a stub translation unit so `flutterxel_core_*` is no longer exported from the plugin binary.
- Repackaged iOS Rust core outputs to `packages/flutterxel/ios/Frameworks/FlutterxelCore.xcframework` with a consistent static library name (`libflutterxel_core.a`) across device and simulator slices.
- Updated iOS loading/linking integration:
  - podspec now vendors `ios/Frameworks/FlutterxelCore.xcframework` and force-loads slice libraries
  - Dart loader now defers `DynamicLibrary.process()` to last on iOS
- Updated CI native artifact packaging and docs to match the new iOS framework location.
- Rebuilt and bundled release native artifacts for Android and iOS.

## 0.0.7

- Fixed C fallback image bank capacity to match sprite-sheet scale usage by restoring `DEFAULT_IMAGE_BANK_SIZE` to `IMAGE_SIZE` (`256`).
- Added regression coverage for high-coordinate image-bank writes and frame-width sampling beyond `16px` in `image_bank_size_regression_test.dart`.
- Bundled prebuilt Rust native artifacts into `packages/flutterxel/native` for release packaging:
  - Android: `jniLibs` (`arm64-v8a`, `armeabi-v7a`, `x86_64`)
  - iOS: `FlutterxelCore.xcframework` and `libflutterxel_core.a`
- Updated release/docs metadata for `0.0.7`.

## 0.0.6

- Added backend discriminator ABI contract (`flutterxel_core_backend_kind`) and tightened ABI parity checks across native header, plugin header, and generated Dart bindings.
- Added runtime backend introspection API (`BackendMode`, `Flutterxel.backendMode`) and capability surface (`Flutterxel.supportsNativeBltSourceSelection`) with fail-closed ABI mismatch handling.
- Added deterministic fallback test forcing with `FLUTTERXEL_FORCE_BACKEND` and `FLUTTERXEL_LIBRARY_OVERRIDE`, plus host C scaffold helper script for reproducible fallback regressions.
- Fixed C fallback source-selection mismatches so `blt` honors `img` and `bltm` honors `tm`.
- Added opt-in alpha-aware image import policy for `Image.load`/`Image.fromImage` and documented transparent-index + `colkey` usage.
- Clarified and test-locked `include_colors` semantics, including explicit alias guidance.
- Added Flutterxel agent-map MVP pipeline in example app (character manifest ingestion, zone state machine, renderer/controller, JSONL activity feed adapter) with test coverage and docs.
- CI release workflow now uses tag-triggered dry-run validation (`publish_dry_run.yml`) before manual pub.dev publish.

## 0.0.5

- Fixed native rendering mismatch where resource-image mutations (`images[n].pset/cls/load/set`) were not reflected by global `blt(...)` in native-binding mode.
- Added explicit image mutation/read ABI (`flutterxel_core_image_pset`, `flutterxel_core_image_pget`, `flutterxel_core_image_cls`) across core/header/FFI bindings.
- Added regression tests for resource image sync behavior on native path.
- Added CI workflow for pub.dev release publishing on `v*` tags: `.github/workflows/publish_pub_dev.yml`.
- Updated compatibility/docs notes for `blt` source contract and ASCII-only built-in text behavior.

## 0.0.4

- Added `Tilemap.fromTmx`/`from_tmx` support for TMX tile sizes that are square integer multiples of `8` (for example `16x16`).
- Added internal normalization from larger TMX tiles to flutterxel's `8x8` tile grid to preserve existing runtime rendering/collision behavior.
- Added regression coverage for normalized `16x16` imports and invalid (non-divisible) tile-size rejection.
- Updated release and installation docs for `0.0.4`.

## 0.0.3

- Added tooling-side image preprocessing with `flutterxel_tools pixel-snap`.
- Added docs for pixel-snap usage in package README, repository README, and docs site guides.
- Added release notes page for `v0.0.3`.
- Fixed runtime PNG loading in `flutterxel.Image.fromImage`/`Image.load` with palette quantization.

## 0.0.2

- Added four polished game examples under `examples/`:
  - `star_patrol` (top-down shooter)
  - `pixel_puzzle` (puzzle)
  - `void_runner` (runner)
  - `cosmic_survivor` (survival shooter)
- Hardened runtime behavior in `flutterxel`:
  - improved native binding/runtime fallback handling
  - strengthened runtime state reset behavior
  - expanded API surface regression coverage
- Fixed ABI contract check script compatibility when `rg` is unavailable.
- Added a full documentation site setup in `docs/` with:
  - MkDocs structure and authored guides
  - auto-generated API docs via `dart doc`
  - manual GitHub Pages deployment workflow (`workflow_dispatch`)
- Updated repository ignore rules and cleanup changes.

## 0.0.1

- Initial monorepo bootstrap for Flutter + Rust porting effort based on Pyxel.
- Added Flutter runtime plugin (`flutterxel`) and tooling package (`flutterxel_tools`).
- Added Rust FFI core and compatibility-focused API/resource implementation progress.
