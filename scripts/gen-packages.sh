#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

out="${1:-$PROFILE_DIR/packages.x86_64}"

tmp="$(mktemp)"
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT

kernel_fragment=''
case "${KITEST_KERNEL:-kitten}" in
  kitten|"") kernel_fragment="$PROFILE_DIR/packages.d/15-kernel-kitten.list" ;;
  stock|linux) kernel_fragment="$PROFILE_DIR/packages.d/15-kernel-stock.list" ;;
  *)
    echo "Unknown KITEST_KERNEL=${KITEST_KERNEL}. Use: kitten|linux" >&2
    exit 2
    ;;
esac

brcm_fragment=''
case "${KITEST_BRCM_DRIVER:-b43}" in
  b43|"") brcm_fragment="$PROFILE_DIR/packages.d/16-brcm-b43.list" ;;
  wl) brcm_fragment="$PROFILE_DIR/packages.d/16-brcm-wl.list" ;;
  *)
    echo "Unknown KITEST_BRCM_DRIVER=${KITEST_BRCM_DRIVER}. Use: b43|wl" >&2
    exit 2
    ;;
esac

[[ -r "$kernel_fragment" ]] || { echo "Missing kernel fragment: $kernel_fragment" >&2; exit 2; }
[[ -r "$brcm_fragment" ]] || { echo "Missing Broadcom fragment: $brcm_fragment" >&2; exit 2; }

{
  printf '%s\n' '# Generated from packages.d/*.list — edit fragments, not this file.'

  # Common fragments (everything except kernel/brcm variants).
  for f in "$PROFILE_DIR"/packages.d/[0-9][0-9]-*.list; do
    case "$(basename "$f")" in
      15-kernel-*.list|16-brcm-*.list) continue ;;
    esac
    cat "$f"
  done

  # Variant fragments.
  cat "$kernel_fragment"
  cat "$brcm_fragment"
} | sed '/^[[:blank:]]*#/d;s/#.*//;/^[[:blank:]]*$/d' >"$tmp"

if [[ -f "$out" ]] && cmp -s "$tmp" "$out"; then
  exit 0
fi

install -D -m 0644 "$tmp" "$out"
