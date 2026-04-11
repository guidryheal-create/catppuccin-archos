#!/usr/bin/env bash
# Optional: build Calamares from AUR into LOCALREPO_DIR/localpkgs for [kitten-local].
# Requires: base-devel, git, network. Run on Arch (or in an Arch container).
# After build: scripts/prepare-repo.sh, then adjust packages.d (remove EOS calamares if desired).
#
# Stable upstream sources: https://codeberg.org/Calamares/calamares (tags). A vendored tree may exist
# under scripts/calamares-3.4.2/ for reference; this script still uses the AUR PKGBUILD so the build
# matches current Arch/Qt deps. Install the resulting package with pacman (binaries under /usr/bin),
# not by copying a binary into /etc.
#
# You do not need yay on the ISO to run Calamares; yay is only for interactive AUR work on a dev host.
set -euo pipefail
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCALREPO_DIR="${LOCALREPO_DIR:-/var/tmp/kitest-localrepo}"
WORKDIR="${WORKDIR:-/var/tmp/calamares-aur-build}"

if [[ "$(id -u)" -ne 0 ]]; then
  exec sudo env \
    LOCALREPO_DIR="$LOCALREPO_DIR" WORKDIR="$WORKDIR" \
    BUILD_USER="${SUDO_USER:-${USER:-}}" \
    bash "$0" "$@"
fi

build_user="${BUILD_USER:-${SUDO_USER:-${USER:-nobody}}}"
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
installed=0
for p in calamares-*.pkg.tar.zst; do
  install -Dm644 "$p" "$LOCALREPO_DIR/localpkgs/$p"
  chown root:root "$LOCALREPO_DIR/localpkgs/$p"
  echo "Installed: $LOCALREPO_DIR/localpkgs/$p" >&2
  installed=$((installed + 1))
done
shopt -u nullglob
if [[ "$installed" -eq 0 ]]; then
  echo "ERROR: makepkg produced no calamares-*.pkg.tar.zst in $(pwd)" >&2
  exit 1
fi
echo "Next: bash $PROFILE_DIR/scripts/prepare-repo.sh" >&2
echo "Then edit packages.d/50-calamares.list to use kitten-local calamares (and drop EOS calamares if appropriate)." >&2
