# Kitest profile (archiso)

Arch Linux live ISO profile: Plasma, Tor-forwarded proxy defaults, kernel-hack tooling, Catppuccin-oriented theming.

## Build on Arch (native)

Needs **root** and **Arch Linux** (`pacstrap`, `arch-chroot` from `arch-install-scripts`):

```bash
sudo ./build-iso.sh
```

ISO output: `/var/tmp/kitest-out/` (override with `WORK_DIR` / `OUT_DIR`).

## Build in Docker (Ubuntu, macOS, etc.)

`mkarchiso` → `pacstrap` → `mount` on `/proc` inside the chroot. A plain `docker run` is **not** enough: the default container security profile blocks those mounts, so you get:

`mount: .../proc: permission denied` / `failed to setup chroot`.

Run the container **`--privileged`** (simplest and what upstream archiso docs expect for containers):

```bash
docker run --rm -it --privileged \
  -v "${PWD}:/profile" \
  -v kitest-iso-out:/var/tmp/kitest-out \
  archlinux:latest \
  bash -lc 'pacman -Sy --needed --noconfirm archiso arch-install-scripts && cd /profile && OUT_DIR=/var/tmp/kitest-out ./build-iso.sh'
```

The ISO appears in the named volume `kitest-iso-out`. To copy it to the host directory instead:

```bash
docker run --rm -it --privileged \
  -v "${PWD}:/profile" \
  -v "${PWD}/out:/var/tmp/kitest-out" \
  archlinux:latest \
  bash -lc 'pacman -Sy --needed --noconfirm archiso arch-install-scripts && cd /profile && OUT_DIR=/var/tmp/kitest-out ./build-iso.sh'
```

Then find `out/*.iso` on the host.

### Docker Compose (repeatable builds)

```bash
mkdir -p out
docker compose run --rm build-iso
```

ISOs land in **`./out/`**. Package downloads are cached in the **`kitest-pacman-cache`** volume between runs.

Interactive Arch environment (profile writable, `archiso` preinstalled):

```bash
docker compose --profile dev run --rm dev-shell
```

Rolling base, CI, and “do we fork Arch?” are summarized in [docs/devops.md](docs/devops.md).

## Smoke test (QEMU)

After the build:

```bash
./qemu-smoke.sh /var/tmp/kitest-out/*.iso
```

**Host AMD GPU (VFIO)** for driver testing: bind the card to `vfio-pci`, then e.g. `QEMU_VFIO_GPU=0000:0c:00.0 ./qemu-smoke.sh out/*.iso` or `QEMU_TRY_AMD_VFIO=1 ./qemu-smoke.sh …` if the detected device is already on VFIO. Guest video is on the **passed-through GPU** (not the virtio window).

## Agent skill (Cursor / AI)

Project notes for archiso + this profile: [`.skill/SKILL.md`](.skill/SKILL.md). To load as a Cursor project skill, copy or symlink that folder to `.cursor/skills/kitten-arch-kitest/`.

## CI

- Lint: `.github/workflows/lint.yml`
- ISO build: `.github/workflows/build-archiso.yml` (Arch container with **privileged** so `pacstrap` works)

## Mirrors and big downloads

`pacman.conf` uses **Rackspace and Leaseweb first**, **`geo.mirror.pkgbuild.com` last**, plus **`ParallelDownloads = 3`**, so huge `pacstrap` runs are less likely to hit SSL resets on the CDN mid-transaction.

**Brave**, **Steam**, and **Flatseal** are **Flatpak-only** (Flathub) via `kitest-desktop-extras.sh` so GPU stacks and game deps stay in the runtime, not `multilib` on the host.

**Flatpak** runs during `customize_airootfs.sh` when the build has **clearnet** access; Tor `http(s)_proxy` is **unset** for that step. If the build was offline, run on the live session:

`sudo /usr/local/bin/kitest-desktop-extras.sh`

## Themes (official repos vs AUR)

Catppuccin Kvantum/GTK packages and legacy `gtk-engine-murrine` are **not** in the Arch `extra` repos (many are AUR-only). This profile ships **`kvantum-theme-materia`** plus **Breeze-Dark** GTK (from KDE) and **Papirus-Dark** icons so the ISO builds cleanly. To use Catppuccin on the live system, install the AUR packages or add a custom repo to the profile.
