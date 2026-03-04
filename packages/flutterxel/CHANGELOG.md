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
