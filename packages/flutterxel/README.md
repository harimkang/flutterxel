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
- Runtime API skeleton includes `init/run/flip/quit/btn/btnp/btnr/btnv/cls/blt/play/playm/stop/load/save`.
- `load/save` uses `.pyxres` ZIP archives with `pyxel_resource.toml` (`format_version <= 4`) in Rust core.
- Image bank/tilemap/sound/music resource data round-trip and `exclude*` semantics are handled in Rust.
- Native artifact layout for prebuilt Rust binaries is documented at `native/README.md`.

## Native Artifact Bundling

For release builds without requiring end-user Rust toolchains:

- Android prebuilt `.so` files: `native/android/jniLibs/<abi>/libflutterxel_core.so`
- iOS prebuilt xcframework: `native/ios/FlutterxelCore.xcframework`

Runtime loading prefers `flutterxel_core` and falls back to `flutterxel` scaffold library.

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

## Monorepo

The repository is organized as:

- `packages/flutterxel`
- `packages/flutterxel_tools`
- `native/flutterxel_core`

## License

MIT.
