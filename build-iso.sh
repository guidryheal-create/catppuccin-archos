#!/usr/bin/env bash
# Build the Kitest profile. Requires an Arch Linux host (pacstrap, arch-chroot)
# and root. On Ubuntu/Debian use the official archlinux container or GitHub
# Actions workflow .github/workflows/build-archiso.yml instead.
set -euo pipefail
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${WORK_DIR:-/var/tmp/kitest-work}"
OUT_DIR="${OUT_DIR:-/var/tmp/kitest-out}"
LOCALREPO_DIR="${LOCALREPO_DIR:-/var/tmp/kitest-localrepo}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Re-exec with sudo (mkarchiso must run as root)." >&2
  exec sudo env \
    WORK_DIR="$WORK_DIR" OUT_DIR="$OUT_DIR" LOCALREPO_DIR="${LOCALREPO_DIR:-}" \
    KITEST_SKIP_KERNEL_BUILD="${KITEST_SKIP_KERNEL_BUILD:-}" \
    KITEST_FORCE_KERNEL_REBUILD="${KITEST_FORCE_KERNEL_REBUILD:-}" \
    KITEST_KERNEL_BUILD_DIR="${KITEST_KERNEL_BUILD_DIR:-}" \
    KITEST_THEME="${KITEST_THEME:-}" \
    KITEST_OFFLINE="${KITEST_OFFLINE:-}" \
    KITEST_CLEAN="${KITEST_CLEAN:-}" \
    KITEST_KERNEL="${KITEST_KERNEL:-}" KITEST_BRCM_DRIVER="${KITEST_BRCM_DRIVER:-}" \
    bash "$0" "$@"
fi

case "${KITEST_CLEAN:-}" in
  ""|none) ;;
  airootfs)
    rm -rf "$WORK_DIR/x86_64/airootfs" \
      "$WORK_DIR/x86_64/airootfs.sfs" \
      "$WORK_DIR/x86_64/airootfs.sfs"* || true
    ;;
  work|all)
    rm -rf "$WORK_DIR"
    ;;
  *)
    echo "Unknown KITEST_CLEAN=${KITEST_CLEAN}. Use: none|airootfs|work" >&2
    exit 2
    ;;
esac

mkdir -p "$WORK_DIR" "$OUT_DIR" "$LOCALREPO_DIR"

PROFILE_BUILD_DIR="$PROFILE_DIR"
case "${KITEST_THEME:-}" in
  ""|none) ;;
  latte|mocha)
    PROFILE_BUILD_DIR="$WORK_DIR/profile-${KITEST_THEME}"
    rm -rf "$PROFILE_BUILD_DIR"
    mkdir -p "$PROFILE_BUILD_DIR"
    # Stage a themed profile copy under WORK_DIR without preserving ownership.
    # Exclude common large artifacts (e.g. ./out/*.iso) and VCS metadata.
    tar -C "$PROFILE_DIR" \
      --exclude='./.git' \
      --exclude='./out' \
      -cf - . \
      | tar -C "$PROFILE_BUILD_DIR" --no-same-owner -xf -

    # Syslinux theming (menu colors + splash).
    cp -f "$PROFILE_DIR/themes/syslinux/${KITEST_THEME}/archiso_head.cfg" \
      "$PROFILE_BUILD_DIR/syslinux/archiso_head.cfg"
    cp -f "$PROFILE_DIR/themes/syslinux/${KITEST_THEME}/splash.png" \
      "$PROFILE_BUILD_DIR/syslinux/splash.png"

    # Optional theme metadata + wallpaper for live (legacy paths under themes/calamares/).
    install -d -m0755 "$PROFILE_BUILD_DIR/airootfs/usr/share/kitest"
    cp -f "$PROFILE_DIR/themes/calamares/${KITEST_THEME}/branding.desc" \
      "$PROFILE_BUILD_DIR/airootfs/usr/share/kitest/theme-${KITEST_THEME}.branding.desc"
    if [[ -r "$PROFILE_DIR/themes/calamares/${KITEST_THEME}/wallpaper.png" ]]; then
      install -d -m0755 "$PROFILE_BUILD_DIR/airootfs/usr/share/wallpapers/Kitest"
      cp -f "$PROFILE_DIR/themes/calamares/${KITEST_THEME}/wallpaper.png" \
        "$PROFILE_BUILD_DIR/airootfs/usr/share/wallpapers/Kitest/wallpaper-${KITEST_THEME}.png"
    fi
    if [[ -r "$PROFILE_DIR/themes/calamares/${KITEST_THEME}/stylesheet.qss" ]]; then
      cp -f "$PROFILE_DIR/themes/calamares/${KITEST_THEME}/stylesheet.qss" \
        "$PROFILE_BUILD_DIR/airootfs/usr/share/kitest/theme-${KITEST_THEME}.stylesheet.qss"
    fi
    ;;
  *)
    echo "Unknown KITEST_THEME=${KITEST_THEME}. Use: none|latte|mocha" >&2
    exit 2
    ;;
esac

case "${KITEST_KERNEL:-kitten}" in
  kitten|"")
    bash "$PROFILE_DIR/scripts/build-kernel.sh"
    bash "$PROFILE_DIR/scripts/prepare-repo.sh"
    ;;
  stock|linux)
    ;;
  *)
    echo "Unknown KITEST_KERNEL=${KITEST_KERNEL}. Use: kitten|linux" >&2
    exit 2
    ;;
esac
bash "$PROFILE_BUILD_DIR/scripts/gen-packages.sh"

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_BUILD_DIR"
echo "Output directory: $OUT_DIR"
