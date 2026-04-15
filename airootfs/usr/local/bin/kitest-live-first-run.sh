#!/usr/bin/env bash
# One-time live session: configure Flathub + Kitest Flatpak bundles (best-effort).
set -euo pipefail

mark="$HOME/.config/kitest-live-setup-done"
[[ -f "$mark" ]] && exit 0

mkdir -p "$(dirname "$mark")"

# Ensure Qt/KDE theme is applied for live testing on first login.
if command -v /usr/local/bin/kitten-apply-catppuccin-kvantum >/dev/null 2>&1; then
  KITTEN_APPLY_NONINTERACTIVE=1 /usr/local/bin/kitten-apply-catppuccin-kvantum >/dev/null 2>&1 || true
fi
if command -v /usr/local/kde/install.sh >/dev/null 2>&1; then
  /usr/local/kde/install.sh --base-defaults >/dev/null 2>&1 || true
fi

if [[ "${KITEST_OFFLINE:-0}" == "1" ]]; then
  touch "$mark"
  exit 0
fi

if command -v /usr/local/bin/kitest-desktop-extras.sh >/dev/null 2>&1; then
  if ! command -v flatpak >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm --needed flatpak xdg-desktop-portal xdg-desktop-portal-kde xdg-desktop-portal-gtk >/dev/null 2>&1 || true
  fi
  /usr/local/bin/kitest-desktop-extras.sh 2>/dev/null || true
fi

touch "$mark"
exit 0
