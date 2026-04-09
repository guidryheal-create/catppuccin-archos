---
name: kitten-arch-kitest
description: >-
  Arch Linux, archiso/mkarchiso, and the choutoulu-profile (Kitest) live ISO.
  Use when editing this repo, pacstrap/arch-chroot issues, Flatpak-on-ISO,
  pacman mirrors, or Docker-based ISO builds.
---

# Arch + Kitest (choutoulu-profile)

## What this repo is

- An **archiso profile** (not a fork of archiso): `profiledef.sh`, `packages.x86_64`, `pacman.conf`, `airootfs/`, `customize_airootfs.sh`.
- **Build**: on **Arch** as **root** — `sudo ./build-iso.sh`, or **`docker compose run --rm build-iso`** (see `docker-compose.yml`; requires `privileged` for pacstrap).
- **Customize hook**: `airootfs/root/customize_airootfs.sh` runs once in the chroot after packages; it is removed afterward by mkarchiso.

## Pacman / mirrors (common failures)

- **`mirrorlist` missing**: this profile uses explicit `Server =` lines in `pacman.conf`, not `/etc/pacman.d/mirrorlist`.
- **SSL reset / connection reset on geo CDN**: `pacman.conf` puts **Rackspace + Leaseweb before** `geo.mirror.pkgbuild.com` and lowers **`ParallelDownloads`** to ease long `pacstrap` runs.
- **Package “target not found”**: verify names on [archlinux.org/packages](https://archlinux.org/packages) — Arch drops/renames packages (e.g. `dwarves` → `pahole`, `nvidia` → `nvidia-open`). **Groups** like `plasma` prompt interactively; use **`plasma-meta`** instead.

## Flatpak on the ISO

- Flathub apps are installed in **`kitest-desktop-extras.sh`** (Brave, Steam, Flatseal, oneko Flatpak). There is **no** global proxy in `/etc/environment` by default.
- If the image was built **offline**, run on live: `sudo /usr/local/bin/kitest-desktop-extras.sh`.
- **Skel autostart** for oneko must use **`flatpak run com.daidouji.oneko`**, not the removed native `oneko` package.

## Conventions here

- **No global Tor/SOCKS proxy** in `/etc/environment`; optional Tor can be offered later (e.g. Calamares bundle) per user.
- **NM + iwd**: `systemd-networkd` is masked; `NetworkManager.conf` sets `wifi.backend=iwd`.
- Do **not** edit the user’s plan file in `.cursor/plans/` unless they ask.

## Optional: use this skill in Cursor

Copy or symlink this folder to **`.cursor/skills/kitten-arch-kitest/`** inside the project so Cursor loads it as a project skill.
