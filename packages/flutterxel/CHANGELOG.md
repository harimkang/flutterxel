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
