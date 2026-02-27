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

`Tilemap` supports:

- tile read/write and draw helpers
- TMX import via `fromTmx(...)`
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
