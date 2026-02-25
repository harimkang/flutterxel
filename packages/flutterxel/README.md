# flutterxel

Mobile-first Flutter runtime plugin for a Pyxel-compatible game engine powered by Rust over FFI.

## Phase-1 Scope

- Android/iOS runtime integration
- Dart API surface for Pyxel-like usage
- Native FFI bridge to `native/flutterxel_core`

Tooling and editor functionality is intentionally separated into `flutterxel_tools` so app dependencies remain minimal.

## Current Status

This package is scaffolded and ready for progressive implementation:

- FFI plugin packaging is configured.
- Runtime architecture and implementation plans are documented in the repository `docs/` directory.
- A Rust core ABI scaffold is present at `../../native/flutterxel_core`.

## Monorepo

The repository is organized as:

- `packages/flutterxel`
- `packages/flutterxel_tools`
- `native/flutterxel_core`

## License

MIT.

