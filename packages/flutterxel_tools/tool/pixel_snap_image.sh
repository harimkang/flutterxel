#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: pixel_snap_image.sh --input <path> --output <path> [--colors <n>] [--overwrite]

Preprocesses an image with the SpriteFusion pixel snapper reference implementation.

Options:
  --input <path>     Required. Source image path.
  --output <path>    Required. Destination image path.
  --colors <n>       Optional. Palette size (> 0). Default: 16.
  --overwrite        Optional. Overwrite output file if it already exists.
  --help, -h         Show this help message.
EOF
}

INPUT=""
OUTPUT=""
COLORS="16"
OVERWRITE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --input." >&2
        usage >&2
        exit 64
      fi
      INPUT="$2"
      shift 2
      ;;
    --input=*)
      INPUT="${1#*=}"
      shift
      ;;
    --output)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --output." >&2
        usage >&2
        exit 64
      fi
      OUTPUT="$2"
      shift 2
      ;;
    --output=*)
      OUTPUT="${1#*=}"
      shift
      ;;
    --colors)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --colors." >&2
        usage >&2
        exit 64
      fi
      COLORS="$2"
      shift 2
      ;;
    --colors=*)
      COLORS="${1#*=}"
      shift
      ;;
    --overwrite)
      OVERWRITE=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "Missing required argument: --input <path>." >&2
  usage >&2
  exit 64
fi

if [[ -z "$OUTPUT" ]]; then
  echo "Missing required argument: --output <path>." >&2
  usage >&2
  exit 64
fi

if ! [[ "$COLORS" =~ ^[0-9]+$ ]] || (( COLORS <= 0 )); then
  echo "Invalid --colors value: $COLORS (must be an integer > 0)." >&2
  exit 64
fi

if [[ ! -f "$INPUT" ]]; then
  echo "Input file not found: $INPUT" >&2
  exit 66
fi

if [[ -f "$OUTPUT" && "$OVERWRITE" -ne 1 ]]; then
  echo "Output file already exists: $OUTPUT (use --overwrite to replace)." >&2
  exit 73
fi

OUTPUT_DIR="$(dirname "$OUTPUT")"
mkdir -p "$OUTPUT_DIR"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd -- "$TOOLS_DIR/../.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/reference/spritefusion-pixel-snapper/Cargo.toml"

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "SpriteFusion manifest not found: $MANIFEST_PATH" >&2
  exit 66
fi

cargo run --manifest-path "$MANIFEST_PATH" --quiet -- "$INPUT" "$OUTPUT" "$COLORS"
