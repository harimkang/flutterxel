#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bump_release_versions.sh --version <version>

Options:
  --version <version> Target version (for example 0.1.0)
  -h, --help          Show this help

Behavior:
  - Updates version in:
      packages/flutterxel/pubspec.yaml
      packages/flutterxel_tools/pubspec.yaml
  - Ensures CHANGELOG headings for the version exist in:
      CHANGELOG.md
      packages/flutterxel/CHANGELOG.md
      packages/flutterxel_tools/CHANGELOG.md
  - Runs release metadata validation after update.
USAGE
}

update_pubspec_version() {
  local file_path="$1"
  local target_version="$2"
  local tmp
  tmp="$(mktemp)"
  awk -v v="$target_version" '
    BEGIN { updated=0 }
    /^version:[[:space:]]*/ && updated==0 {
      print "version: " v
      updated=1
      next
    }
    { print }
    END {
      if (updated==0) {
        exit 2
      }
    }
  ' "$file_path" > "$tmp"
  mv "$tmp" "$file_path"
}

ensure_changelog_heading() {
  local file_path="$1"
  local target_version="$2"
  if [[ -f "$file_path" ]] &&
     grep -Eq "^##[[:space:]]*\\[?${target_version}\\]?" "$file_path"; then
    return
  fi

  local tmp
  tmp="$(mktemp)"
  {
    echo "## $target_version"
    echo
    echo "- TODO: Describe this release."
    echo
    if [[ -f "$file_path" ]]; then
      cat "$file_path"
    fi
  } > "$tmp"
  mv "$tmp" "$file_path"
}

VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ -z "$VERSION" ]]; then
  echo "--version is required." >&2
  exit 64
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version format: $VERSION" >&2
  exit 65
fi

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
PUBSPECS=(
  "$ROOT_DIR/packages/flutterxel/pubspec.yaml"
  "$ROOT_DIR/packages/flutterxel_tools/pubspec.yaml"
)
CHANGELOGS=(
  "$ROOT_DIR/CHANGELOG.md"
  "$ROOT_DIR/packages/flutterxel/CHANGELOG.md"
  "$ROOT_DIR/packages/flutterxel_tools/CHANGELOG.md"
)

for pubspec in "${PUBSPECS[@]}"; do
  if [[ ! -f "$pubspec" ]]; then
    echo "Missing pubspec: $pubspec" >&2
    exit 1
  fi
  update_pubspec_version "$pubspec" "$VERSION"
  echo "[release-bump] updated version in ${pubspec#$ROOT_DIR/}"
done

for changelog in "${CHANGELOGS[@]}"; do
  ensure_changelog_heading "$changelog" "$VERSION"
  echo "[release-bump] ensured changelog heading in ${changelog#$ROOT_DIR/}"
done

bash "$ROOT_DIR/packages/flutterxel_tools/tool/check_release_versions.sh" --version "$VERSION"
echo "[release-bump] done for version $VERSION"
