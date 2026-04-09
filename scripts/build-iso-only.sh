#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-/var/tmp/kitest-work}"
OUT_DIR="${OUT_DIR:-/var/tmp/kitest-out}"

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo env WORK_DIR="$WORK_DIR" OUT_DIR="$OUT_DIR" KITEST_CLEAN="${KITEST_CLEAN:-}" KITEST_KERNEL="${KITEST_KERNEL:-}" KITEST_BRCM_DRIVER="${KITEST_BRCM_DRIVER:-}" bash "$0" "$@"
fi

case "${KITEST_CLEAN:-}" in
  ""|none) ;;
  airootfs)
    rm -rf "$WORK_DIR/x86_64/airootfs" \
      "$WORK_DIR/x86_64/airootfs.sfs" \
      "$WORK_DIR/x86_64/airootfs.sfs"* || true
    ;;
  work|all)
    rm -rf "$WORK_DIR"
    ;;
  *)
    echo "Unknown KITEST_CLEAN=${KITEST_CLEAN}. Use: none|airootfs|work" >&2
    exit 2
    ;;
esac

mkdir -p "$WORK_DIR" "$OUT_DIR"

bash "$PROFILE_DIR/scripts/gen-packages.sh"
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
echo "Output directory: $OUT_DIR"
