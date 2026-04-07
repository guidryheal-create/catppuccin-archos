# “Failed to mount root device” / “can’t access TTY” / initramfs emergency

This happens **before** the live system starts — **before** SDDM, Plasma, or anything from [`customize_airootfs.sh`](../airootfs/root/customize_airootfs.sh) (that script only runs **while building** the ISO, not on each boot). It is **not** caused by Kvantum or themes.

The **mkinitcpio-archiso** initramfs must find the ISO (or disk image), mount the **squashfs** (`airootfs.sfs` under `arch/x86_64/` inside the ISO layout), and optionally set up the **overlay** for persistence. If that chain fails, you get an emergency shell or a message about root/TTY.

## How this profile boots (reference)

From [`profiledef.sh`](../profiledef.sh):

- **`iso_label`**: `KITEST_` + `YYYYMM` (e.g. `KITEST_202604`) — FAT volume label of the ISO.
- **`install_dir`**: `arch` — files live under `arch/` on the ISO (e.g. `arch/x86_64/airootfs.sfs`).

Kernel command lines in [`syslinux/archiso_sys-linux.cfg`](../syslinux/archiso_sys-linux.cfg) and [`efiboot/loader/entries/`](../efiboot/loader/entries/) use:

- **`archisobasedir=%INSTALL_DIR%`** → becomes **`archisobasedir=arch`**.
- **`archisosearchuuid=%ARCHISO_UUID%`** → **`mkarchiso` replaces this at build time** with the **ISO filesystem UUID**. The live system **searches by UUID**, not by `iso_label` text in the cmdline, so a stale **`archisolabel=...`** mismatch is **less** of an issue here than on hand-edited configs — but **do not** hand-edit the generated cmdline to a wrong UUID.

Persistence adds:

- **`cow_label=KITEST_PERSIST`** — must match a **real** filesystem label on another partition.

Initramfs hooks are defined in [`airootfs/etc/mkinitcpio.conf.d/archiso.conf`](../airootfs/etc/mkinitcpio.conf.d/archiso.conf) (must include **`archiso`**, **`archiso_loop_mnt`**, etc.).

## Most likely causes

1. **Persistence** — booting **“persistent live”** without a partition labeled **`KITEST_PERSIST`**, wrong label, or wrong device. **Test:** boot **“live session”** only (no `cow_label`). If that works, fix persistence layout/label.
2. **Bad / missing squashfs** — incomplete or corrupted ISO build; **`arch/x86_64/airootfs.sfs`** missing or truncated. **Test:** loop-mount the ISO and `ls arch/x86_64/*.sfs`.
3. **Wrong or edited kernel cmdline** — if you edit GRUB/Syslinux and break **`archisosearchuuid`** or **`archisobasedir`**, the image will not be found.
4. **Unreliable USB** — try **`copytoram`** on the kernel line (see [archiso boot parameters](https://gitlab.archlinux.org/archlinux/mkinitcpio/mkinitcpio-archiso/-/blob/master/docs/README.bootparams)).
5. **VM without ISO attached** — empty CD + wrong boot order.

## Quick checks

| Check | What to do |
|--------|------------|
| Isolate persistence | Boot **live session**, not **persistent live**. |
| ISO contents | Mount ISO: `ls arch/x86_64/` — expect **`airootfs.sfs`** (names may vary slightly; see upstream archiso). |
| Kernel line | In firmware editor, confirm **`archisosearchuuid=...`** matches the **ISO partition UUID** (`blkid` on the USB stick’s first partition). |
| Debug | Append **`rd.debug`** or use **`break=postmount`** (see archiso docs) to stop in initramfs. |
| RAM copy | Append **`copytoram`** to load the image into RAM (helps flaky USB). |

## GRUB loopback / Ventoy

[`grub/loopback.cfg`](../grub/loopback.cfg) / [`grub/grub.cfg`](../grub/grub.cfg) use **`img_dev` / `img_loop`** or **`archisosearchuuid`** depending on boot path. If you chainload from **Ventoy** or **GRUB loopback**, follow that bootloader’s archiso recipe; mismatched **`img_loop`** or UUID causes the same class of failure.

## Related docs

- On the **built ISO**: [`/usr/share/doc/kitest/initramfs-troubleshooting.txt`](../airootfs/usr/share/doc/kitest/initramfs-troubleshooting.txt) (short) and [`persistence.txt`](../airootfs/usr/share/doc/kitest/persistence.txt).
- [README.md — Running the ISO](../README.md) — QEMU / Proxmox, persistence summary.

## mkinitcpio “Possibly missing firmware for module: …” (many lines)

`mkarchiso` builds an initramfs with a **broad** set of kernel modules. **Firmware** for Fibre Channel, SCSI RAID, NICs, etc. is often **not** installed or not needed on your machine. **Warnings for `wd719x`, `qla2xxx`, `ast`, `bfa`, … are usually safe to ignore** for a generic desktop/laptop ISO. See also the README section on this topic.
