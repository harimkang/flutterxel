# Flutterxel FFI Mobile Architecture

## Goal

Build a Pyxel-compatible runtime for Flutter with a Rust core over FFI, targeting mobile first (Android/iOS), while keeping tools separated from app runtime dependencies.

## Package Boundaries

- `flutterxel` (runtime plugin):
  - Dart API surface for game code
  - FFI bridge and platform integration (Texture/input/audio lifecycle)
  - Bundled native artifacts for supported mobile targets
- `flutterxel_tools` (developer tools):
  - CLI commands (`run/watch/play/edit/package/app2html`)
  - Editor UX and project tooling
  - Optional dependency on runtime for preview flows
- `native/flutterxel_core`:
  - Shared Rust engine core
  - Stable C ABI surface consumed by `flutterxel`

## Runtime Layering

1. Dart API layer:
   - Exposes Pyxel-like APIs (`init/run/btn/btnp/cls/blt/play/load/save`)
   - Keeps Flutter-facing types and lifecycle control
2. FFI bridge:
   - Maps Dart calls to C ABI functions
   - Manages pointers/handles and buffer transfer boundaries
3. Rust core:
   - Owns simulation logic, rendering buffers, audio mixing, resource format logic

Current implemented bridge includes:

- Core API skeleton: `init/run/btn/cls/blt/play/load/save`
- Runtime helper ABI: framebuffer pointer/length, frame counter, input-state bridge
- `.pyxres` compatibility: ZIP archive + `pyxel_resource.toml` format handling and image-bank round-trip in Rust core

## Rendering and Input

- Rendering:
  - Rust produces frame buffers
  - Flutter plugin presents frames through texture-based rendering integration
- Input:
  - Flutter events are normalized and forwarded to Rust key/input model
  - Mobile touch and hardware input are mapped into a single runtime input state

## Resource and Audio Strategy

- `.pyxres/.pyxpal/.pyxapp` compatibility lives in Rust for deterministic behavior across platforms.
- Audio synthesis, channel sequencing, and timing-sensitive logic remain in Rust to avoid Dart-isolate jitter.

## Distribution Model

- End users should consume `flutterxel` from pub.dev without installing Rust toolchain.
- CI builds and bundles native binaries for supported targets.
- Tooling package is versioned and distributed independently from runtime behavior changes.

## Verification Layers

1. Rust unit tests for core logic (audio, parsing, resource serialization)
2. ABI contract checks between Dart FFI and Rust exports
3. Flutter integration tests for runtime behavior
4. Smoke tests on Android/iOS examples per release
