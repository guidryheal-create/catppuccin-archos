#!/usr/bin/env bash
# One-time live session: configure theme + Flathub extras (best-effort).
set -euo pipefail

mark="$HOME/.config/kitest-live-setup-done"
[[ -f "$mark" ]] && exit 0

mkdir -p "$(dirname "$mark")"

# Ensure Qt/KDE theme is applied for live testing on first login.
if command -v /usr/local/bin/kitten-apply-catppuccin-kvantum >/dev/null 2>&1; then
  KITTEN_APPLY_NONINTERACTIVE=1 /usr/local/bin/kitten-apply-catppuccin-kvantum >/dev/null 2>&1 || true
fi

if [[ "${KITEST_OFFLINE:-0}" == "1" ]]; then
  touch "$mark"
  exit 0
fi

if command -v flatpak >/dev/null 2>&1; then
  if [[ "$(id -u)" -eq 0 ]]; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    flatpak install -y --system --noninteractive flathub com.brave.Browser 2>/dev/null || true
  else
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    sudo flatpak install -y --system --noninteractive flathub com.brave.Browser 2>/dev/null || true
  fi
  update-desktop-database /var/lib/flatpak/exports/share/applications 2>/dev/null || true
fi

touch "$mark"
exit 0
