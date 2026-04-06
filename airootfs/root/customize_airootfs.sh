#!/bin/bash
set -e

# -------------------------
# NETWORK: NM + iwd only (avoid fighting systemd-networkd)
# -------------------------
systemctl mask systemd-networkd.service
systemctl mask systemd-networkd-wait-online.service

# -------------------------
# PACMAN: refresh core/extra DB (needs network during customize; harmless if offline)
# -------------------------
pacman -Sy --noconfirm 2>/dev/null || true

# -------------------------
# THEMES: Catppuccin Kvantum — system-wide + /etc/skel (before useradd)
# -------------------------
KITEST_KVANTUM_THEME="${KITEST_KVANTUM_THEME:-catppuccin-mocha-mauve}"
KVANTUM_SYSTEM="/usr/share/Kvantum/themes"
install -d -m 0755 "$KVANTUM_SYSTEM"

TMP_KVANTUM="$(mktemp -d)"
trap 'rm -rf "${TMP_KVANTUM}"' EXIT
if git clone --depth 1 https://github.com/catppuccin/kvantum.git "${TMP_KVANTUM}/kvantum"; then
  cp -a "${TMP_KVANTUM}/kvantum/themes/." "$KVANTUM_SYSTEM/" 2>/dev/null || true
fi

install -d -m 0755 /etc/skel/.config/Kvantum
if [[ -d "$KVANTUM_SYSTEM/$KITEST_KVANTUM_THEME" ]]; then
  cat <<EOF >/etc/skel/.config/Kvantum/kvantum.kvconfig
[General]
theme=$KITEST_KVANTUM_THEME
EOF
else
  cat <<'EOF' >/etc/skel/.config/Kvantum/kvantum.kvconfig
[General]
theme=MateriaDark
EOF
fi

# -------------------------
# USER SETUP
# -------------------------
useradd -m -G wheel,audio,video,storage,network kitest
passwd -d kitest

echo "kitest ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/kitest
chmod 440 /etc/sudoers.d/kitest

# -------------------------
# SERVICES (slim live: optional stacks install via Calamares on target)
# -------------------------
systemctl enable iwd
systemctl enable NetworkManager
systemctl enable sddm

# -------------------------
# FLATPAK: remote only on live; app installs default to Calamares target (or KITEST_DESKTOP_EXTRAS=1)
# -------------------------
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
chmod +x /usr/local/bin/kitest-desktop-extras.sh
if [[ "${KITEST_DESKTOP_EXTRAS:-}" == "1" ]]; then
  /usr/local/bin/kitest-desktop-extras.sh || true
fi

install -d -m 0755 /etc/profile.d
cat <<'EOF' >/etc/profile.d/flatpak-xdg.sh
# Discover Flatpak apps in menus and for xdg-open (all users)
export XDG_DATA_DIRS="/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
EOF

# -------------------------
# SHELL CONFIG (BASH DEFAULT)
# -------------------------
echo 'fastfetch' >> /etc/bash.bashrc

# -------------------------
# OPTIONAL ZSH + STARSHIP (installed but not forced)
# -------------------------
cat <<'EOF' > /home/kitest/.zshrc
eval "$(starship init zsh)"
fastfetch
EOF

chown kitest:kitest /home/kitest/.zshrc

# -------------------------
# XDG user directories
# -------------------------
runuser -u kitest -- xdg-user-dirs-update

# -------------------------
# PERMISSIONS FIX
# -------------------------
chown -R kitest:kitest /home/kitest
