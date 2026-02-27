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
