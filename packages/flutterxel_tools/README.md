# flutterxel_tools

Tooling package for the `flutterxel` monorepo.

## Scope

- CLI command surface (`run/watch/play/edit/package/app2html`)
- Editor-oriented workflows and automation scripts
- Packaging and build helper integrations
- Asset preprocessing helpers (`pixel-snap`)

## Current Status

The CLI command surface is scaffolded with placeholder handlers.

```bash
dart run flutterxel_tools:flutterxel_tools --help
dart run flutterxel_tools:flutterxel_tools run
dart run flutterxel_tools:flutterxel_tools build-native
dart run flutterxel_tools:flutterxel_tools release-check --tag v0.0.10
dart run flutterxel_tools:flutterxel_tools release-bump --version 0.0.10
dart run flutterxel_tools:flutterxel_tools pixel-snap --input assets/raw/hero.png --output assets/pixel/hero.png
```

`build-native` currently points maintainers to:

- `packages/flutterxel_tools/tool/build_rust_core_artifacts.sh`

Examples:

```bash
dart run flutterxel_tools:flutterxel_tools build-native --android
dart run flutterxel_tools:flutterxel_tools build-native --ios
dart run flutterxel_tools:flutterxel_tools build-native --all --out-dir ./dist/native
```

For tagged releases (`v*`), `.github/workflows/native_artifacts.yml` builds the same artifacts and uploads both:

- platform bundle (`flutterxel-native-artifacts.tgz`)
- package overlay (`flutterxel-native-package-overlay.tgz`)

Version/tag validation helper:

```bash
bash packages/flutterxel_tools/tool/check_release_versions.sh --tag v0.0.10
```

`release-check` CLI wrapper runs the same script.

Pre-tag version bump helper:

```bash
bash packages/flutterxel_tools/tool/bump_release_versions.sh --version 0.0.10
```

`release-bump` CLI wrapper runs the same script.

For tagged releases (`v*`), CI release validation uses:

- `.github/workflows/publish_dry_run.yml` (validation + `pub publish --dry-run`)

After CI dry-run succeeds, publish to pub.dev manually:

```bash
cd packages/flutterxel && flutter pub publish --force
cd ../flutterxel_tools && flutter pub publish --force
```

## pixel-snap Asset Preprocessing

`pixel-snap` preprocesses raw images into grid-aligned, palette-quantized assets before runtime use.

Prerequisites:

- Rust and Cargo installed (`cargo --version`)
- Repository contains `reference/spritefusion-pixel-snapper`

Examples:

```bash
dart run flutterxel_tools:flutterxel_tools pixel-snap --input assets/raw/hero.png --output assets/pixel/hero.png
dart run flutterxel_tools:flutterxel_tools pixel-snap --input assets/raw/hero.png --output assets/pixel/hero.snapped.png --colors 16 --overwrite
```

Arguments:

- `--input`: source image path (required)
- `--output`: destination image path (required)
- `--colors`: palette color count (optional, default `16`)
- `--overwrite`: allow replacing existing output file (optional)

Implementation note:

- CLI command delegates to `packages/flutterxel_tools/tool/pixel_snap_image.sh`
- Wrapper invokes `reference/spritefusion-pixel-snapper` via Cargo

## Monorepo Context

`flutterxel_tools` is intentionally separated from `flutterxel` runtime so app projects can depend on runtime without pulling in tooling/editor dependencies.

## License

MIT.
