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
