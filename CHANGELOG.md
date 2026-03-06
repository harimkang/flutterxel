## Unreleased

## 0.0.13

- Added agent-map/editor-friendly rendering primitives to `flutterxel`:
  - bytes-based detached image loading (`Image.fromBytes`, `image.loadBytes`)
  - global detached-image `blt(...)`
  - destination-rect nearest-neighbor blits (`bltEx`, `Image.bltEx`)
  - `FlutterxelView.onPointerSample`
- Updated release metadata and docs for `0.0.13`.

## 0.0.12

- Added runtime `truecolor` (`0xRRGGBB`) mode across Rust core, C fallback, Dart API, raster import, and `FlutterxelView`.
- Added ABI symbols for runtime color mode control:
  - `flutterxel_core_set_color_mode`
  - `flutterxel_core_color_mode`
- Added Dart API/runtime helpers:
  - `init(..., color_mode / colorMode)`
  - `flutterxel.colorMode` / `flutterxel.color_mode`
  - `flutterxel.isTruecolor`
  - `flutterxel.rgb24(...)`
- Updated mode-specific behavior:
  - indexed mode keeps palette mapping and `num_colors`
  - truecolor mode preserves RGB24 framebuffer/import values
  - truecolor mode treats `pal`, `load_pal`, and `save_pal` as no-ops
- Updated release metadata to align workspace/package versions with `flutterxel` `0.0.12`.

## 0.0.11

- Added runtime `num_colors` expansion (`16/64/256`) end-to-end across Rust core, C fallback, Dart API, and Flutter view rendering.
- Added ABI symbols for runtime palette count control:
  - `flutterxel_core_set_num_colors`
  - `flutterxel_core_num_colors`
- Added Dart API/runtime compatibility surface:
  - `init(..., num_colors / numColors)`
  - `flutterxel.num_colors` / `flutterxel.numColors`
- Updated palette-related behavior to be runtime-count aware:
  - `pal`
  - `load_pal`
  - `save_pal`
  - discovered-palette import path
- Updated `FlutterxelView` default palette strategy for runtime `64/256` color modes.
- Rebuilt and refreshed bundled Android/iOS native artifacts for the ABI expansion.
- Added regression tests for runtime `num_colors` API contract and rendering/palette compatibility paths.
- Updated release metadata to align workspace/package versions with `flutterxel` `0.0.11`.

## 0.0.10

- Added native tilemap mutation/query ABI sync (`tilemap_pset/pget/cls/set_imgsrc`) and wired resource `Tilemap` mutation paths to native state.
- Removed Rust `blt`/`bltm` clone and temporary-allocation hotspots in render hot paths.
- Added bulk image replacement ABI (`flutterxel_core_image_replace`) and switched resource image bulk writes to deferred single-flush sync.
- Added framebuffer bulk-copy ABI (`flutterxel_core_copy_framebuffer`) and reduced Flutter view painter allocation overhead with paint caching.
- Added regression coverage for resource tilemap/image native sync paths, including non-zero tile coordinate sync.
- Fixed resource tilemap sync parity for non-zero tile coordinates by aligning native tilemap default/normalized bounds with runtime expectations.
- Fixed `Tilemap.imgsrc` setter to preserve object state when invalid input or native sync failure occurs.
- Updated release metadata to align workspace/package versions with `flutterxel` `0.0.10`.

## 0.0.9

- Fixed native core default image bank capacity to initialize/reset at `256` so multi-row sprite-sheet coordinates remain valid in native mode.
- Optimized native `blt` sampling to avoid per-call full source bank cloning while preserving safe copy semantics.
- Added native regression coverage for image-bank pixel writes at row indices beyond `16`.
- Optimized Flutter view rendering by reusing a native frame buffer snapshot and batching horizontal same-color pixel runs into single draw calls.
- Updated release metadata to align workspace/package versions with `flutterxel` `0.0.9`.

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
