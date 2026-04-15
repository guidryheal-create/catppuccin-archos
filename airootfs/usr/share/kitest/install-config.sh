#!/usr/bin/env bash
# Deterministic defaults for hybrid install post-install phase.

# Base packages always enforced after archinstall.
KITEST_REQUIRE_PACKAGES="flatpak xorg-xrandr kvantum qt5ct qt6ct"
# Kernel package(s) enforced in Phase 2 so a fresh archinstall becomes Kitten OS.
KITEST_KERNEL_PACKAGES="linux-kitten-cachyos-hardened"
KITEST_DEFAULT_KVANTUM_THEME="catppuccin-mocha-mauve"
KITEST_DEFAULT_PLASMA_THEME="Catppuccin-Mocha-Mauve"
KITEST_DEFAULT_COLOR_SCHEME="CatppuccinMochaMauve"
KITEST_WALLPAPER_PATH="/usr/share/images/wallpaper.png"
KITEST_LOCKSCREEN_IMAGE="/usr/share/images/welcome.png"
KITEST_LOGO_IMAGE="/usr/share/images/logo.png"
KITEST_SPLASH_IMAGE="/usr/share/images/squid.png"

# Flatpak behavior: keep default bundle and add Kitest extra bundle.
KITEST_ENABLE_FLATHUB=1
KITEST_INSTALL_DEFAULT_BUNDLE=1
KITEST_INSTALL_EXTRA_BUNDLE=1

# User-customizable app sets (space-separated Flatpak IDs).
KITEST_FLATPAK_DEFAULT_APPS="com.brave.Browser com.valvesoftware.Steam com.github.tchx84.Flatseal"
KITEST_FLATPAK_EXTRA_APPS="com.daidouji.oneko"
