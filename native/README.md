# native

Rust native crates and build assets for `flutterxel`.

## Crates

- `flutterxel_core`: shared runtime core exposed through a C ABI for Flutter FFI consumers.

## Notes

- Current exports provide phase-1 runtime API scope (`init/run/btn/cls/blt/play/load/save`).
- `.pyxres` `load/save` currently uses ZIP + `pyxel_resource.toml` baseline handling in Rust.
- Production integration will provide:
  - mobile artifact builds (`.so`, `.xcframework`)
  - stable ABI versioning policy
  - generated bindings used by `packages/flutterxel`
