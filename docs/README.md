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
