# Constants and Compatibility

## Exported Constant Surface

`flutterxel` re-exports Pyxel-style constants from:

- `packages/flutterxel/lib/src/pyxel_constants.dart`

This includes:

- color constants
- keyboard/mouse constants
- resource sizing constants (`IMAGE_SIZE`, `TILE_SIZE`, etc.)
- audio constants

## Naming Compatibility

The package keeps both naming styles where implemented:

- camelCase (`frameCount`, `loadPal`, `playPos`, ...)
- snake_case aliases (`frame_count`, `load_pal`, `play_pos`, ...)

This helps port Pyxel-like code while keeping idiomatic Dart usage available.

## Text and Built-in Font

Built-in text uses a 4x6 pixel font (`FONT_WIDTH = 4`, `FONT_HEIGHT = 6`) and now renders glyph shapes consistently in both native and fallback paths.

Behavior summary:

- ASCII code points 32..127 are rendered.
- newline is supported.
- unsupported code points are skipped.

## `blt` Source Contract

- Global `blt(...)` accepts image resource ids (`int`) or resource-backed `Image` objects.
- Detached `Image(...)` / `Image.fromImage(...)` objects should be used via `image.blt(...)`.
- Resource-image mutations in native mode (`pset`, `cls`, `set`, `load`) are synchronized to the native core image bank used by global `blt(...)`.

## Runtime Backend Mode and Capabilities

- `Flutterxel.backendMode` exposes runtime backend selection:
  - `BackendMode.native_core`
  - `BackendMode.c_fallback`
  - `BackendMode.dart_fallback`
- `Flutterxel.supportsNativeBltSourceSelection` is derived from `backendMode` and is `true` only on `native_core`.
- If native bindings load but `flutterxel_core_backend_kind` is missing, backend resolution fails closed with an explicit ABI mismatch error (no heuristic fallback classification).
