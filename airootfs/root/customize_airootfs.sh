#!/bin/bash
set -e

# -------------------------
# CALAMARES: install profile module *.conf after pacstrap (see usr/share/kitest/calamares-modules/)
# mkarchiso copies airootfs before pacstrap; the calamares package ships the same paths under
# /etc/calamares/modules/ — pre-seeding them caused "exists in filesystem" during pacstrap.
# -------------------------
if [[ -d /usr/share/kitest/calamares-modules ]]; then
  install -d -m0755 /etc/calamares/modules
  cp -a /usr/share/kitest/calamares-modules/. /etc/calamares/modules/
fi

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
# KERNEL: ensure archiso bootloader finds vmlinuz-linux
# -------------------------
kernel_image="$(ls -1 /usr/lib/modules/*/vmlinuz 2>/dev/null | head -n 1 || true)"
if [[ -n "${kernel_image:-}" ]]; then
  install -Dm644 "$kernel_image" /boot/vmlinuz-linux
fi

# -------------------------
# Qt / Plasma: Breeze default — Kvantum + Catppuccin + QT_STYLE_OVERRIDE caused black/partial UI
# (QEMU virtio, missing GL, Wayland quirks). Re-enable manually after login: kvantum, qt6ct, etc.
# -------------------------
rm -f /etc/environment.d/99-kvantum.conf 2>/dev/null || true
install -d -m0755 /etc/environment.d
cat <<'EOF' >/etc/environment.d/99-qt.conf
# KDE platform integration only; no QT_STYLE_OVERRIDE (lets Qt use Plasma Breeze).
QT_QPA_PLATFORMTHEME=kde
EOF

# -------------------------
# OPTIONAL THEMES: bundle Catppuccin Kvantum (do not auto-apply)
# Enable with: KITEST_BUNDLE_CATPPUCCIN_KVANTUM=1
# -------------------------
if [[ "${KITEST_BUNDLE_CATPPUCCIN_KVANTUM:-0}" == "1" ]]; then
  install -d -m0755 /usr/share/kitten-themes/kvantum
  tmpdir="$(mktemp -d)"
  if git clone --depth 1 https://github.com/catppuccin/kvantum.git "$tmpdir/kvantum" 2>/dev/null; then
    cp -a "$tmpdir/kvantum/themes/." /usr/share/kitten-themes/kvantum/ 2>/dev/null || true
  fi
  rm -rf "$tmpdir"
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
systemctl enable qemu-guest-agent 2>/dev/null || true

# -------------------------
# FLATPAK: remote only on live; app installs default to Calamares target (or KITEST_DESKTOP_EXTRAS=1)
# -------------------------
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
chmod +x /usr/local/bin/kitest-desktop-extras.sh
chmod +x /usr/local/bin/kitten-theme-selector 2>/dev/null || true
if [[ "${KITEST_DESKTOP_EXTRAS:-}" == "1" ]]; then
  /usr/local/bin/kitest-desktop-extras.sh || true
fi

install -d -m0755 /etc/profile.d
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
