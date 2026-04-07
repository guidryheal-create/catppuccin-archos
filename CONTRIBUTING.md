# Contributing

Thanks for helping improve this archiso profile.

## Build requirements

- **Arch Linux** (or the official `archlinux` container) with **root** for `mkarchiso` / `pacstrap`.
- **Network** during the build: [`scripts/bootstrap-endeavouros-pacman.sh`](scripts/bootstrap-endeavouros-pacman.sh) loads the [official EOS keyring files](https://github.com/endeavouros-team/keyring) with **`pacman-key --populate endeavouros`**, then **`pacman -U`**’s **`endeavouros-keyring`** and **`endeavouros-mirrorlist`** from a mirror. Skipping this step causes **`invalid or corrupted package (PGP signature)`** because the packages are signed before the EOS keys are trusted. If **`endeavouros-keyring: … exists in filesystem`**, the script passes **`--overwrite`** for the pre-seeded keyring paths so the package can install.

Run:

```bash
sudo ./build-iso.sh
```

Override the mirror used to resolve `.pkg.tar.zst` names (default is Gigenet US):

```bash
sudo env EOS_PKG_BASE='https://mirror.alpix.eu/endeavouros/repo/endeavouros/x86_64' ./build-iso.sh
```

To skip EndeavourOS bootstrap (not recommended; build will fail if `calamares` is still listed):

```bash
sudo env KITEST_SKIP_EOS_SETUP=1 ./build-iso.sh
```

Legacy alias: `KITEST_SKIP_CHAOTIC_SETUP=1` (same behaviour).

## Calamares configuration

This profile ships Calamares modules under [`airootfs/etc/calamares/`](airootfs/etc/calamares/). There is no separate `calamares-config` package: the profile **is** the config. Generic distro configs from packages (if any) are overridden by files in `airootfs/` when present.

## Pull requests

- Keep changes focused (one logical change per PR when possible).
- Match existing shell/YAML style.
- If you change `packages.d/*.list`, run `./build-iso.sh` or regenerate `packages.x86_64` the same way CI does (see [`build-iso.sh`](build-iso.sh)).
- Document new third-party repos or keys in [`README.md`](README.md).

## Code of conduct

Be respectful. Report problems with **upstream** packages (Calamares, EndeavourOS repo, Arch) to their respective trackers after confirming the issue is not caused solely by this profile.
