#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: check_release_versions.sh [--tag <tag>]

Options:
  --tag <tag>   Tag to validate (format: vX.Y.Z)
  -h, --help    Show this help

Behavior:
  - Verifies the tag format.
  - Verifies package versions match tag version:
      packages/flutterxel/pubspec.yaml
      packages/flutterxel_tools/pubspec.yaml
USAGE
}

TAG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --tag" >&2
        exit 64
      fi
      TAG="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
  shift
done

if [[ -z "$TAG" ]]; then
  if [[ -n "${GITHUB_REF_NAME:-}" ]]; then
    TAG="$GITHUB_REF_NAME"
  elif [[ "${GITHUB_REF:-}" == refs/tags/* ]]; then
    TAG="${GITHUB_REF#refs/tags/}"
  fi
fi

if [[ -z "$TAG" ]]; then
  echo "Tag is required. Pass --tag or set GITHUB_REF_NAME/GITHUB_REF." >&2
  exit 64
fi

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid tag format: $TAG (expected vX.Y.Z)" >&2
  exit 65
fi

EXPECTED_VERSION="${TAG#v}"
ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
PACKAGES=(
  "packages/flutterxel"
  "packages/flutterxel_tools"
)

FAILED=0
for pkg in "${PACKAGES[@]}"; do
  pubspec="$ROOT_DIR/$pkg/pubspec.yaml"
  if [[ ! -f "$pubspec" ]]; then
    echo "Missing pubspec: $pubspec" >&2
    FAILED=1
    continue
  fi

  pkg_version="$(awk -F': ' '/^version:[[:space:]]*/ {print $2; exit}' "$pubspec" | tr -d '\r')"
  if [[ -z "$pkg_version" ]]; then
    echo "Unable to read version from $pubspec" >&2
    FAILED=1
    continue
  fi

  if [[ "$pkg_version" != "$EXPECTED_VERSION" ]]; then
    echo "Version mismatch for $pkg: expected $EXPECTED_VERSION, found $pkg_version" >&2
    FAILED=1
    continue
  fi

  echo "[release-check] $pkg version matches $EXPECTED_VERSION"
done

if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi

echo "[release-check] tag and package versions are aligned: $TAG"
