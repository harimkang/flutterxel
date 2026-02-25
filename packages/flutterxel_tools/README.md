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
```

## Monorepo Context

`flutterxel_tools` is intentionally separated from `flutterxel` runtime so app projects can depend on runtime without pulling in tooling/editor dependencies.

## License

MIT.

