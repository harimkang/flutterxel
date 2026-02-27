# flutterxel Docs Site Architecture Plan

Date: 2026-02-27

## Goals

- Provide clear, practical user-facing docs for the `flutterxel` plugin.
- Keep API reference accurate without manual signature maintenance.
- Host docs as a static GitHub Pages site.
- Deploy docs manually (operator-controlled), not on every push.

## Constraints

- Existing repository already uses `docs/architecture` and `docs/plans`; this structure should remain intact.
- Documentation content must be in English.
- API docs must be generated from the real package source code.

## Chosen Architecture

### 1) Static docs framework

- Use MkDocs with Material theme.
- Keep authored pages in `docs/site/`.
- Keep build config in `docs/mkdocs.yml`.

### 2) API docs generation

- Use `dart doc` against `packages/flutterxel`.
- Generation script: `docs/scripts/generate_api_docs.sh`.
- Output path: `docs/site/api/flutterxel/`.

This ensures API reference always matches the package source at build time.

### 3) Unified docs build entry point

- Script: `docs/scripts/build_docs.sh`.
- Steps:
  1. Generate API docs.
  2. Build MkDocs site to `docs/.site/`.

### 4) Deployment model

- Workflow: `.github/workflows/docs_manual_deploy.yml`.
- Trigger: `workflow_dispatch` only.
- Build job:
  - checkout selected ref
  - workspace bootstrap
  - install Python docs dependencies
  - run docs build script
  - upload Pages artifact
- Deploy job:
  - deploy artifact with `actions/deploy-pages`

## Content Information Architecture

- Home
- Getting Started
  - Installation
  - First App
- Guides
  - Game Loop and Rendering
  - Input
  - Audio
  - Resources and Persistence
  - Examples
- Reference
  - API (auto-generated)
  - Constants and Compatibility
- Docs Workflow

## Operational Notes

- Generated artifacts are ignored via `.gitignore`:
  - `docs/.site/`
  - `docs/site/api/`
- Local docs build commands are documented in `docs/README.md`.
