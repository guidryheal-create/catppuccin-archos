# Calamares on a custom Arch ISO — expert course notes

Source material: educational walkthrough (Arch ISO + graphical installer). This document separates **what to know** from **what to do**, and lists **gaps** so you can deepen or adapt the material.

---

## Learning outcomes

After this course track you should be able to:

- Explain how **Arch ISO** (`mkarchiso`) and **Calamares** fit together in a live → installed system pipeline.
- Place Calamares **configuration** (`settings.conf`, modules, branding) and know which pieces are **generic** vs **Arch-specific**.
- Plan **packaging**: where the Calamares **binary** comes from (repo vs local build) and how a **settings** package or **profile `airootfs/`** supplies config.
- Integrate Calamares with **live user removal**, **post-install scripts**, and **ISO package lists**.

---

## Part A — Knowledge (concepts)

### A.1 Arch ISO’s role

- **Arch ISO** builds the install medium: it assembles an **airootfs** (tree that becomes the live system), **package lists**, boot loaders, etc.
- Customization happens **before** `mkarchiso` runs: you add packages, files under `airootfs/`, and branding—not after the fact on a released ISO.

### A.2 Why Calamares is “deep”

- Calamares is a **multi-distro** installer framework: many **modules** exist, but **not every module** applies to every distro (partitioning, init, package manager, groups like `wheel` vs `sudo`, etc.).
- **Arch-based** flows differ from Debian-style flows; module choice and **job order** in `settings.conf` must match your target layout and Calamares version.

### A.3 Configuration layout (mental model)

Typical on-disk layout (names may vary):

| Area | Role |
|------|------|
| `settings.conf` | Global settings, **module search paths**, **branding** key, and **sequence** of *show* vs *exec* jobs. |
| `modules/*.conf` | Per-module options; missing file → often **upstream defaults** from the Calamares package. |
| `branding/<name>/` | Product strings, URLs, QML slideshow, images, `branding.desc`, stylesheet colors. |

The **branding** name in `settings.conf` must match the **folder name** under `branding/`.

### A.4 Live session vs installed system

- The ISO often defines a **live user** (e.g. for demos). The **removeuser** (or equivalent) module removes that user on the **target** install so the machine is not left with a known live account.
- **shellprocess** (or similar) runs commands **after** unpack/install steps—useful for **pacman-key**, removing the installer package, one-shot tuning. Environment and **privileges** in that context can differ from an interactive shell (see gaps).

### A.5 Packaging strategy (from the source narrative)

- **Distro maintainers** often ship a **fork or pinned Calamares** plus a **`calamares-settings`** (or equivalent) package.
- A lighter approach: consume **AUR `calamares`** (or another binary repo), build with `makepkg`, sign packages, publish a **small custom repo**, then list `calamares` in the ISO **package list** so the live image installs it via `pacman`.

**Note for this repository (`choutoulu-profile`):** Calamares is **not** in official `[core]`/`[extra]`. This profile uses the **EndeavourOS** repository for a **binary** `calamares` (see `pacman.conf`, `packages.d/50-calamares.list`, `build-iso.sh` / `scripts/bootstrap-endeavouros-pacman.sh`). On a **live VM**, if **`pacman`** reports **`error: target not found: calamares`**, the problem is **repository visibility** (missing **`[endeavouros]`**, unsynced DBs, no network for **`pacman -Sy`**, or PGP trust)—not the same as **`libyaml-cpp.so`** missing **after** the `calamares` package is installed (`yaml-cpp` runtime dependency). **Persistent live** COW can leave **`yaml-cpp`** out of date relative to **`calamares`**; recreate the overlay disk or install **`yaml-cpp`** on the live session.

### A.6 airootfs beyond Calamares

- **`/etc/skel`**: default dotfiles copied when a **new user** is created (matches Calamares **users** module behavior).
- **GRUB** `GRUB_DISTRIBUTOR`, **SDDM** theme, **`display-manager.service`** symlink: branding and session flow for the **live** and **installed** system.
- **`packages.x86_64`** (or split lists): everything the **live** environment needs (desktop, Calamares, partition tools, drivers).

---

## Part B — Skills (procedures)

### B.1 Obtain and build Calamares (AUR / custom repo path)

1. Clone or copy the **AUR `calamares`** directory (PKGBUILD + any extra sources the PKGBUILD references).
2. Run **`makepkg`** in that directory (optionally with signing keys consistent with your repo).
3. Move **`*.pkg.tar.zst`** (+ signatures) into your **custom package repository** layout.
4. On the **ISO profile**, enable that repo in **`pacman.conf`** and add **`calamares`** to the ISO package list.

### B.2 Ship Calamares settings

Two common patterns:

1. **Separate package** (e.g. `dtos-calamares-settings`) that installs files under `/etc/calamares/`.
2. **Profile-only**: bake `/etc/calamares/` (and branding) directly under **`airootfs/`** in the mkarchiso profile.

**This profile:** uses **`airootfs/etc/calamares/`** and copies some module files in **`customize_airootfs.sh`** from **`usr/share/kitest/calamares-modules/`** to avoid `pacstrap` file conflicts—see `README.md` / `customize_airootfs.sh`.

### B.3 Edit `settings.conf`

- Set **branding** to the folder name under `branding/`.
- Define **sequence**: welcome → locale → keyboard → partition → users → summary → install (**show**), then **exec** jobs (unpack, fstab, bootloader, etc.).
- Comment out or omit modules you do not need; verify compatibility with your Calamares **major version**.

### B.4 Tune common modules (examples from the narrative)

