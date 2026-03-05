## 0.0.10

- Added native tilemap mutation/query ABI sync (`tilemap_pset/pget/cls/set_imgsrc`) and wired resource `Tilemap` mutation paths to native state.
- Removed Rust `blt`/`bltm` clone and temporary-allocation hotspots in render hot paths.
- Added bulk image replacement ABI (`flutterxel_core_image_replace`) and switched resource image bulk writes to deferred single-flush sync.
- Added framebuffer bulk-copy ABI (`flutterxel_core_copy_framebuffer`) and reduced Flutter view painter allocation overhead with paint caching.
- Added regression coverage for resource tilemap/image native sync paths, including non-zero tile coordinate sync.
- Fixed resource tilemap sync parity for non-zero tile coordinates by aligning native tilemap default/normalized bounds with runtime expectations.
- Fixed `Tilemap.imgsrc` setter to preserve object state when invalid input or native sync failure occurs.

## 0.0.9

- Fixed native core default image bank capacity to initialize/reset at `256` so multi-row sprite-sheet coordinates remain valid in native mode.
- Optimized native `blt` sampling to avoid per-call full source bank cloning while preserving safe copy semantics.
- Added native regression coverage for image-bank pixel writes at row indices beyond `16`.
- Optimized Flutter view rendering by reusing a native frame buffer snapshot and batching horizontal same-color pixel runs into single draw calls.

## 0.0.8

- Fixed iOS backend fallback shadowing by removing C fallback symbol exports from `ios/Classes/flutterxel.c`.
- Moved bundled iOS native core artifact path to:
  - `ios/Frameworks/FlutterxelCore.xcframework`
- Updated iOS pod integration to vendor the xcframework directly and force-load static library slices to avoid linker stripping.
- Updated Dart runtime native loader on iOS to try explicit library opens before `DynamicLibrary.process()`.
- Refreshed bundled native artifacts with rebuilt Android `.so` files and iOS xcframework slices.

## 0.0.7

- Fixed C fallback image bank capacity regression by setting `DEFAULT_IMAGE_BANK_SIZE` to `256` for sprite-sheet addressing compatibility.
- Added `image_bank_size_regression_test.dart` to lock:
  - resource image pixel writes at y-coordinates used by multi-row sprite sheets
  - `blt` sampling across frame widths larger than `16px`
- Bundled release native artifacts in package layout:
  - `native/android/jniLibs/{arm64-v8a,armeabi-v7a,x86_64}/libflutterxel_core.so`
  - `native/ios/FlutterxelCore.xcframework`
  - `native/ios/libflutterxel_core.a`

## 0.0.6

- Added backend discriminator ABI integration and fail-closed backend mode resolution:
  - `BackendMode`
  - `Flutterxel.backendMode`
  - `Flutterxel.supportsNativeBltSourceSelection`
- Added deterministic fallback forcing controls for test environments:
  - `FLUTTERXEL_FORCE_BACKEND`
  - `FLUTTERXEL_LIBRARY_OVERRIDE`
- Fixed C fallback rendering contract mismatches:
  - `blt` now honors `img` image bank selection
  - `bltm` now honors `tm` tilemap source selection
- Added opt-in alpha-aware import options on `Image.load` and `Image.fromImage`:
  - `preserve_transparent` / `preserveTransparent`
  - `transparent_index` / `transparentIndex`
  - `alpha_threshold` / `alphaThreshold`
- Clarified `include_colors` semantics and added test coverage to lock behavior.
- Added Agent Map MVP example components under `example/agent_map` with parser, state machine, renderer, and activity feed adapter tests.

## 0.0.5

- Added native core image-resource mutation ABI integration for `Image` resources:
  - `flutterxel_core_image_pset`
  - `flutterxel_core_image_pget`
  - `flutterxel_core_image_cls`
- Fixed resource image synchronization gap in native-binding mode so `images[n].pset/cls/load/set` updates are reflected by subsequent global `blt(...)`.
- Added native-path regression tests covering resource-image `pset` and `load` reflection through global `blt(...)`.
- Updated ABI version to `0.4.0` for the expanded C ABI surface.

## 0.0.4

- Added TMX import support in `Tilemap.fromTmx`/`from_tmx` for square tile sizes that are integer multiples of `8` (including `16x16`).
- Added TMX tile normalization so imported larger tiles are expanded into internal `8x8` tile coordinates.
- Added TMX validation for unsupported tile sizes (non-positive, non-square, or not divisible by `8`).
- Added regression tests for `16x16` normalization and invalid-size rejection.

## 0.0.3

- Added PNG binary decoding support for `Image.fromImage` and `Image.load`.
- Added palette-quantized color mapping when importing raster images in fallback/runtime path.
- Added regression tests for PNG decode behavior (dimensions, palette mapping, and offset load).

## 0.0.2

- Hardened native binding loading and fallback/runtime reset behavior.
- Improved API surface stability with expanded regression test coverage.
- Updated `tool/check_abi_contract.sh` to work even when `rg` is not installed.

## 0.0.1

* TODO: Describe initial release.
