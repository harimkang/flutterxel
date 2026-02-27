# Docs Workflow

This project uses MkDocs for static documentation and GitHub Pages for hosting.

## Build Locally

From repository root:

```bash
dart run melos bootstrap
python3 -m pip install -r docs/requirements.txt
bash docs/scripts/build_docs.sh
```

Output:

- `docs/.site/`

## API Docs Auto-Generation

API pages are generated with `dart doc` from the plugin package:

```bash
bash docs/scripts/generate_api_docs.sh
```

Generated files are placed under:

- `docs/site/api/flutterxel/`

## Manual GitHub Pages Deployment

Deployment is intentionally manual.

Workflow file:

- `.github/workflows/docs_manual_deploy.yml`

Trigger path:

1. Open GitHub Actions.
2. Select **docs-manual-deploy**.
3. Click **Run workflow**.

No push/PR trigger is configured for this workflow.
