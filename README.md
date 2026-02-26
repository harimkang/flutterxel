# flutterxel

`flutterxel` is a **Pyxel-compatible runtime and tooling monorepo** built with:

- **Rust core** (`native/flutterxel_core`)
- **Flutter API/plugin layer** (`packages/flutterxel`)
- **Tooling package** (`packages/flutterxel_tools`)

This codebase is a Flutter + Rust porting effort based on the Pyxel project:

- Upstream reference: https://github.com/kitao/pyxel

The goal is high Pyxel API/resource compatibility with a mobile-first Flutter developer experience.

## Project Status

Current status: **active implementation, mobile-first runtime path ready, compatibility surface expanded heavily**.

Implemented so far includes:

- Monorepo/workspace bootstrap with Dart workspace + Melos
- Rust core C ABI and Dart FFI bindings
- Flutter plugin runtime structure for Android/iOS
- Pyxel-style public API surface (camelCase + snake_case aliases)
- Large compatibility constant set (`VERSION`, key/mouse/gamepad constants, palette constants, etc.)
- Runtime loop and frame lifecycle (`init/run/flip/show/quit/reset`)
- Input bridge APIs (`btn/btnp/btnr/btnv`, mouse position/wheel, text/files mirror)
- Drawing primitives and transforms (`cls/pset/pget/line/rect/rectb/circ/circb/elli/ellib/tri/trib/fill/text/blt/bltm`)
- Camera/clip/palette/dither behavior in runtime fallback and core paths
- Resource objects and compatibility modeling:
  - `Image`, `Tilemap`, `Sound`, `Music`, `Tone`, `Channel`, `Seq`
  - Tilemap operations (`set`, `load`, `from_tmx`, `blt`, `collide`)
  - Image/tilemap raw pointer snapshots for core interop testing
- Audio compatibility work:
  - `play/playm/stop/play_pos` including Pyxel-like signatures
  - `Sound`/`Music` mutation sync over FFI (`sound_set_*`, `music_set_seq`)
  - playback progress tracking (`playPos`) and `sec`-based completion behavior
  - MML parser compatibility improvements including old tokens (`x/X/~`)
  - WAV export path and ffmpeg-based optional compressed workflow
- Resource file support in Rust core:
  - `.pyxres` zip archive with `pyxel_resource.toml`
  - `format_version <= 4` handling
  - image/tilemap/sound/music round-trip + exclude flags
  - `.pyxpal` load/save path
- Native prebuilt artifact strategy:
  - Android: `packages/flutterxel/native/android/jniLibs/<abi>/libflutterxel_core.so`
  - iOS: `packages/flutterxel/native/ios/FlutterxelCore.xcframework`
- Release/CI automation:
  - workspace CI (analyze/test), Rust test/fmt, ABI contract checks
  - tagged native artifact packaging (`v*`)
  - tag/version validation + `pub publish --dry-run` workflow

## Repository Layout

```text
flutterxel/
├── docs/
│   ├── architecture/
│   └── plans/
├── native/
│   └── flutterxel_core/
└── packages/
    ├── flutterxel/
    └── flutterxel_tools/
```

## Packages

- `packages/flutterxel`
  - Flutter runtime plugin (mobile-first)
  - Dart API + FFI bridge to Rust core
- `packages/flutterxel_tools`
  - CLI/tooling package
  - native artifact build helpers and release-check command
- `native/flutterxel_core`
  - Rust engine core
  - stable C ABI boundary for Flutter FFI

## Quick Start (Repo)

```bash
dart pub get
dart run melos bootstrap
dart run melos run analyze
dart run melos run test
```

Rust core tests:

```bash
cd native/flutterxel_core
cargo test
```

## Native Artifacts

Maintainer build helper:

```bash
dart run flutterxel_tools:flutterxel_tools build-native --all
```

Tag releases (`v*`) produce downloadable artifacts via GitHub Actions:

- `flutterxel-native-artifacts.tgz`
- `flutterxel-native-package-overlay.tgz`

## Release Validation

Tag/package version alignment check:

```bash
dart run flutterxel_tools:flutterxel_tools release-check --tag v0.0.1
```

Equivalent script:

```bash
bash packages/flutterxel_tools/tool/check_release_versions.sh --tag v0.0.1
```

Pre-tag version bump (pubspec + changelog headings):

```bash
dart run flutterxel_tools:flutterxel_tools release-bump --version 0.0.2
```

## CI Workflows

- `.github/workflows/ci.yml`
  - workspace analyze/test
  - Rust fmt/test
  - ABI contract check
- `.github/workflows/native_artifacts.yml`
  - Android/iOS native artifact build and release asset upload on tag
- `.github/workflows/publish_dry_run.yml`
  - tag/version validation
  - `flutter pub publish --dry-run` for monorepo packages
- `.github/workflows/release_readiness.yml`
  - pre-tag metadata validation on PR/main (versions + CHANGELOG headings)

## Design/Planning Docs

- `docs/architecture/2026-02-25-flutterxel-ffi-mobile-architecture.md`
- `docs/plans/2026-02-25-workspace-bootstrap-implementation-plan.md`
- `docs/plans/2026-02-26-audio-ffi-old-mml-implementation-plan.md`

## License

MIT. See [LICENSE](LICENSE).
