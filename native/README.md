# native

Rust native crates and build assets for `flutterxel`.

## Crates

- `flutterxel_core`: shared runtime core exposed through a C ABI for Flutter FFI consumers.

## Notes

- Current exports provide phase-1 runtime API scope (`init/run/flip/quit/camera/clip/pal/btn/btnp/btnr/btnv/cls/pset/pget/line/rect/rectb/circ/circb/tri/trib/text/blt/play/playm/stop/load/save`).
- `.pyxres` `load/save` currently uses ZIP + `pyxel_resource.toml` handling in Rust.
- Current resource implementation supports image/tilemap/sound/music serialization round-trip and `exclude*` load/save behavior.
- Production integration will provide:
  - mobile artifact builds (`.so`, `.xcframework`)
  - stable ABI versioning policy
  - generated bindings used by `packages/flutterxel`
