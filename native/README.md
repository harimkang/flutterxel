# native

Rust native crates and build assets for `flutterxel`.

## Crates

- `flutterxel_core`: shared runtime core exposed through a C ABI for Flutter FFI consumers.

## Notes

- Current exports are scaffolding-level placeholders.
- Production integration will provide:
  - mobile artifact builds (`.so`, `.xcframework`)
  - stable ABI versioning policy
  - generated bindings used by `packages/flutterxel`

