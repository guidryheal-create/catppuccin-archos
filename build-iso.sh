#!/usr/bin/env bash
# Build the Kitest profile. Requires an Arch Linux host (pacstrap, arch-chroot)
# and root. On Ubuntu/Debian use the official archlinux container or GitHub
# Actions workflow .github/workflows/build-archiso.yml instead.
set -euo pipefail
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-/var/tmp/kitest-work}"
OUT_DIR="${OUT_DIR:-/var/tmp/kitest-out}"
LOCALREPO_DIR="${LOCALREPO_DIR:-/var/tmp/kitest-localrepo}"

setup_endeavouros_trust() {
  if [[ "${KITEST_SKIP_EOS_SETUP:-0}" == "1" || "${KITEST_SKIP_CHAOTIC_SETUP:-0}" == "1" ]]; then
    echo "KITEST_SKIP_EOS_SETUP=1 (or legacy KITEST_SKIP_CHAOTIC_SETUP=1): skipping EndeavourOS keyring bootstrap (build will fail if calamares is listed)." >&2
    return 0
  fi
  # See scripts/bootstrap-endeavouros-pacman.sh — must populate EOS keys before pacman -U.
  bash "$PROFILE_DIR/scripts/bootstrap-endeavouros-pacman.sh"
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Re-exec with sudo (mkarchiso must run as root)." >&2
  exec sudo env \
    WORK_DIR="$WORK_DIR" OUT_DIR="$OUT_DIR" LOCALREPO_DIR="${LOCALREPO_DIR:-}" \
    EOS_PKG_BASE="${EOS_PKG_BASE:-}" EOS_KEYRING_GIT="${EOS_KEYRING_GIT:-}" \
    KITEST_SKIP_KERNEL_BUILD="${KITEST_SKIP_KERNEL_BUILD:-}" \
    KITEST_FORCE_KERNEL_REBUILD="${KITEST_FORCE_KERNEL_REBUILD:-}" \
    KITEST_KERNEL_BUILD_DIR="${KITEST_KERNEL_BUILD_DIR:-}" \
    bash "$0" "$@"
fi

setup_endeavouros_trust

rm -rf "$WORK_DIR"
mkdir -p "$OUT_DIR"
mkdir -p "$LOCALREPO_DIR"

# Build the Kitten Cachy kernel package into a local repo (used by pacman.conf [kitten-local]).
# This is intentionally done before mkarchiso so pacstrap can install it.
#
# Reuse (skip long rebuild): if PKGBUILD+config hash matches .kernel-src-stamp and
# linux-kitten-cachyos-hardened-*.pkg.tar.zst exists in LOCALREPO_DIR, only refresh repo DB.
# Force rebuild: KITEST_FORCE_KERNEL_REBUILD=1
# Skip entirely (must have packages already): KITEST_SKIP_KERNEL_BUILD=1
# Persistent makepkg tree (incremental rebuilds): KITEST_KERNEL_BUILD_DIR (default LOCALREPO_DIR/.kernel-build)
build_kitten_kernel() {
  local pkgdir="$PROFILE_DIR/pkgs/linux-kitten-cachy"
  [[ -d "$pkgdir" ]] || { echo "Kernel PKGBUILD not found at $pkgdir" >&2; exit 1; }

  local stamp="$LOCALREPO_DIR/.kernel-src-stamp"
  local src_hash
  src_hash=$( (sha256sum "$pkgdir/PKGBUILD" "$pkgdir/config" 2>/dev/null || true) | sha256sum | awk '{print $1}' )

  _repo_add_kernel_pkgs() {
    shopt -s nullglob
    local pkgs=( "$LOCALREPO_DIR"/linux-kitten-cachyos-hardened*.pkg.tar.zst )
    shopt -u nullglob
    [[ "${#pkgs[@]}" -gt 0 ]] || { echo "No linux-kitten-cachyos-hardened *.pkg.tar.zst in $LOCALREPO_DIR" >&2; return 1; }
    repo-add "$LOCALREPO_DIR/kitten-local.db.tar.gz" "${pkgs[@]}" >/dev/null
  }

  if [[ "${KITEST_SKIP_KERNEL_BUILD:-0}" == "1" ]]; then
    echo "KITEST_SKIP_KERNEL_BUILD=1: skipping kernel build (using existing $LOCALREPO_DIR)"
    _repo_add_kernel_pkgs || exit 1
    return 0
  fi

  if [[ "${KITEST_FORCE_KERNEL_REBUILD:-0}" != "1" ]] && [[ -f "$stamp" ]] && grep -qFx "$src_hash" "$stamp" 2>/dev/null; then
    if compgen -G "$LOCALREPO_DIR/linux-kitten-cachyos-hardened"*.pkg.tar.zst >/dev/null; then
      echo "kitest: reusing kernel packages (same PKGBUILD+config hash). Set KITEST_FORCE_KERNEL_REBUILD=1 to rebuild."
      _repo_add_kernel_pkgs || exit 1
      return 0
    fi
  fi

  # Makepkg refuses to run as root; create a throwaway build user.
  if ! id -u kitbuild >/dev/null 2>&1; then
    useradd -m -s /bin/bash kitbuild
  fi

  local kwork="${KITEST_KERNEL_BUILD_DIR:-$LOCALREPO_DIR/.kernel-build}"
  mkdir -p "$kwork"

  if [[ "${KITEST_FORCE_KERNEL_REBUILD:-0}" == "1" ]] || [[ ! -f "$kwork/PKGBUILD" ]]; then
    rm -rf "$kwork"
    mkdir -p "$kwork"
    cp -a "$pkgdir/." "$kwork/"
  else
    # Refresh PKGBUILD/config from profile (keeps src/ for incremental makepkg when possible)
    cp -a "$pkgdir/PKGBUILD" "$pkgdir/config" "$kwork/"
    [[ -f "$pkgdir/.SRCINFO" ]] && cp -a "$pkgdir/.SRCINFO" "$kwork/" || true
  fi
  chown -R kitbuild:kitbuild "$kwork"

  # Install build deps as root to avoid makepkg prompting for sudo.
  # (This keeps Docker/CI builds non-interactive.)
  pacman -Sy --needed --noconfirm \
    base-devel git \
    bc cpio gettext libelf pahole perl python \
    rust rust-bindgen rust-src \
    tar xz zstd

  # Build as an unprivileged user (makepkg refuses to run as root).
  runuser -u kitbuild -- bash -lc "cd \"$kwork\" && makepkg --noconfirm --needed"

  # Add packages to local repo.
  shopt -s nullglob
  local built=( "$kwork"/*.pkg.tar.zst )
  shopt -u nullglob
  [[ "${#built[@]}" -gt 0 ]] || { echo "makepkg produced no *.pkg.tar.zst in $kwork" >&2; exit 1; }
  cp -a "${built[@]}" "$LOCALREPO_DIR/"
  printf '%s\n' "$src_hash" >"$stamp"
  _repo_add_kernel_pkgs || exit 1
}

build_kitten_kernel

# Single packages.x86_64 for mkarchiso; source of truth is packages.d/*.list
{
  printf '%s\n' '# Generated from packages.d/*.list — edit fragments, not this file.'
  cat "$PROFILE_DIR"/packages.d/*.list
} | sed '/^[[:blank:]]*#/d;s/#.*//;/^[[:blank:]]*$/d' >"$PROFILE_DIR/packages.x86_64"

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
echo "Output directory: $OUT_DIR"
