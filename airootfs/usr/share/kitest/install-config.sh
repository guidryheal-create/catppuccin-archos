#!/usr/bin/env bash
# Deterministic defaults for hybrid install post-install phase.

# Base packages always enforced after archinstall.
KITEST_REQUIRE_PACKAGES="flatpak xorg-xrandr kvantum qt5ct qt6ct"
KITEST_DEFAULT_KVANTUM_THEME="catppuccin-mocha-mauve"

# Flatpak behavior: keep default bundle and add Kitest extra bundle.
KITEST_ENABLE_FLATHUB=1
KITEST_INSTALL_DEFAULT_BUNDLE=1
KITEST_INSTALL_EXTRA_BUNDLE=1

# User-customizable app sets (space-separated Flatpak IDs).
KITEST_FLATPAK_DEFAULT_APPS="com.brave.Browser com.valvesoftware.Steam com.github.tchx84.Flatseal"
KITEST_FLATPAK_EXTRA_APPS="com.daidouji.oneko"
