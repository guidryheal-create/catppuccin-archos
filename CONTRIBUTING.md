# Contributing

Thanks for helping improve this archiso profile.

## Build requirements

- **Arch Linux** (or the official `archlinux` container) with **root** for `mkarchiso` / `pacstrap`.
- **Network** during the build if you use optional assets that fetch from the network (e.g. Catppuccin Kvantum git clone when no vendored tarball is present). Official Arch repos only — no third-party installer repo is required.

Run:

```bash
sudo ./build-iso.sh
```

## Installer

The live image uses **`archinstall`** from official repositories ([extra]). Configuration examples and optional package lists live under **`airootfs/usr/share/kitest/`**.

## Pull requests

- Keep changes focused (one logical change per PR when possible).
- Match existing shell/YAML style.
- If you change `packages.d/*.list`, run `bash scripts/gen-packages.sh` (or `./build-iso.sh`, which regenerates [`packages.x86_64`](packages.x86_64) the same way CI does). Do not hand-edit `packages.x86_64` as the source of truth.
- Document new third-party repos or keys in [`README.md`](README.md).

## Code of conduct

Be respectful. Report problems with **upstream** packages (archinstall, Arch) to their respective trackers after confirming the issue is not caused solely by this profile.
