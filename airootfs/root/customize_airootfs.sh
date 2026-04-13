#!/bin/bash
set -e

# -------------------------
# KERNEL: ensure archiso bootloader finds vmlinuz-linux
# -------------------------
pick_kernel_image() {
  local -a candidates=()
  local kdir pkgbasefile pkgbase vmlinuz

  for kdir in /usr/lib/modules/*; do
    [[ -d "$kdir" ]] || continue
    vmlinuz="$kdir/vmlinuz"
    [[ -r "$vmlinuz" ]] || continue
    candidates+=("$vmlinuz")
  done

  ((${#candidates[@]})) || return 1
  ((${#candidates[@]} == 1)) && { printf '%s\n' "${candidates[0]}"; return 0; }

  for kdir in /usr/lib/modules/*; do
    pkgbasefile="$kdir/pkgbase"
    [[ -r "$pkgbasefile" ]] || continue
    pkgbase="$(<"$pkgbasefile")"
    if [[ "$pkgbase" == "linux" && -r "$kdir/vmlinuz" ]]; then
      printf '%s\n' "$kdir/vmlinuz"
      return 0
    fi
  done

  for kdir in /usr/lib/modules/*; do
    pkgbasefile="$kdir/pkgbase"
    [[ -r "$pkgbasefile" ]] || continue
    pkgbase="$(<"$pkgbasefile")"
    if [[ "$pkgbase" == linux-kitten-* && -r "$kdir/vmlinuz" ]]; then
      printf '%s\n' "$kdir/vmlinuz"
      return 0
    fi
  done

  ls -1d /usr/lib/modules/* 2>/dev/null | sort -V | tail -n 1 | awk '{print $0"/vmlinuz"}'
}

kernel_image="$(pick_kernel_image 2>/dev/null || true)"
if [[ -z "${kernel_image:-}" || ! -r "$kernel_image" ]]; then
  echo "ERROR: could not locate kernel image under /usr/lib/modules/*/vmlinuz" >&2
  exit 1
fi
install -Dm644 "$kernel_image" /boot/vmlinuz-linux
[[ -r /boot/vmlinuz-linux ]] || { echo "ERROR: /boot/vmlinuz-linux was not created" >&2; exit 1; }

if command -v mkinitcpio >/dev/null 2>&1; then
  if ! mkinitcpio -p linux; then
    echo "ERROR: mkinitcpio -p linux failed — ISO bootloaders require /boot/initramfs-linux.img" >&2
    exit 1
  fi
else
  echo "ERROR: mkinitcpio not found; cannot create initramfs-linux.img" >&2
  exit 1
fi
[[ -r /boot/initramfs-linux.img ]] || { echo "ERROR: /boot/initramfs-linux.img missing after mkinitcpio -p linux" >&2; exit 1; }

# -------------------------
# Qt / Plasma: qt6ct + Kvantum (Catppuccin) on live — use kitten-theme-selector to switch back to Breeze.
# -------------------------
rm -f /etc/environment.d/99-kvantum.conf 2>/dev/null || true
install -d -m0755 /etc/environment.d
cat <<'EOF' >/etc/environment.d/99-qt.conf
QT_QPA_PLATFORMTHEME=qt6ct
EOF

install -d -m0755 /etc/profile.d
cat <<'EOF' >/etc/profile.d/qt-platformtheme.sh
export QT_QPA_PLATFORMTHEME=qt6ct
EOF

_kitest_kvantum_has_themes() {
  local d
  d="$(find "${KVANTUM_SYSTEM_THEMES:-/usr/share/kvantum/themes}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1 || true)"
  [[ -n "$d" ]]
}

if [[ "${KITEST_BUNDLE_CATPPUCCIN_KVANTUM:-1}" != "0" ]]; then
  KVANTUM_SYSTEM_THEMES="/usr/share/kvantum/themes"
  install -d -m0755 "$KVANTUM_SYSTEM_THEMES"

  vendored_tgz="/usr/share/kitest/assets/catppuccin-kvantum.tar.gz"
  vendored_sha="${vendored_tgz}.sha256"

  if [[ -r "$vendored_tgz" ]]; then
    if [[ -r "$vendored_sha" ]] && command -v sha256sum >/dev/null 2>&1; then
      (cd "$(dirname "$vendored_tgz")" && sha256sum -c "$(basename "$vendored_sha")") || {
        echo "ERROR: Catppuccin Kvantum asset checksum failed: $vendored_sha" >&2
        exit 1
      }
    fi

    if command -v tar >/dev/null 2>&1; then
      tmpdir="$(mktemp -d)"
      tar -xzf "$vendored_tgz" -C "$tmpdir"
      if [[ -d "$tmpdir/kvantum/themes" ]]; then
        cp -a "$tmpdir/kvantum/themes/." "$KVANTUM_SYSTEM_THEMES/" 2>/dev/null || true
      else
        found_themes="$(find "$tmpdir" -maxdepth 3 -type d -name themes 2>/dev/null | head -n 1 || true)"
        if [[ -n "${found_themes:-}" ]]; then
          cp -a "$found_themes/." "$KVANTUM_SYSTEM_THEMES/" 2>/dev/null || true
        fi
      fi
      rm -rf "$tmpdir"
    fi
  fi

  if ! _kitest_kvantum_has_themes && [[ "${KITEST_ALLOW_NET_ASSETS:-1}" == "1" ]] && [[ "${KITEST_OFFLINE:-0}" != "1" ]] && command -v git >/dev/null 2>&1; then
    tmpdir="$(mktemp -d)"
    if git clone --depth 1 https://github.com/catppuccin/kvantum.git "$tmpdir/kvantum" 2>/dev/null; then
      cp -a "$tmpdir/kvantum/themes/." "$KVANTUM_SYSTEM_THEMES/" 2>/dev/null || true
    fi
    rm -rf "$tmpdir"
  fi

  install -d -m0755 /usr/share/kitten-themes
  ln -sfn ../kvantum/themes /usr/share/kitten-themes/kvantum
