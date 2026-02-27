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
