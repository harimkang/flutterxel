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
