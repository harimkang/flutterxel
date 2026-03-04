#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
SRC_DIR="$ROOT_DIR/reference/characters"
DST_DIR="$ROOT_DIR/packages/flutterxel/example/assets/characters"

if [ ! -d "$SRC_DIR" ]; then
  echo "Missing source directory: $SRC_DIR" >&2
  exit 1
fi

mkdir -p "$DST_DIR"
find "$DST_DIR" -mindepth 1 ! -name '.gitkeep' -exec rm -rf {} +

count=0
for meta in "$SRC_DIR"/*/*_sheet.meta.json; do
  [ -e "$meta" ] || continue
  char_dir="$(basename "$(dirname "$meta")")"
  out_dir="$DST_DIR/$char_dir"
  mkdir -p "$out_dir"
  cp "$meta" "$out_dir/"

  for sheet in "$SRC_DIR/$char_dir"/*_sheet.png; do
    [ -e "$sheet" ] || continue
    cp "$sheet" "$out_dir/"
    count=$((count + 1))
  done
done

echo "Synced character sheets and manifests to: $DST_DIR"
echo "Copied $count sheet PNG files."
