#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCALREPO_DIR="${LOCALREPO_DIR:-/var/tmp/kitest-localrepo}"
REPO_DB_NAME="${REPO_DB_NAME:-kitten-local}"

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo env \
    LOCALREPO_DIR="$LOCALREPO_DIR" \
    REPO_DB_NAME="$REPO_DB_NAME" \
    bash "$0" "$@"
fi

mkdir -p "$LOCALREPO_DIR"

repo_db="${LOCALREPO_DIR}/${REPO_DB_NAME}.db.tar.gz"

pkgs=()

shopt -s nullglob
pkgs+=( "$LOCALREPO_DIR"/linux-kitten-cachyos-hardened*.pkg.tar.zst )
pkgs+=( "$LOCALREPO_DIR"/localpkgs/*.pkg.tar.zst )
shopt -u nullglob

if [[ "${#pkgs[@]}" -eq 0 ]]; then
  echo "No packages found to add. Looked for:" >&2
  echo "  - $LOCALREPO_DIR/linux-kitten-cachyos-hardened*.pkg.tar.zst" >&2
  echo "  - $LOCALREPO_DIR/localpkgs/*.pkg.tar.zst" >&2
  exit 1
fi

repo-add "$repo_db" "${pkgs[@]}" >/dev/null

if [[ -d "$LOCALREPO_DIR/localpkgs" ]]; then
  echo "Local repo updated: $repo_db (includes $LOCALREPO_DIR/localpkgs/*.pkg.tar.zst)" >&2
else
  echo "Local repo updated: $repo_db" >&2
fi
