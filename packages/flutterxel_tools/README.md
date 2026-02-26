# flutterxel_tools

Tooling package for the `flutterxel` monorepo.

## Scope

- CLI command surface (`run/watch/play/edit/package/app2html`)
- Editor-oriented workflows and automation scripts
- Packaging and build helper integrations

## Current Status

The CLI command surface is scaffolded with placeholder handlers.

```bash
dart run flutterxel_tools:flutterxel_tools --help
dart run flutterxel_tools:flutterxel_tools run
dart run flutterxel_tools:flutterxel_tools build-native
dart run flutterxel_tools:flutterxel_tools release-check --tag v0.0.1
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
bash packages/flutterxel_tools/tool/check_release_versions.sh --tag v0.0.1
```

`release-check` CLI wrapper runs the same script.

## Monorepo Context

`flutterxel_tools` is intentionally separated from `flutterxel` runtime so app projects can depend on runtime without pulling in tooling/editor dependencies.

## License

MIT.
