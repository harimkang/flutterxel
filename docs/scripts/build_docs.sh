#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCS_DIR="$ROOT_DIR/docs"

bash "$DOCS_DIR/scripts/generate_api_docs.sh"

mkdocs build --config-file "$DOCS_DIR/mkdocs.yml" --strict --site-dir "$DOCS_DIR/.site"

echo "Built docs site at: $DOCS_DIR/.site"
