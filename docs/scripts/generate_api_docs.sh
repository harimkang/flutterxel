#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_OUTPUT_DIR="$ROOT_DIR/docs/site/api/flutterxel"

rm -rf "$API_OUTPUT_DIR"
mkdir -p "$API_OUTPUT_DIR"

(
  cd "$ROOT_DIR/packages/flutterxel"
  dart doc --output "$API_OUTPUT_DIR"
)

echo "Generated flutterxel API docs at: $API_OUTPUT_DIR"
