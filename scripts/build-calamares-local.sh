#!/usr/bin/env bash
# Optional: build Calamares from AUR into LOCALREPO_DIR/localpkgs for [kitten-local].
# Requires: base-devel, git, network. Run on Arch (or in an Arch container).
# After build: scripts/prepare-repo.sh, then adjust packages.d (remove EOS calamares if desired).
set -euo pipefail
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCALREPO_DIR="${LOCALREPO_DIR:-/var/tmp/kitest-localrepo}"
WORKDIR="${WORKDIR:-/var/tmp/calamares-aur-build}"

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo env LOCALREPO_DIR="$LOCALREPO_DIR" WORKDIR="$WORKDIR" bash "$0" "$@"
fi

build_user="${SUDO_USER:-${BUILD_USER:-nobody}}"
if ! id "$build_user" &>/dev/null; then
  echo "Build user '$build_user' not found; set SUDO_USER or BUILD_USER." >&2
  exit 1
fi

mkdir -p "$LOCALREPO_DIR/localpkgs" "$WORKDIR"
chown "$build_user:$build_user" "$WORKDIR" "$LOCALREPO_DIR/localpkgs"
cd "$WORKDIR"
if [[ ! -d calamares-aur ]]; then
  runuser -u "$build_user" -- git clone --depth 1 https://aur.archlinux.org/calamares.git calamares-aur
else
  runuser -u "$build_user" -- git -C calamares-aur pull --ff-only || true
fi
cd calamares-aur
runuser -u "$build_user" -- makepkg -sf --noconfirm
shopt -s nullglob
for p in calamares-*.pkg.tar.zst; do
  install -Dm644 "$p" "$LOCALREPO_DIR/localpkgs/$p"
  chown root:root "$LOCALREPO_DIR/localpkgs/$p"
  echo "Installed: $LOCALREPO_DIR/localpkgs/$p" >&2
done
shopt -u nullglob
echo "Next: bash $PROFILE_DIR/scripts/prepare-repo.sh" >&2
echo "Then edit packages.d/50-calamares.list to use kitten-local calamares (and drop EOS calamares if appropriate)." >&2
