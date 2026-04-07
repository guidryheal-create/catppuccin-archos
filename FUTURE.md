# **Kitten OS: CachyOS-style Performance + System Hardening Report**

## **1️⃣ Kernel & Scheduler (Performance Focus)**

* **BORE** kernel → interactive workloads / gaming.
* **EEVDF** → general-purpose.
* **BMQ** → experimental / niche.
* Keep **only one active kernel** for stability; switch via GRUB menu if needed.

### Current implementation in this repo

This profile now builds and ships a **CachyOS-style hardened+BORE kernel** as a **local pacman package** (built during `./build-iso.sh`), then uses it on the ISO while keeping archiso boot filenames stable (`vmlinuz-linux` / `initramfs-linux.img`).

Kernel sources/config live under:

- `pkgs/linux-kitten-cachy/`

**Kernel tuning for Kitten ISO:**

* CPU Governor: `schedutil` (BORE is optimized for interactive workloads).
* I/O Scheduler: `bfq` for HDD, `mq-deadline`/`noop` for NVMe SSDs.
* Enable `zswap` for faster memory management under load.

---

## **2️⃣ GPU Stack**

* **AMD:** Mesa + Vulkan → low-latency frame pacing.
* **NVIDIA:** nvidia-utils → ensure modules match BORE kernel.
* Steam / Proton ready via Flatpak or system packages.
* Optional kernel patches for GPU preemption (AMD) to improve responsiveness.

---

## **3️⃣ Theme & User Experience Integration**

* **Breeze → BORE kernel:** safe default, no forced QT overrides.
* **Catppuccin Kvantum → user-initiated:** user-only, optional.
* Kitten Theme Selector manages:

  * QT5/6 configs
  * Kvantum themes
  * Plasma env (QT_QPA_PLATFORMTHEME)
* Could extend selector with a **“Performance Profile” menu**:

  * Gaming (BORE + GPU tuning)
  * General-purpose (EEVDF)

---

## **4️⃣ System Hardening (Performance-Friendly)**

Based on your existing Kitten ISO hardening:

### **4.1 User / Permissions**

* Non-root default user (`kitest`) in `wheel,audio,video,storage,network`.
* Passwordless sudo restricted to `/etc/sudoers.d/kitest` for live ISO.
* Skel defaults for config directories (`~/.config`) with safe file permissions.

### **4.2 Networking**

* Mask `systemd-networkd` to avoid conflicts → only use NM + iwd.
* Optional Tor proxy configuration:

```bash
export http_proxy=socks5://127.0.0.1:9050
export https_proxy=socks5://127.0.0.1:9050
```

* Network hardening for live environment: avoid auto-mounting / sharing sensitive paths.

### **4.3 Package Management**

* Pacman refresh on live → ensure reproducible builds.
* Flatpak installs isolated to system / user → reduces permission escalation risk.
* Optional sandboxed Flatpak apps (Brave, Steam, Oneko).

### **4.4 X / QT Environment**

* Avoid forcing QT_STYLE_OVERRIDE globally → prevents breaking Plasma environment.
* User-only platform theme files in `~/.config/plasma-workspace/env`.
* Ensures security boundaries between root configs and user theme.

### **4.5 Autostart & Services**

* Only essential services enabled:

  * `iwd`, `NetworkManager`, `sddm`.
* Removed unnecessary QT/Kvantum autostarts → reduces attack surface.
* Sound / TTS scripts are user-run only.

### **4.6 Filesystem & I/O**

* ISO built read-only → prevents persistence from breaking security assumptions.
* Optional encrypted home or swap partition for persistent installs.
* Scheduler/I/O tweaks do not reduce security; they only enhance responsiveness.

---

## **5️⃣ Recommended Performance + Hardening Balance**

* **Performance:** BORE kernel, GPU preemption, schedutil, bfq/mq-deadline, zswap.
* **Hardening:** non-root user, isolated Flatpak, limited autostarts, no global QT overrides.
* **User UX:** theme selector + optional performance profiles → no root interference.

---

## **6️⃣ Visual Workflow Idea (Kitten ISO Build Flow)**

**Workflow Components:**

```
Kitten Base Arch ISO
      |
      v
[Customize airootfs]
  |--> User + Skel defaults
  |--> Services: iwd, NM, sddm
  |--> Networking hardening (Tor optional)
      |
      v
[Kernel Selection]
  |--> BORE kernel (gaming/interactive)
  |--> Optional: EEVDF / BMQ
      |
      v
[GPU Stack]
  |--> AMD / NVIDIA drivers
  |--> Steam / Flatpak ready
      |
      v
[Theme Selector Integration]
  |--> Breeze (safe)
  |--> Catppuccin Kvantum (user-only)
  |--> Writes QT5/6 + Kvantum + Plasma env
      |
      v
[Performance Profile Hook]
  |--> Optional profile: Gaming / General-purpose
      |
      v
[ISO Build + Bundle Catppuccin Themes (opt-in)]
      |
      v
[Boot Live ISO / Install Kitten OS]
      |
      v
[User Experience]
  |--> Launch Theme Selector
  |--> Choose Profile / Theme
  |--> Log out/in for full effect
```

**Notes:**

* Scheduler choice (BORE/EEVDF) affects CPU responsiveness.
* GPU stack + Flatpak apps run in sandboxed, isolated environment.
* Theme changes are user-only, no global overrides → hardening maintained.


