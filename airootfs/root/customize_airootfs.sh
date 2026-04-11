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
# CALAMARES: ensure libyaml-cpp is resolvable (EOS binary may not depend on yaml-cpp explicitly).
# Do not run pacman -Sy/-Syu here — partial DB sync can skew ABI vs pacstrapped packages (e.g. libyaml-cpp).
# -------------------------
if [[ -x /usr/bin/calamares ]]; then
  if ! pacman -Q yaml-cpp &>/dev/null; then
    echo "WARNING: yaml-cpp not installed; installing from frozen pacstrap DBs..." >&2
    pacman -S --needed --noconfirm yaml-cpp || {
      echo "ERROR: could not install yaml-cpp (needed for Calamares)." >&2
      exit 1
    }
  fi
  if ldd /usr/bin/calamares 2>/dev/null | grep -q 'libyaml-cpp\.so.*not found'; then
    pacman -S --needed --noconfirm yaml-cpp || true
    if ldd /usr/bin/calamares 2>/dev/null | grep -q 'libyaml-cpp\.so.*not found'; then
      echo "ERROR: /usr/bin/calamares still missing libyaml-cpp after yaml-cpp install (ABI skew?)." >&2
      ldd /usr/bin/calamares 2>/dev/null | grep yaml || true
      exit 1
    fi
  fi
fi

# -------------------------
# CALAMARES branding: fill missing assets from upstream default (same Calamares version as installed).
# Profile ships branding.desc + stylesheet.qss + bundle.yaml; binaries come from the calamares package.
# -------------------------
_branding_dst=/etc/calamares/branding/kitten
_branding_src=/usr/share/calamares/branding/default
if [[ -d "$_branding_dst" && -d "$_branding_src" ]]; then
  shopt -s nullglob
  for f in "$_branding_src"/*.{png,jpg,jpeg,svg,gif,qml}; do
    [[ -f "$f" ]] || continue
    b=$(basename "$f")
    [[ -e "$_branding_dst/$b" ]] || cp -a "$f" "$_branding_dst/"
  done
  shopt -u nullglob
  if [[ -d "$_branding_src/lang" && ! -d "$_branding_dst/lang" ]]; then
    cp -a "$_branding_src/lang" "$_branding_dst/"
  fi
  if [[ -f "$_branding_src/calamares-sidebar.qml" && ! -f "$_branding_dst/calamares-sidebar.qml" ]]; then
    cp -a "$_branding_src/calamares-sidebar.qml" "$_branding_dst/"
  fi
fi

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

  # Prefer a kernel that provides the standard "linux" pkgbase (Arch) if present.
  for kdir in /usr/lib/modules/*; do
    pkgbasefile="$kdir/pkgbase"
    [[ -r "$pkgbasefile" ]] || continue
    pkgbase="$(<"$pkgbasefile")"
    if [[ "$pkgbase" == "linux" && -r "$kdir/vmlinuz" ]]; then
      printf '%s\n' "$kdir/vmlinuz"
      return 0
    fi
  done

  # Prefer our custom kernel if multiple module trees exist.
  for kdir in /usr/lib/modules/*; do
    pkgbasefile="$kdir/pkgbase"
    [[ -r "$pkgbasefile" ]] || continue
    pkgbase="$(<"$pkgbasefile")"
    if [[ "$pkgbase" == linux-kitten-* && -r "$kdir/vmlinuz" ]]; then
      printf '%s\n' "$kdir/vmlinuz"
      return 0
    fi
  done

  # Fallback: pick newest module dir (kernelrelease is the directory name).
  ls -1d /usr/lib/modules/* 2>/dev/null | sort -V | tail -n 1 | awk '{print $0"/vmlinuz"}'
}

kernel_image="$(pick_kernel_image 2>/dev/null || true)"
if [[ -z "${kernel_image:-}" || ! -r "$kernel_image" ]]; then
  echo "ERROR: could not locate kernel image under /usr/lib/modules/*/vmlinuz" >&2
  exit 1
fi
install -Dm644 "$kernel_image" /boot/vmlinuz-linux
[[ -r /boot/vmlinuz-linux ]] || { echo "ERROR: /boot/vmlinuz-linux was not created" >&2; exit 1; }

