#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/usr/share/kitest/install-config.sh"
[[ -r "${CONFIG_FILE}" ]] && . "${CONFIG_FILE}"

KITEST_REQUIRE_PACKAGES="${KITEST_REQUIRE_PACKAGES:-flatpak xorg-xrandr}"
KITEST_KERNEL_PACKAGES="${KITEST_KERNEL_PACKAGES:-linux-kitten-cachyos-hardened}"
KITEST_FLATPAK_DEFAULT_APPS="${KITEST_FLATPAK_DEFAULT_APPS:-com.brave.Browser com.valvesoftware.Steam com.github.tchx84.Flatseal}"
KITEST_FLATPAK_EXTRA_APPS="${KITEST_FLATPAK_EXTRA_APPS:-com.daidouji.oneko}"
KITEST_ENABLE_FLATHUB="${KITEST_ENABLE_FLATHUB:-1}"
KITEST_INSTALL_DEFAULT_BUNDLE="${KITEST_INSTALL_DEFAULT_BUNDLE:-1}"
KITEST_INSTALL_EXTRA_BUNDLE="${KITEST_INSTALL_EXTRA_BUNDLE:-1}"
KITEST_DEFAULT_KVANTUM_THEME="${KITEST_DEFAULT_KVANTUM_THEME:-catppuccin-mocha-mauve}"
KITEST_DEFAULT_PLASMA_THEME="${KITEST_DEFAULT_PLASMA_THEME:-Catppuccin-Mocha-Mauve}"
KITEST_DEFAULT_COLOR_SCHEME="${KITEST_DEFAULT_COLOR_SCHEME:-CatppuccinMochaMauve}"
KITEST_WALLPAPER_PATH="${KITEST_WALLPAPER_PATH:-/usr/share/images/wallpaper.png}"
KITEST_LOCKSCREEN_IMAGE="${KITEST_LOCKSCREEN_IMAGE:-/usr/share/images/welcome.png}"

echo "[kitest-postinstall] Installing Kitten kernel + required packages..."
pacman -Sy --noconfirm --needed ${KITEST_KERNEL_PACKAGES} ${KITEST_REQUIRE_PACKAGES}

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

install -d -m0755 /etc/skel/.config/Kvantum
cat >/etc/skel/.config/Kvantum/kvantum.kvconfig <<EOF
[General]
theme=${KITEST_DEFAULT_KVANTUM_THEME}
EOF

install -d -m0755 /etc/skel/.config/plasma-workspace/env
cat >/etc/skel/.config/plasma-workspace/env/kitten-qt-platformtheme.sh <<'EOF'
#!/usr/bin/env bash
export QT_QPA_PLATFORMTHEME=qt6ct
EOF
chmod 0755 /etc/skel/.config/plasma-workspace/env/kitten-qt-platformtheme.sh

install -d -m0755 /etc/skel/.config/autostart-scripts
cat >/etc/skel/.config/autostart-scripts/kitest-theme-setup.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
MARKER="\${XDG_CONFIG_HOME:-\$HOME/.config}/kitest-theme-applied"
[[ -f "\$MARKER" ]] && exit 0
kwrite_cfg=""
if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwrite_cfg="kwriteconfig6"
elif command -v kwriteconfig5 >/dev/null 2>&1; then
  kwrite_cfg="kwriteconfig5"
fi
if [[ -n "\$kwrite_cfg" ]]; then
  "\$kwrite_cfg" --file "\${XDG_CONFIG_HOME:-\$HOME/.config}/kdeglobals" --group KDE --key LookAndFeelPackage "${KITEST_DEFAULT_PLASMA_THEME}" >/dev/null 2>&1 || true
  "\$kwrite_cfg" --file "\${XDG_CONFIG_HOME:-\$HOME/.config}/kdeglobals" --group General --key ColorScheme "${KITEST_DEFAULT_COLOR_SCHEME}" >/dev/null 2>&1 || true
  "\$kwrite_cfg" --file "\${XDG_CONFIG_HOME:-\$HOME/.config}/kscreenlockerrc" --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "${KITEST_LOCKSCREEN_IMAGE}" >/dev/null 2>&1 || true
fi
if command -v plasma-apply-wallpaperimage >/dev/null 2>&1 && [[ -f "${KITEST_WALLPAPER_PATH}" ]]; then
  plasma-apply-wallpaperimage "${KITEST_WALLPAPER_PATH}" >/dev/null 2>&1 || true
fi
touch "\$MARKER"
EOF
chmod 0755 /etc/skel/.config/autostart-scripts/kitest-theme-setup.sh

install -d -m0755 /etc/skel/.config/qt5ct
cat >/etc/skel/.config/qt5ct/qt5ct.conf <<'EOF'
[Appearance]
standard_dialogs=default
style=kvantum
EOF

install -d -m0755 /etc/skel/.config/qt6ct
cat >/etc/skel/.config/qt6ct/qt6ct.conf <<'EOF'
[Appearance]
standard_dialogs=default
style=kvantum
EOF

echo "[kitest-postinstall] Done."
