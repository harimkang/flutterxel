# Game Loop and Rendering

## Runtime Lifecycle

Core entry points:

- `init(width, height, ...)`
- `run(update, draw)`
- `flip()`
- `show()`
- `quit()`
- `reset()`

`run(update, draw)` calls `update`, then `draw`, then `flip` on a timer.

Use `show()` when you need a frame-advance call outside `run`.

## Drawing APIs

Primary screen-space drawing functions:

- `cls`, `pset`, `pget`
- `line`
- `rect`, `rectb`
- `circ`, `circb`
- `elli`, `ellib`
- `tri`, `trib`
- `fill`
- `text`
- `blt`, `bltm`

## Camera, Clip, and Palette

- `camera(x, y)` shifts drawing coordinates.
- `clip(x, y, w, h)` constrains drawing writes.
- `pal(col1, col2)` remaps palette colors (or resets mapping when called without args).
- `dither(alpha)` sets runtime dithering state.

## Text Behavior

`text(x, y, s, col)` renders the built-in 4x6 glyph set.

- Newline (`\n`) moves to the next text row.
- ASCII code points 32..127 are rendered.
- Out-of-range characters are skipped.

## Rendering in Flutter

Use `FlutterxelView` in your widget tree.

Common options:

- `pixelScale`
- `palette`
- `backgroundColor`
- `captureInput`
- `keyboardMapping`

`FlutterxelView` repaints from `frameBufferSnapshot()` updates.
