# Constants and Compatibility

## Exported Constant Surface

`flutterxel` re-exports Pyxel-style constants from:

- `packages/flutterxel/lib/src/pyxel_constants.dart`

This includes:

- color constants
- runtime palette constants (`NUM_COLORS`, `DEFAULT_NUM_COLORS`, `MAX_NUM_COLORS`, `SUPPORTED_NUM_COLORS`)
- `MAX_COLORS` (kept as max color-index compatibility alias: `255`)
- keyboard/mouse constants
- resource sizing constants (`IMAGE_SIZE`, `TILE_SIZE`, etc.)
- audio constants

## Naming Compatibility

The package keeps both naming styles where implemented:

- camelCase (`frameCount`, `loadPal`, `playPos`, ...)
- snake_case aliases (`frame_count`, `load_pal`, `play_pos`, ...)

Runtime palette options keep both styles as well:

- `init(..., num_colors: 64)` / `init(..., numColors: 64)`
- `flutterxel.num_colors` / `flutterxel.numColors`

This helps port Pyxel-like code while keeping idiomatic Dart usage available.

For image import options, compatibility aliases are also available:

- `include_colors` / `includeColors`
- `use_discovered_palette` / `useDiscoveredPalette`
- `transparent_index` / `transparentIndex`
- `alpha_threshold` / `alphaThreshold`
- `preserve_transparent` / `preserveTransparent`

## Runtime Palette Count Compatibility

- Legacy behavior is unchanged when `num_colors` is omitted (`16` colors).
- Supported runtime palette counts are currently limited to `16`, `64`, `256`.
- Native core and C fallback both enforce this contract via ABI (`set/get num_colors`).
- `pal`, `load_pal`, and `save_pal` now respect runtime palette count rather than fixed `16`.
- `FlutterxelView` default palette selection also follows runtime palette count when `palette` is not provided.

## Text and Built-in Font

Built-in text uses a 4x6 pixel font (`FONT_WIDTH = 4`, `FONT_HEIGHT = 6`) and now renders glyph shapes consistently in both native and fallback paths.

Behavior summary:

- ASCII code points 32..127 are rendered.
- newline is supported.
- unsupported code points are skipped.

## `blt` Source Contract

- Global `blt(...)` accepts image resource ids (`int`), resource-backed `Image` objects, and detached `Image` objects.
- Detached `Image(...)` / `Image.fromImage(...)` / `Image.fromBytes(...)` sources use the compatibility screen-local blit path.
- Resource-image mutations in native mode (`pset`, `cls`, `set`, `load`) are synchronized to the native core image bank used by global `blt(...)`.

## Runtime Backend Mode and Capabilities

- `Flutterxel.backendMode` exposes runtime backend selection:
  - `BackendMode.native_core`
  - `BackendMode.c_fallback`
  - `BackendMode.dart_fallback`
- `Flutterxel.supportsNativeBltSourceSelection` is derived from `backendMode` and is `true` only on `native_core`.
- If native bindings load but `flutterxel_core_backend_kind` is missing, backend resolution fails closed with an explicit ABI mismatch error (no heuristic fallback classification).

Backend-branching example:

```dart
switch (Flutterxel.backendMode) {
  case BackendMode.native_core:
    // Full native path
    break;
  case BackendMode.c_fallback:
    // Use compatibility-safe rendering path
    break;
  case BackendMode.dart_fallback:
    // Keep runtime-light behavior only
    break;
}

final supportsFastPath = Flutterxel.supportsNativeBltSourceSelection;
```
