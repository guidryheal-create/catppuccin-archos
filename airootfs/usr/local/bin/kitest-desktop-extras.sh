#!/usr/bin/env bash
# Flathub: Brave (browser), Steam (games), Flatseal (Flatpak permissions).
# GPU/userspace for Steam is carried by the Flatpak runtime, not multilib on the host.
# Re-run on the live ISO if the image was built offline.
set -euo pipefail

CONFIG_FILE="/usr/share/kitest/install-config.sh"
[[ -r "${CONFIG_FILE}" ]] && . "${CONFIG_FILE}"

KITEST_FLATPAK_DEFAULT_APPS="${KITEST_FLATPAK_DEFAULT_APPS:-com.brave.Browser com.valvesoftware.Steam com.github.tchx84.Flatseal}"
KITEST_FLATPAK_EXTRA_APPS="${KITEST_FLATPAK_EXTRA_APPS:-com.daidouji.oneko}"
KITEST_INSTALL_DEFAULT_BUNDLE="${KITEST_INSTALL_DEFAULT_BUNDLE:-1}"
KITEST_INSTALL_EXTRA_BUNDLE="${KITEST_INSTALL_EXTRA_BUNDLE:-1}"

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy 2>/dev/null || true

if ! flatpak remote-list --system 2>/dev/null | grep -q flathub; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

if [[ "${KITEST_INSTALL_DEFAULT_BUNDLE}" == "1" ]]; then
  flatpak install -y --system --noninteractive flathub ${KITEST_FLATPAK_DEFAULT_APPS} || true
fi
if [[ "${KITEST_INSTALL_EXTRA_BUNDLE}" == "1" ]]; then
  flatpak install -y --system --noninteractive flathub ${KITEST_FLATPAK_EXTRA_APPS} || true
fi

update-desktop-database /var/lib/flatpak/exports/share/applications 2>/dev/null || true
