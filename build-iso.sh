#!/usr/bin/env bash
# Build the Kitest profile. Requires an Arch Linux host (pacstrap, arch-chroot)
# and root. On Ubuntu/Debian use the official archlinux container or GitHub
# Actions workflow .github/workflows/build-archiso.yml instead.
set -euo pipefail
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-/var/tmp/kitest-work}"
OUT_DIR="${OUT_DIR:-/var/tmp/kitest-out}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Re-exec with sudo (mkarchiso must run as root)." >&2
  exec sudo env WORK_DIR="$WORK_DIR" OUT_DIR="$OUT_DIR" bash "$0" "$@"
fi

rm -rf "$WORK_DIR"
mkdir -p "$OUT_DIR"

# Single packages.x86_64 for mkarchiso; source of truth is packages.d/*.list
{
  printf '%s\n' '# Generated from packages.d/*.list — edit fragments, not this file.'
  cat "$PROFILE_DIR"/packages.d/*.list
} | sed '/^[[:blank:]]*#/d;s/#.*//;/^[[:blank:]]*$/d' >"$PROFILE_DIR/packages.x86_64"

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
echo "Output directory: $OUT_DIR"
