#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: check_release_versions.sh [--tag <tag> | --version <version>]

Options:
  --tag <tag>         Tag to validate (format: vX.Y.Z)
  --version <version> Version to validate before creating a tag
  -h, --help          Show this help

Behavior:
  - Verifies release version format.
  - Verifies package versions match expected version:
      packages/flutterxel/pubspec.yaml
      packages/flutterxel_tools/pubspec.yaml
  - Verifies CHANGELOG headings contain expected version:
      CHANGELOG.md
      packages/flutterxel/CHANGELOG.md
      packages/flutterxel_tools/CHANGELOG.md
USAGE
}

read_pubspec_version() {
  local pubspec_path="$1"
  awk -F': ' '/^version:[[:space:]]*/ {print $2; exit}' "$pubspec_path" | tr -d '\r'
}

has_changelog_heading() {
  local changelog_path="$1"
  local expected_version="$2"
  grep -Eq "^##[[:space:]]*\\[?${expected_version}\\]?" "$changelog_path"
}

TAG=""
VERSION=""
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
    --version)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --version" >&2
        exit 64
      fi
      VERSION="$2"
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

if [[ -n "$TAG" && -n "$VERSION" ]]; then
  echo "Use either --tag or --version, not both." >&2
  exit 64
fi

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
if [[ -z "$TAG" && -z "$VERSION" ]]; then
  if [[ -n "${GITHUB_REF_NAME:-}" && "${GITHUB_REF_NAME}" == v* ]]; then
    TAG="$GITHUB_REF_NAME"
  elif [[ "${GITHUB_REF:-}" == refs/tags/* ]]; then
    TAG="${GITHUB_REF#refs/tags/}"
  else
    VERSION="$(read_pubspec_version "$ROOT_DIR/packages/flutterxel/pubspec.yaml")"
  fi
fi

EXPECTED_VERSION=""
if [[ -n "$VERSION" ]]; then
  EXPECTED_VERSION="$VERSION"
elif [[ -n "$TAG" ]]; then
  if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
    echo "Invalid tag format: $TAG (expected vX.Y.Z)." >&2
    exit 65
  fi
  EXPECTED_VERSION="${TAG#v}"
fi

if [[ ! "$EXPECTED_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version format: $EXPECTED_VERSION." >&2
  exit 65
fi

declare -a PACKAGE_PATHS=(
  "packages/flutterxel"
  "packages/flutterxel_tools"
)
declare -a CHANGELOG_PATHS=(
  "CHANGELOG.md"
  "packages/flutterxel/CHANGELOG.md"
  "packages/flutterxel_tools/CHANGELOG.md"
)

FAILED=0
for pkg in "${PACKAGE_PATHS[@]}"; do
  pubspec="$ROOT_DIR/$pkg/pubspec.yaml"
  if [[ ! -f "$pubspec" ]]; then
    echo "Missing pubspec: $pubspec" >&2
    FAILED=1
    continue
  fi

  pkg_version="$(read_pubspec_version "$pubspec")"
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

for changelog_rel_path in "${CHANGELOG_PATHS[@]}"; do
  changelog="$ROOT_DIR/$changelog_rel_path"
  if [[ ! -f "$changelog" ]]; then
    echo "Missing changelog: $changelog_rel_path" >&2
    FAILED=1
    continue
  fi
  if ! has_changelog_heading "$changelog" "$EXPECTED_VERSION"; then
    echo "Missing changelog heading for $EXPECTED_VERSION in $changelog_rel_path" >&2
    FAILED=1
    continue
  fi
  echo "[release-check] $changelog_rel_path contains $EXPECTED_VERSION heading"
done

if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi

if [[ -n "$TAG" ]]; then
  echo "[release-check] tag and versions are aligned: $TAG"
else
  echo "[release-check] release metadata is ready for version: $EXPECTED_VERSION"
fi
