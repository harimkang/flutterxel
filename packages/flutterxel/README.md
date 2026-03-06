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
- Runtime API skeleton includes `init/run/flip/quit/camera/clip/pal/btn/btnp/btnr/btnv/cls/pset/pget/line/rect/rectb/circ/circb/tri/trib/text/blt/play/playm/stop/load/save`.
- `load/save` uses `.pyxres` ZIP archives with `pyxel_resource.toml` (`format_version <= 4`) in Rust core.
- Image bank/tilemap/sound/music resource data round-trip and `exclude*` semantics are handled in Rust.
- Native artifact layout for prebuilt Rust binaries is documented at `native/README.md`.

## Native Artifact Bundling

For release builds without requiring end-user Rust toolchains:

- Android prebuilt `.so` files: `native/android/jniLibs/<abi>/libflutterxel_core.so`
- iOS prebuilt xcframework: `ios/Frameworks/FlutterxelCore.xcframework`

Runtime loading prefers `flutterxel_core` and falls back to `flutterxel` scaffold library.

Tag releases (`v*`) publish prebuilt native bundles via GitHub Actions, including a package-overlay archive that can be extracted directly into `packages/flutterxel`.

Release tags also trigger `.github/workflows/publish_dry_run.yml`, which validates package versions against the tag and runs `pub publish --dry-run` for monorepo packages.

Pre-tag metadata checks run in `.github/workflows/release_readiness.yml` (versions and CHANGELOG headings).

## Runtime Loop and View

```dart
import 'package:flutterxel/flutterxel.dart' as flutterxel;

void main() {
  flutterxel.init(160, 120, fps: 60);
  flutterxel.run(() {
    // update
  }, () {
    flutterxel.cls(0);
    flutterxel.blt(8, 8, 0, 0, 0, 16, 16, colkey: 2);
  });
}
```

Render with:

```dart
const flutterxel.FlutterxelView(pixelScale: 3)
```

`FlutterxelView` captures input by default:

- pointer/touch -> `MOUSE_BUTTON_LEFT`
- arrow keys -> `KEY_LEFT/KEY_RIGHT/KEY_UP/KEY_DOWN`
- `space/enter/escape` -> `KEY_SPACE/KEY_RETURN/KEY_ESCAPE`

## Runtime Palette Size (`num_colors` / `numColors`)

`init(...)` now supports runtime palette size selection:

- supported: `16`, `64`, `256`
- default: `16` (backward compatible)
- constants: `DEFAULT_NUM_COLORS`, `MAX_NUM_COLORS`, `SUPPORTED_NUM_COLORS`

Example:

```dart
flutterxel.init(160, 120, num_colors: 64);
// or
flutterxel.init(160, 120, numColors: 256);
```

Read the current runtime value via:

- `flutterxel.numColors`
- `flutterxel.num_colors`

When `FlutterxelView.palette` is omitted, the view now selects a deterministic
default palette for the active runtime color count (`16/64/256`).
You can still pass a custom palette explicitly:

```dart
flutterxel.FlutterxelView(
  pixelScale: 3,
  palette: flutterxel.defaultPaletteForNumColors(256),
)
```

If you see `flutterxel_core_set_num_colors` / `flutterxel_core_num_colors`
missing-symbol errors on native backend, rebuild/bundle native artifacts for the
same commit as the Dart package update.

## Color Mode (`color_mode` / `colorMode`)

`init(...)` also supports runtime color mode selection:

- `COLOR_MODE_INDEXED` (default): palette-index rendering
- `COLOR_MODE_TRUECOLOR`: direct `0xRRGGBB` rendering

Example:

```dart
flutterxel.init(
  160,
  120,
  color_mode: flutterxel.COLOR_MODE_TRUECOLOR,
);

flutterxel.cls(flutterxel.rgb24(4, 8, 16));
flutterxel.pset(8, 8, 0x12AB34);
```

Runtime helpers:

- `flutterxel.colorMode`
- `flutterxel.color_mode`
- `flutterxel.isTruecolor`
- `flutterxel.rgb24(r, g, b)`

Behavior differences by mode:

- indexed mode uses `num_colors` and `pal()`
- truecolor mode rejects `num_colors` on `init(...)`
- truecolor mode keeps raster-import RGB24 values without palette quantization
- truecolor mode treats `pal()`, `load_pal()`, and `save_pal()` as no-ops

Migration checklist:

- Leave `init(...)` unchanged to stay on indexed mode
- Add `colorMode: flutterxel.COLOR_MODE_TRUECOLOR` only for raw RGB rendering
- Convert palette-index literals that should be actual colors to `0xRRGGBB`
- Remove `num_colors` from truecolor initializers

## Test Backend Forcing

For deterministic backend-path regression tests, runtime loading supports:

- `FLUTTERXEL_FORCE_BACKEND`: `native_core`, `c_fallback`, `dart_fallback`
- `FLUTTERXEL_LIBRARY_OVERRIDE`: absolute shared-library path to load first

Example for forced `c_fallback` tests on host:

```bash
HOST_LIB="$(./tool/build_c_scaffold_host.sh)"
FLUTTERXEL_FORCE_BACKEND=c_fallback \
FLUTTERXEL_LIBRARY_OVERRIDE="$HOST_LIB" \
flutter test test/flutterxel_api_surface_test.dart --plain-name "forced c fallback mode"
```

## Monorepo

The repository is organized as:

- `packages/flutterxel`
- `packages/flutterxel_tools`
- `native/flutterxel_core`

## License

MIT.
Upstream attribution for Pyxel compatibility work: https://github.com/harimkang/flutterxel/blob/main/THIRD_PARTY_NOTICES.md
