#!/bin/bash
# Runs inside Calamares target chroot. KITEST_PC is comma-separated packagechooser ids (legacy).
set -u
choices="${KITEST_PC:-}"
if [[ -z "$choices" ]]; then
  exit 0
fi

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

IFS=',' read -ra IDS <<<"$choices"
for id in "${IDS[@]}"; do
  id="${id//[[:space:]]/}"
  [[ -z "$id" ]] && continue
  case "$id" in
    brave) flatpak install -y --noninteractive --system flathub com.brave.Browser ;;
    steam) flatpak install -y --noninteractive --system flathub com.valvesoftware.Steam ;;
    flatseal) flatpak install -y --noninteractive --system flathub com.github.tchx84.Flatseal ;;
    oneko) flatpak install -y --noninteractive --system flathub com.daidouji.oneko ;;
  esac
done

update-desktop-database /var/lib/flatpak/exports/share/applications 2>/dev/null || true

if [[ -f /var/lib/flatpak/exports/share/applications/com.brave.Browser.desktop ]]; then
  printf '%s\n' 'export BROWSER="flatpak run com.brave.Browser"' >/etc/profile.d/flatpak-browser-brave.sh
fi

exit 0
