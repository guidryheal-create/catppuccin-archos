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

## Layered build helpers (fast iteration)

This repo supports a layered workflow (kernel → local repo → ISO) so you don’t pay the full rebuild cost every time.

- **Kernel artifact (rare):**
  - `sudo ./scripts/build-kernel.sh`
- **Refresh local pacman repo DB (sometimes):**
  - `sudo ./scripts/prepare-repo.sh`
- **Build ISO (often):**
  - `sudo ./build-iso.sh`
  - or ISO-only: `sudo ./scripts/build-iso-only.sh` (runs package list generation + `mkarchiso` only)

### WORK_DIR reuse (mkarchiso cache)

`./build-iso.sh` reuses `WORK_DIR` by default.

Control cleanup with `KITEST_CLEAN`:

- `KITEST_CLEAN=none` (default)
- `KITEST_CLEAN=airootfs` (rebuild rootfs layer; keep caches)
- `KITEST_CLEAN=work` / `all` (full wipe)

### Offline-first

To force no network (fail fast if something would require downloading):

- `KITEST_OFFLINE=1 sudo ./build-iso.sh`

Notes:

- EndeavourOS key bootstrap is skipped automatically if `endeavouros-keyring` and `endeavouros-mirrorlist` are already installed on the host.
- Kernel dependency install is skipped when `KITEST_OFFLINE=1` (deps must already be installed if you want to rebuild offline).

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
- **Live networking:** **NetworkManager** + **systemd-resolved** (see `customize_airootfs.sh`); **systemd-networkd** is masked on the live image. `airootfs/etc/systemd/network/*.network` is for targets that enable networkd later; `airootfs/etc/NetworkManager/NetworkManager.conf` applies on live and after install.
- Do **not** edit the user’s plan file in `.cursor/plans/` unless they ask.

## Optional: use this skill in Cursor

Copy or symlink this folder to **`.cursor/skills/kitten-arch-kitest/`** inside the project so Cursor loads it as a project skill.
