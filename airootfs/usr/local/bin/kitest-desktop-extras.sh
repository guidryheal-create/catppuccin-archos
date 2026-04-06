#!/usr/bin/env bash
# Flathub: Brave (browser), Steam (games), Flatseal (Flatpak permissions).
# GPU/userspace for Steam is carried by the Flatpak runtime, not multilib on the host.
# Re-run on the live ISO if the image was built offline.
set -euo pipefail

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy 2>/dev/null || true

if ! flatpak remote-list --system 2>/dev/null | grep -q flathub; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

flatpak install -y --system --noninteractive flathub \
  com.brave.Browser \
  com.valvesoftware.Steam \
  com.daidouji.oneko \
  com.github.tchx84.Flatseal || {
  echo "kitest-desktop-extras: flatpak install failed (no network during build?). On live: sudo /usr/local/bin/kitest-desktop-extras.sh" >&2
  exit 0
}

update-desktop-database /var/lib/flatpak/exports/share/applications 2>/dev/null || true
