#!/usr/bin/env bash
# Download yaml-cpp 0.8.0-3 from the Arch Linux Archive into airootfs/root/ so ISO builds work
# when the mkarchiso chroot has no writable pacman-keyring (e.g. Docker + customize_airootfs.sh).
# Same package as https://archive.archlinux.org/packages/y/yaml-cpp/yaml-cpp-0.8.0-3-x86_64.pkg.tar.zst
# (matches libyaml-cpp.so.0.8 — see https://archlinux.org/packages/extra/x86_64/yaml-cpp/ for 0.9 sonames).
set -euo pipefail
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$PROFILE_DIR/airootfs/root/yaml-cpp-0.8.0-3-x86_64.pkg.tar.zst"
URL='https://archive.archlinux.org/packages/y/yaml-cpp/yaml-cpp-0.8.0-3-x86_64.pkg.tar.zst'

mkdir -p "$(dirname "$DEST")"
curl -fL --retry 3 --retry-delay 2 -o "$DEST.part" "$URL"
mv -f "$DEST.part" "$DEST"
echo "Wrote $DEST ($(wc -c <"$DEST") bytes). Re-run mkarchiso." >&2
