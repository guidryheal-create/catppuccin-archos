#!/usr/bin/env bash
# One-time live session: configure Flathub + Kitest Flatpak bundles (best-effort).
set -euo pipefail

mark="$HOME/.config/kitest-live-setup-done"
[[ -f "$mark" ]] && exit 0

mkdir -p "$(dirname "$mark")"

if [[ "${KITEST_OFFLINE:-0}" == "1" ]]; then
  touch "$mark"
  exit 0
fi

if command -v flatpak >/dev/null 2>&1 && command -v /usr/local/bin/kitest-desktop-extras.sh >/dev/null 2>&1; then
  if [[ "$(id -u)" -eq 0 ]]; then
    /usr/local/bin/kitest-desktop-extras.sh 2>/dev/null || true
  else
    sudo /usr/local/bin/kitest-desktop-extras.sh 2>/dev/null || true
  fi
fi

touch "$mark"
exit 0
