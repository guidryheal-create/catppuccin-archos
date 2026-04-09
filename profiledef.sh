#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="kitest"
iso_label="KITEST_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Kitest OS"
iso_application="Kitest OS Live / kernel-hack media"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# SquashFS compression: prefer lower-RAM, faster builds than XZ defaults.
# Keep CPU usage bounded to avoid OOM / xz failures on constrained builders.
airootfs_image_tool_options=('-processors' '2' '-comp' 'zstd' '-Xcompression-level' '15')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/kitest-welcome"]="0:0:755"
  ["/usr/local/bin/kitest-desktop-extras.sh"]="0:0:755"
  ["/usr/local/bin/kitest-calamares-flatpak.sh"]="0:0:755"
  ["/usr/local/bin/kitest-calamares-cleanup.sh"]="0:0:755"
  ["/usr/local/bin/kitest-calamares-safe"]="0:0:755"
  ["/usr/local/bin/kitten-apply-catppuccin-kvantum"]="0:0:755"
)
