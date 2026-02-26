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
- A Rust core runtime implementation is present at `../../native/flutterxel_core`.
- Runtime API skeleton includes `init/run/btn/cls/blt/play/load/save`.
- Native artifact layout for prebuilt Rust binaries is documented at `native/README.md`.

## Native Artifact Bundling

For release builds without requiring end-user Rust toolchains:

- Android prebuilt `.so` files: `native/android/jniLibs/<abi>/libflutterxel_core.so`
- iOS prebuilt xcframework: `native/ios/FlutterxelCore.xcframework`

Runtime loading prefers `flutterxel_core` and falls back to `flutterxel` scaffold library.

## Monorepo

The repository is organized as:

- `packages/flutterxel`
- `packages/flutterxel_tools`
- `native/flutterxel_core`

## License

MIT.
