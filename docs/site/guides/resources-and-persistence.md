# Resources and Persistence

## Resource Containers

Global resource collections:

- `images`
- `tilemaps`
- `sounds`
- `musics`

They are exposed through `Seq<T>` wrappers for Pyxel-style mutation.

## Image and Tilemap

`Image` supports drawing and data manipulation methods (for both detached and resource-backed use):

- `pset`, `pget`, `line`, `rect`, `circ`, `elli`, `tri`, `fill`
- `blt`, `bltm`, `text`
- `set`, `load`, `save`
- `clip`, `camera`, `pal`, `dither`

Important behavior boundaries:

- Global `blt(...)` accepts only image resource ids (`int`) or resource-backed `Image` handles (for example `images[0]`).
- Detached images created with `Image(...)` / `Image.fromImage(...)` are not valid as global `blt` source arguments.
- Use `image.blt(...)` when drawing from detached image objects.
- In native-binding mode, resource image mutations (`pset`, `cls`, `set`, `load`) now sync directly to native core image banks, so subsequent global `blt(...)` draws reflect those updates.
- `Image.load(...)` / `Image.fromImage(...)` keep legacy alpha-agnostic mapping by default.
- `include_colors` / `includeColors` uses a local discovered-palette mapping:
  - first discovered color maps to index `0`
  - next discovered color maps to `1`, and so on
  - mapping is local to each load call (not a global palette replacement)
- clearer alias: `use_discovered_palette` / `useDiscoveredPalette` (same behavior as `include_colors`)
- Optional alpha-aware import is available with:
  - `preserve_transparent` / `preserveTransparent`
  - `transparent_index` / `transparentIndex`
  - `alpha_threshold` / `alphaThreshold` (`0..255`)
- Transparent sprite recipe:
  - load with `preserve_transparent: true, transparent_index: <index>, alpha_threshold: <threshold>`
  - draw with `blt(..., colkey: <same index>)` to skip transparent background pixels

```dart
// Resource image import (alpha-aware opt-in)
images[0].load(
  0,
  0,
  'assets/characters/dude/dude_sheet.png',
  preserve_transparent: true,
  transparent_index: COLOR_BLACK,
  alpha_threshold: 0,
);

// Draw using the same transparent index as colkey
blt(16, 24, 0, 0, 0, 32, 32, colkey: COLOR_BLACK);
```

### `include_colors` Usage Guide

| Goal | Recommended option |
|---|---|
| Keep Pyxel-like default nearest-color behavior | omit `include_colors` |
| Build compact local palette indices from imported pixels | `include_colors: true` (or `use_discovered_palette: true`) |
| Import alpha-cutout sprites for `blt(colkey: ...)` | `preserve_transparent: true` + `transparent_index` + `alpha_threshold` |

`Tilemap` supports:

- tile read/write and draw helpers
- TMX import via `fromTmx(...)` (supports `8x8` and square multiples of `8`, normalized internally to `8x8`)
- tilemap `set(...)`, `load(...)`, `save(...)`

## Runtime Resource File I/O

Runtime-level file I/O APIs:

- `load(filename, excludeImages: ..., excludeTilemaps: ..., excludeSounds: ..., excludeMusics: ...)`
- `save(filename, excludeImages: ..., excludeTilemaps: ..., excludeSounds: ..., excludeMusics: ...)`

Important behavior:

- `load` and `save` require native flutterxel core bindings.
- If bindings are unavailable, these functions throw `UnsupportedError`.

## Palette and Capture

- `loadPal(filename)` / `savePal(filename)`
- `screenshot(scale: ...)`
- `screencast(scale: ...)`
- `resetScreencast()`

## App Data Directory

- `userDataDir(vendorName, appName)` returns (and creates) a writable per-app directory.

## Asset Preprocessing

Before loading external image assets at runtime, preprocess them with the tooling command described in:

- [Pixel Snap Asset Preprocessing](pixel-snap-asset-preprocessing.md)