fi

# Seed qt6ct + Kvantum to use themes from the system path only:
#   /usr/share/kvantum/themes/<name>  (also linked from /usr/share/kitten-themes/kvantum)
# Prefer a *mocha* Catppuccin folder when present. Used for /etc/skel (new users) and live user.
_kitest_seed_catppuccin_userconfig() {
  local home_dir="$1"
  local theme_root="/usr/share/kvantum/themes"
  local selected="" d

  [[ -d "$theme_root" ]] || return 0
  shopt -s nullglob
  for d in "$theme_root"/*; do
    [[ -d "$d" ]] || continue
    if [[ "$(basename "$d")" == *[Mm]ocha* ]]; then
      selected="$(basename "$d")"
      break
    fi
  done
  if [[ -z "$selected" ]]; then
    for d in "$theme_root"/*; do
      [[ -d "$d" ]] || continue
      selected="$(basename "$d")"
      break
    done
  fi
  shopt -u nullglob
  [[ -n "$selected" ]] || return 0

  local kcfg="$home_dir/.config"
  install -d -m0755 "$kcfg/Kvantum" "$kcfg/plasma-workspace/env" "$kcfg/qt5ct" "$kcfg/qt6ct"

  cat >"$kcfg/Kvantum/kvantum.kvconfig" <<EOF
[General]
theme=${selected}
EOF

  cat >"$kcfg/plasma-workspace/env/kitten-qt-platformtheme.sh" <<'EOF'
#!/usr/bin/env bash
export QT_QPA_PLATFORMTHEME=qt6ct
EOF
  chmod 755 "$kcfg/plasma-workspace/env/kitten-qt-platformtheme.sh" 2>/dev/null || true

  cat >"$kcfg/qt5ct/qt5ct.conf" <<'EOF'
[Appearance]
standard_dialogs=default
style=kvantum
EOF

  cat >"$kcfg/qt6ct/qt6ct.conf" <<'EOF'
[Appearance]
standard_dialogs=default
style=kvantum
EOF
}

if [[ "${KITEST_BUNDLE_CATPPUCCIN_KVANTUM:-1}" != "0" ]]; then
  _kitest_seed_catppuccin_userconfig "/etc/skel"
fi

# -------------------------
# USER SETUP
# -------------------------
LIVE_USER="${KITEST_LIVE_USER:-kitest}"
LIVE_GROUPS="${KITEST_LIVE_GROUPS:-wheel,audio,video,storage,network}"

if [[ -d /etc/sddm.conf.d ]]; then
  install -d -m0755 /etc/sddm.conf.d
fi
cat <<EOF >/etc/sddm.conf.d/autologin.conf
[Autologin]
User=${LIVE_USER}
Session=plasma.desktop
EOF

useradd -m -G "$LIVE_GROUPS" "$LIVE_USER"
passwd -d "$LIVE_USER"

echo "${LIVE_USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${LIVE_USER}"
chmod 440 "/etc/sudoers.d/${LIVE_USER}"

systemctl enable sddm
systemctl enable qemu-guest-agent 2>/dev/null || true

systemctl disable systemd-networkd.service 2>/dev/null || true
systemctl mask systemd-networkd.service 2>/dev/null || true
systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true

systemctl unmask systemd-resolved.service 2>/dev/null || true
systemctl enable systemd-resolved.service

systemctl unmask NetworkManager.service 2>/dev/null || true
systemctl enable NetworkManager.service
systemctl enable NetworkManager-wait-online.service 2>/dev/null || true

for s in cloud-init-local cloud-init cloud-config cloud-final; do
  systemctl mask "${s}.service" 2>/dev/null || true
done
systemctl mask ModemManager.service 2>/dev/null || true

if [[ "${KITEST_OFFLINE:-0}" != "1" ]]; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
else
  echo "NOTICE: KITEST_OFFLINE=1 — skipping flathub remote-add (run flatpak remote-add on the live session)." >&2
fi
chmod +x /usr/local/bin/kitest-desktop-extras.sh
chmod +x /usr/local/bin/kitest-live-first-run.sh
chmod +x /usr/local/bin/kitest-install-hybrid 2>/dev/null || true
chmod +x /usr/local/bin/kitest-postinstall.sh 2>/dev/null || true
chmod +x /usr/local/bin/kitten-theme-selector 2>/dev/null || true
chmod +x /usr/local/bin/kitten-apply-catppuccin-kvantum 2>/dev/null || true
if [[ "${KITEST_DESKTOP_EXTRAS:-}" == "1" ]]; then
  /usr/local/bin/kitest-desktop-extras.sh || true
fi

install -d -m0755 /etc/profile.d
cat <<'EOF' >/etc/profile.d/flatpak-xdg.sh
# Discover Flatpak apps in menus and for xdg-open (all users)
export XDG_DATA_DIRS="/var/lib/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
EOF

echo 'fastfetch' >> /etc/bash.bashrc

install -d -m0755 "/home/${LIVE_USER}"
cat <<'EOF' >"/home/${LIVE_USER}/.zshrc"
eval "$(starship init zsh)"
fastfetch
EOF

chown "${LIVE_USER}:${LIVE_USER}" "/home/${LIVE_USER}/.zshrc"

runuser -u "$LIVE_USER" -- xdg-user-dirs-update

chown -R "${LIVE_USER}:${LIVE_USER}" "/home/${LIVE_USER}"
