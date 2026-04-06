# DevOps: Kitest profile vs Arch Linux

## What you are shipping

This repository is an **archiso profile**: it is **not** a fork of `pacman`, the kernel tree, or the Arch package database. Every successful build runs `pacstrap` against the **current** Arch `core` / `extra` mirrors (see `pacman.conf`).

So in practice:

- **“Upgrading the Arch base”** = **rebuild the ISO**. The live image picks up whatever package versions exist on the mirrors at build time (rolling release).
- You do **not** maintain a separate OS branch unless you add **custom repos**, **pinned package versions**, or **forked packages**.

## When you might add process later

| Goal | Typical approach |
|------|-------------------|
| Reproducible builds | Record `pacman -Q` from the chroot or use a fixed snapshot mirror / own repo. |
| Faster CI | Persist `/var/cache/pacman/pkg` (Compose volume `kitest-pacman-cache` does this locally). |
| Stricter QA | Gate merges on `build-iso` + a QEMU smoke boot; optional `arch-repro-status` if you package custom bits. |
| Real fork / derivative | Custom `[custom]` repo in `pacman.conf`, own signing keys, maybe Calamares — out of scope for “profile only”. |

## Docker Compose services

| Service | Command | Purpose |
|---------|---------|---------|
| `build-iso` | `docker compose run --rm build-iso` | Full ISO → `./out/` |
| `dev-shell` | `docker compose --profile dev run --rm dev-shell` | Privileged Arch shell, profile mounted read-write |

Both use **`privileged: true`** (required for `pacstrap`). The named volume **`kitest-pacman-cache`** reuses downloaded packages between runs.

## CI

GitHub Actions **`.github/workflows/build-archiso.yml`** runs the same idea: Arch container, privileged, `mkarchiso` on the checkout. Re-running the workflow is the server-side equivalent of “upgrade base”.

## Relation to Arch upstream

- **archiso / mkarchiso**: follow [archiso](https://gitlab.archlinux.org/archlinux/archiso) release notes if you vendor a git checkout; if you use the `archiso` package from mirrors, it updates with normal Arch updates inside the build container.
- **Breaking profile changes** (rare): read archiso release notes and the Arch news feed before big rebases.

For **now**, no separate “base upgrade” pipeline is required beyond **rebuild when you want a fresher ISO**.