# INITRAMFS: systemd-boot/syslinux/grub all load /arch/boot/x86_64/initramfs-linux.img (see efiboot/, syslinux/).
# During pacstrap, mkinitcpio hooks run before this script. Our custom kernel package only installs
# /usr/lib/modules/*/vmlinuz (not /boot/vmlinuz-linux), so hooks may produce initramfs-<pkgbase>.img only
# and never run the archiso preset that writes /boot/initramfs-linux.img. Build it now that vmlinuz-linux exists.
if command -v mkinitcpio >/dev/null 2>&1; then
  # /etc/mkinitcpio.d/linux.preset defines PRESETS=('archiso') and archiso_image="/boot/initramfs-linux.img".
  # mkinitcpio does NOT use a separate /etc/mkinitcpio.d/archiso.preset, so invoke the linux preset.
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
# Default: enabled. Disable with: KITEST_BUNDLE_CATPPUCCIN_KVANTUM=0
# -------------------------
if [[ "${KITEST_BUNDLE_CATPPUCCIN_KVANTUM:-1}" != "0" ]]; then
  install -d -m0755 /usr/share/kitten-themes/kvantum

  # Prefer vendored assets for reproducible/offline builds.
  # Place a tarball at assets/catppuccin-kvantum.tar.gz (in the profile repo),
  # plus a sha256 file at assets/catppuccin-kvantum.tar.gz.sha256 containing:
  #   <sha256sum>  catppuccin-kvantum.tar.gz
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
      # Accept either archive root styles:
      # - kvantum/themes/*
      # - <something>/themes/*
      if [[ -d "$tmpdir/kvantum/themes" ]]; then
        cp -a "$tmpdir/kvantum/themes/." /usr/share/kitten-themes/kvantum/ 2>/dev/null || true
      else
        found_themes="$(find "$tmpdir" -maxdepth 3 -type d -name themes 2>/dev/null | head -n 1 || true)"
        if [[ -n "${found_themes:-}" ]]; then
          cp -a "$found_themes/." /usr/share/kitten-themes/kvantum/ 2>/dev/null || true
        fi
      fi
      rm -rf "$tmpdir"
    fi
  else
    # Fallback: try fetching from network if allowed.
    if [[ "${KITEST_ALLOW_NET_ASSETS:-1}" == "1" ]] && command -v git >/dev/null 2>&1; then
      tmpdir="$(mktemp -d)"
      if git clone --depth 1 https://github.com/catppuccin/kvantum.git "$tmpdir/kvantum" 2>/dev/null; then
        cp -a "$tmpdir/kvantum/themes/." /usr/share/kitten-themes/kvantum/ 2>/dev/null || true
      fi
      rm -rf "$tmpdir"
    fi
  fi
fi

# -------------------------
# USER SETUP
# -------------------------
LIVE_USER="${KITEST_LIVE_USER:-kitest}"
LIVE_GROUPS="${KITEST_LIVE_GROUPS:-wheel,audio,video,storage,network}"

# Update configs that must contain a concrete username (no variable expansion at runtime).
if [[ -d /etc/sddm.conf.d ]]; then
  install -d -m0755 /etc/sddm.conf.d
fi
cat <<EOF >/etc/sddm.conf.d/autologin.conf
[Autologin]
User=${LIVE_USER}
Session=plasma.desktop
EOF

# Calamares removeuser module: ensure it removes the live user on the installed system.
if [[ -f /etc/calamares/modules/removeuser.conf ]]; then
  sed -i "s/^username: .*/username: ${LIVE_USER}/" /etc/calamares/modules/removeuser.conf || true
fi

useradd -m -G "$LIVE_GROUPS" "$LIVE_USER"
passwd -d "$LIVE_USER"

echo "${LIVE_USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${LIVE_USER}"
chmod 440 "/etc/sudoers.d/${LIVE_USER}"

# -------------------------
# SERVICES (slim live: optional stacks install via Calamares on target)
# -------------------------
systemctl enable sddm
systemctl enable qemu-guest-agent 2>/dev/null || true

# NETWORK: NetworkManager + systemd-resolved on live; do not run systemd-networkd alongside NM.
# - cloud-init (pulled by archiso base metapackage) can reapply network config at boot.
# - ModemManager probes serial/modem devices and often causes virtio ethernet flap (connect/disconnect).
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

pacman -Sy

# -------------------------
# FLATPAK: remote only on live; app installs default to Calamares target (or KITEST_DESKTOP_EXTRAS=1)
# -------------------------
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
chmod +x /usr/local/bin/kitest-desktop-extras.sh
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

# -------------------------
# SHELL CONFIG (BASH DEFAULT)
# -------------------------
echo 'fastfetch' >> /etc/bash.bashrc

# -------------------------
# OPTIONAL ZSH + STARSHIP (installed but not forced)
# -------------------------
install -d -m0755 "/home/${LIVE_USER}"
cat <<'EOF' >"/home/${LIVE_USER}/.zshrc"
eval "$(starship init zsh)"
fastfetch
EOF

chown "${LIVE_USER}:${LIVE_USER}" "/home/${LIVE_USER}/.zshrc"

# -------------------------
# XDG user directories
# -------------------------
runuser -u "$LIVE_USER" -- xdg-user-dirs-update

# -------------------------
# PERMISSIONS FIX
# -------------------------
chown -R "${LIVE_USER}:${LIVE_USER}" "/home/${LIVE_USER}"
