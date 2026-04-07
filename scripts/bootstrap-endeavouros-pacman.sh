#!/usr/bin/env bash
# Populate EndeavourOS signing keys so `pacman -U` can verify endeavouros-keyring /
# endeavouros-mirrorlist from the EOS repo (chicken-and-egg: the .pkg files are signed
# with keys that are not in the Arch Linux keyring until this runs).
#
# Upstream key material: https://github.com/endeavouros-team/keyring
# Mirrors for .pkg:     EOS_PKG_BASE (default: Gigenet US)
set -euo pipefail

EOS_KEYRING_GIT="${EOS_KEYRING_GIT:-https://raw.githubusercontent.com/endeavouros-team/keyring/main}"
EOS_PKG_BASE="${EOS_PKG_BASE:-https://mirrors.gigenet.com/endeavouros/repo/endeavouros/x86_64}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "bootstrap-endeavouros-pacman.sh must run as root." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  pacman -S --needed --noconfirm curl
fi

pacman-key --init 2>/dev/null || true
pacman-key --populate archlinux 2>/dev/null || true

d=/usr/share/pacman/keyrings
install -d -m755 "$d"
curl -fsSL "$EOS_KEYRING_GIT/endeavouros.gpg" -o "$d/endeavouros.gpg"
curl -fsSL "$EOS_KEYRING_GIT/endeavouros-trusted" -o "$d/endeavouros-trusted"
curl -fsSL "$EOS_KEYRING_GIT/endeavouros-revoked" -o "$d/endeavouros-revoked"
chmod 644 "$d/endeavouros.gpg" "$d/endeavouros-trusted" "$d/endeavouros-revoked"
pacman-key --populate endeavouros

eos_latest_pkg() {
  local prefix="$1"
  curl -fsSL "$EOS_PKG_BASE/" | grep -oE "${prefix}-[0-9][^\"<> ]+\\.pkg\\.tar\\.zst" | sort -V | tail -n1
}

# Drop partial / stale downloads so verification is retried cleanly.
rm -f /var/cache/pacman/pkg/endeavouros-keyring-*.pkg.tar.zst.part
rm -f /var/cache/pacman/pkg/endeavouros-mirrorlist-*.pkg.tar.zst.part
rm -f /var/cache/pacman/pkg/endeavouros-keyring-*.pkg.tar.zst
rm -f /var/cache/pacman/pkg/endeavouros-mirrorlist-*.pkg.tar.zst

kr=$(eos_latest_pkg endeavouros-keyring)
ml=$(eos_latest_pkg endeavouros-mirrorlist)
if [[ -z "$kr" || -z "$ml" ]]; then
  echo "Could not resolve endeavouros-keyring / endeavouros-mirrorlist under $EOS_PKG_BASE" >&2
  exit 1
fi

# We pre-seeded keyring files above; the same paths ship in endeavouros-keyring.pkg.
# Without --overwrite pacman aborts: "exists in filesystem" (files not owned by a package).
pacman -U --noconfirm \
  --overwrite /usr/share/pacman/keyrings/endeavouros.gpg \
  --overwrite /usr/share/pacman/keyrings/endeavouros-trusted \
  --overwrite /usr/share/pacman/keyrings/endeavouros-revoked \
  "${EOS_PKG_BASE}/${kr}" "${EOS_PKG_BASE}/${ml}"