| Module / file | Typical edits |
|---------------|----------------|
| **users** | Default groups (`wheel`, `audio`, `video`, …), **sudo** group name, **shell**, **hostname** template, weak-password policy for test VMs. |
| **bootloader** | Menu entry **title** / branding (not “Arch” if you rebranded). |
| **displaymanager** | e.g. **SDDM** vs others. |
| **mount** | Extra mounts, EFI, **Btrfs** subvolumes if used. |
| **packages** | Backend **`pacman`** on Arch. |
| **removeuser** | Name of **live user** to delete after install. |
| **shellprocess** | Scripts for: remove **calamares** / **gparted** from target, **pacman-key** init/populate, dotfile hooks, etc. |

### B.5 Branding pack

- Replace **banner**, **sidebar** art, **slideshow** images; edit **`show.qml`** slide list.
- Edit **`branding.desc`**: `PRODUCT_NAME`, version, codename, support/donate/about URLs, **style** colors (sidebar background/text—relevant to “black sidebar” issues; see gaps).

### B.6 Build the ISO

From the parent of the **profile** directory (names vary):

```bash
sudo mkarchiso -v -w ./output/work -o ./output ./releng
```

Adjust paths to your profile; ensure **output/work** expectations match your `mkarchiso` habits.

### B.7 Validate in a VM

- Boot ISO → **display manager** → login as **live user** → launch or wait for **Calamares** (autostart vs manual depends on profile).
- Walk through **locale**, **keyboard**, **partition**, **user**, **summary**, **install**; confirm **slideshow**, **GRUB/systemd-boot**, **target user**, and **post-install** scripts.

---

## Part C — Reference hooks (map narrative → files)

| Topic | Where it usually lives |
|-------|-------------------------|
| ISO packages | `packages.x86_64`, `packages.d/*.list` |
| Live / installed filesystem overlay | `airootfs/` |
| Pacman repos on the image | `pacman.conf` in profile |
| Calamares global + jobs | `airootfs/etc/calamares/settings.conf` |
| Module snippets | `airootfs/etc/calamares/modules/*.conf` |
| Branding | `airootfs/etc/calamares/branding/<name>/` |
| Post-install commands | `shellprocess*.conf` + scripts in e.g. `/usr/local/bin/` |
| Live user → remove | `removeuser.conf` + profile scripts that substitute username |

---

## Part D — Known pain points (from the narrative)

- **Steep curve**: Arch ISO + Calamares together; allow time for iteration.
- **Black sidebar / unreadable nav**: branding **style** colors vs theme; possible **missing Qt/style** dependency—needs systematic debug (logs, `QT_*` env, platform theme).
- **Shellprocess “works in terminal, fails in Calamares”**: different **environment**, **PATH**, **TTY**, **polkit**, or **chroot** context; treat post-install scripts as **non-interactive** and **idempotent**.
- **Pacman keyring script failed at end of install**: installation may still be **mostly complete**; document manual recovery (`pacman-key` init/populate)—better: fix script context or run steps in **`pacstrap` hooks** / **first-boot** instead of relying on fragile last-step runs.
- **Residual “Arch Linux” strings**: many firmware/menu strings; grep-driven cleanup.

---

## Part E — Missing pieces (what the course does not fully supply)

Use this as a checklist to turn notes into a **maintainable** distro or ISO profile.

1. **Calamares version pinning** — Which **upstream or fork** (EndeavourOS, Manjaro, vanilla) and how you **rebuild** when ABI or modules change.
2. **UEFI vs BIOS matrix** — `bootloader` / `partition` / ESP layout, **systemd-boot vs GRUB**, **Secure Boot** (usually out of scope unless explicitly designed).
3. **Encryption** — LUKS options, key recovery, interaction with **Btrfs** / **swap**.
4. **Networking during install** — Wi‑Fi firmware, **NetworkManager** vs **iwd**, online-only steps; this profile’s `TODO` / `README` mention NM and live networking.
5. **i18n and accessibility** — RTL, high-contrast, screen readers; not covered in the transcript.
6. **Automated testing** — scripted install, disk images, CI; only manual VM shown.
7. **Legal / trademark** — “Arch-based” vs “Arch Linux” branding; redistribution of **binary repos** (keys, licenses).
8. **Updates and security** — Removing Calamares from the **target** is good; also consider **CVE** cadence if you ship a frozen ISO.
9. **Debugging playbook** — `calamares --logfile`, `journalctl`, **chroot** inspection of failed jobs; this repo adds **`kitest-calamares-safe`** and `/tmp/calamares.log` (see `README.md`).
10. **Initramfs / graphics on live** — Black/blank UI can be **GPU/driver/initcpio** (this profile notes **virtio** in `mkinitcpio` for Plasma/Calamares).
11. **Declarative module docs** — Link to **official Calamares settings** docs for your **exact** major version (module renames and deprecations).
12. **First-boot vs Calamares shellprocess** — Prefer **systemd one-shot** or **installer-only** hooks for anything that must run as **root** in a known rootfs.

---

## Suggested practice (skill reinforcement)

1. Change **one** module (e.g. default **shell** or **hostname** pattern), rebuild ISO, verify on VM.
2. Add a **branding.desc** color tweak and confirm sidebar readability.
3. Add a **shellprocess** step that only appends a line to `/etc/motd` on the target; verify it runs and capture **Calamares log** if it fails.
4. Compare your flow to **`airootfs/etc/calamares/settings.conf`** in this repo and note **job order** differences.

---

## External references (authoritative)

- [Arch Wiki — mkarchiso](https://wiki.archlinux.org/title/Archiso)
- [Arch Wiki — Calamares](https://wiki.archlinux.org/title/Calamares)
- [AUR package: calamares](https://aur.archlinux.org/packages/calamares)
- Upstream / forks: check the **exact** package’s upstream URL (EndeavourOS ships a maintained fork; see this repo’s `README.md` for why Chaotic-AUR may not provide `calamares`).
