#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCALREPO_DIR="${LOCALREPO_DIR:-/var/tmp/kitest-localrepo}"

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo env \
    LOCALREPO_DIR="$LOCALREPO_DIR" \
    KITEST_SKIP_KERNEL_BUILD="${KITEST_SKIP_KERNEL_BUILD:-}" \
    KITEST_FORCE_KERNEL_REBUILD="${KITEST_FORCE_KERNEL_REBUILD:-}" \
    KITEST_KERNEL_BUILD_DIR="${KITEST_KERNEL_BUILD_DIR:-}" \
    KITEST_OFFLINE="${KITEST_OFFLINE:-}" \
    bash "$0" "$@"
fi

pkgdir="$PROFILE_DIR/pkgs/linux-kitten-cachy"
[[ -d "$pkgdir" ]] || { echo "Kernel PKGBUILD not found at $pkgdir" >&2; exit 1; }

mkdir -p "$LOCALREPO_DIR"

stamp="$LOCALREPO_DIR/.kernel-src-stamp"
src_hash="$(
  (sha256sum "$pkgdir/PKGBUILD" "$pkgdir/config" 2>/dev/null || true) | sha256sum | awk '{print $1}'
)"

repo_db="${LOCALREPO_DIR}/kitten-local.db.tar.gz"

repo_add_kernel_pkgs() {
  shopt -s nullglob
  local pkgs=( "$LOCALREPO_DIR"/linux-kitten-cachyos-hardened*.pkg.tar.zst )
  shopt -u nullglob
  [[ "${#pkgs[@]}" -gt 0 ]] || { echo "No linux-kitten-cachyos-hardened *.pkg.tar.zst in $LOCALREPO_DIR" >&2; return 1; }
  repo-add "$repo_db" "${pkgs[@]}" >/dev/null
}

if [[ "${KITEST_SKIP_KERNEL_BUILD:-0}" == "1" ]]; then
  echo "KITEST_SKIP_KERNEL_BUILD=1: skipping kernel build (using existing $LOCALREPO_DIR)" >&2
  repo_add_kernel_pkgs
  exit 0
fi

if [[ "${KITEST_FORCE_KERNEL_REBUILD:-0}" != "1" ]] && [[ -f "$stamp" ]] && grep -qFx "$src_hash" "$stamp" 2>/dev/null; then
  if compgen -G "$LOCALREPO_DIR/linux-kitten-cachyos-hardened"*.pkg.tar.zst >/dev/null; then
    echo "kitest: reusing kernel packages (same PKGBUILD+config hash). Set KITEST_FORCE_KERNEL_REBUILD=1 to rebuild." >&2
    repo_add_kernel_pkgs
    exit 0
  fi
fi

if ! id -u kitbuild >/dev/null 2>&1; then
  useradd -m -s /bin/bash kitbuild
fi

kwork="${KITEST_KERNEL_BUILD_DIR:-$LOCALREPO_DIR/.kernel-build}"
mkdir -p "$kwork"

if [[ "${KITEST_FORCE_KERNEL_REBUILD:-0}" == "1" ]] || [[ ! -f "$kwork/PKGBUILD" ]]; then
  rm -rf "$kwork"
  mkdir -p "$kwork"
  cp -a "$pkgdir/." "$kwork/"
else
  cp -a "$pkgdir/PKGBUILD" "$pkgdir/config" "$kwork/"
  [[ -f "$pkgdir/.SRCINFO" ]] && cp -a "$pkgdir/.SRCINFO" "$kwork/" || true
fi
chown -R kitbuild:kitbuild "$kwork"

if [[ "${KITEST_OFFLINE:-0}" == "1" ]]; then
  echo "KITEST_OFFLINE=1: refusing to install build deps (requires network/mirrors). Ensure deps are already installed." >&2
else
  pacman -Sy --needed --noconfirm \
    base-devel git \
    bc cpio gettext libelf pahole perl python \
    rust rust-bindgen rust-src \
    tar xz zstd
fi

runuser -u kitbuild -- bash -lc "cd \"$kwork\" && makepkg --noconfirm --needed"

shopt -s nullglob
built=( "$kwork"/*.pkg.tar.zst )
shopt -u nullglob
[[ "${#built[@]}" -gt 0 ]] || { echo "makepkg produced no *.pkg.tar.zst in $kwork" >&2; exit 1; }
cp -a "${built[@]}" "$LOCALREPO_DIR/"
printf '%s\n' "$src_hash" >"$stamp"
repo_add_kernel_pkgs
