#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/usr/share/kitest/install-config.sh"
[[ -r "${CONFIG_FILE}" ]] && . "${CONFIG_FILE}"

KITEST_REQUIRE_PACKAGES="${KITEST_REQUIRE_PACKAGES:-flatpak xorg-xrandr}"
KITEST_FLATPAK_DEFAULT_APPS="${KITEST_FLATPAK_DEFAULT_APPS:-com.brave.Browser com.valvesoftware.Steam com.github.tchx84.Flatseal}"
KITEST_FLATPAK_EXTRA_APPS="${KITEST_FLATPAK_EXTRA_APPS:-com.daidouji.oneko}"
KITEST_ENABLE_FLATHUB="${KITEST_ENABLE_FLATHUB:-1}"
KITEST_INSTALL_DEFAULT_BUNDLE="${KITEST_INSTALL_DEFAULT_BUNDLE:-1}"
KITEST_INSTALL_EXTRA_BUNDLE="${KITEST_INSTALL_EXTRA_BUNDLE:-1}"

echo "[kitest-postinstall] Installing required packages..."
pacman -Sy --noconfirm --needed ${KITEST_REQUIRE_PACKAGES}

if [[ "${KITEST_ENABLE_FLATHUB}" == "1" ]] && command -v flatpak >/dev/null 2>&1; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true

  if [[ "${KITEST_INSTALL_DEFAULT_BUNDLE}" == "1" ]]; then
    flatpak install -y --system --noninteractive flathub ${KITEST_FLATPAK_DEFAULT_APPS} || true
  fi
  if [[ "${KITEST_INSTALL_EXTRA_BUNDLE}" == "1" ]]; then
    flatpak install -y --system --noninteractive flathub ${KITEST_FLATPAK_EXTRA_APPS} || true
  fi
fi

install -d -m0755 /etc/profile.d
cat >/etc/profile.d/qt-platformtheme.sh <<'EOF'
export QT_QPA_PLATFORMTHEME=qt6ct
EOF

install -d -m0755 /etc/skel/.config/environment.d
cat >/etc/skel/.config/environment.d/99-qt.conf <<'EOF'
QT_QPA_PLATFORMTHEME=qt6ct
EOF

echo "[kitest-postinstall] Done."
