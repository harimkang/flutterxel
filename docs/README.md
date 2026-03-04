# flutterxel Documentation Workspace

This directory contains everything required to build and deploy the public documentation site for `flutterxel`.

## Structure

- `mkdocs.yml`: MkDocs configuration and navigation.
- `site/`: Authored documentation pages (Markdown).
- `scripts/generate_api_docs.sh`: Generates API docs from `packages/flutterxel` using `dart doc`.
- `scripts/build_docs.sh`: Generates API docs and builds the full static site.
- `requirements.txt`: Python dependencies used to build the site.

## Local Build

From the repository root:

```bash
dart run melos bootstrap
python3 -m pip install -r docs/requirements.txt
bash docs/scripts/build_docs.sh
```

Build output:

- `docs/.site/`

## pixel-snap Tooling Command

Asset preprocessing is handled by `flutterxel_tools pixel-snap` (tooling layer, not runtime).

Examples:

```bash
dart run flutterxel_tools:flutterxel_tools pixel-snap --input assets/raw/hero.png --output assets/pixel/hero.png
dart run flutterxel_tools:flutterxel_tools pixel-snap --input assets/raw/hero.png --output assets/pixel/hero.snapped.png --colors 16 --overwrite
```

Arguments:

- `--input` (required), `--output` (required)
- `--colors` (optional), `--overwrite` (optional)

Prerequisites:

- Rust/Cargo installed
- `reference/spritefusion-pixel-snapper` available in this repository

## API Docs Generation

API reference is generated automatically from the real package code:

```bash
bash docs/scripts/generate_api_docs.sh
```

This command runs:

- `dart doc` in `packages/flutterxel`

Generated files are placed in:

- `docs/site/api/flutterxel/`

## Deployment

Deployment is done manually through GitHub Actions using:

- `.github/workflows/docs_manual_deploy.yml`

Trigger it from the **Actions** tab with **Run workflow**.
