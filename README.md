# flutterxel

`flutterxel` is a monorepo for a Flutter-first, Pyxel-compatible runtime powered by a Rust core over FFI.

## Packages

- `packages/flutterxel`: runtime plugin for Flutter apps (mobile-first)
- `packages/flutterxel_tools`: editor/CLI/package tooling
- `native/flutterxel_core`: Rust core engine crate (FFI surface)

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

## Workspace

This repository uses a Dart workspace plus Melos orchestration.

Common commands:

```bash
dart pub get
dart run melos bootstrap
dart run melos run analyze
dart run melos run test
```

## CI

GitHub Actions pipeline (`.github/workflows/ci.yml`) validates:

- workspace bootstrap/analyze/test
- Rust core formatting/tests
- ABI symbol contract between C header and generated Dart bindings

## License

MIT. See [LICENSE](LICENSE).
