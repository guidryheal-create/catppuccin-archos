Integrated into the profile:

- **`pacman -Sy`** runs in `customize_airootfs.sh` when the build chroot has network (ignored if offline).
- **Catppuccin Kvantum** is cloned from GitHub during customize, themes go to `/usr/share/Kvantum/themes/`, default **`catppuccin-mocha-mauve`** for new users (`KITEST_KVANTUM_THEME` to override).
- **QEMU VFIO**: see `qemu-smoke.sh` (`QEMU_VFIO_GPU`, `QEMU_TRY_AMD_VFIO`).

---

## 1️⃣ Clone the Kvantum themes repo

```bash
cd ~/Documents/choutoulu-profile/airootfs/root/
git clone https://github.com/catppuccin/kvantum.git
```

* This will create a folder `kvantum/themes/` containing all `.kvconfig` theme files.

---

## 2️⃣ Copy themes into Kvantum’s theme directory

Kvantum reads themes from:

```
~/.config/Kvantum/
```

Or system-wide:

```
/usr/share/Kvantum/themes/
```

To add all Catppuccin themes system-wide:

```bash
sudo mkdir -p /usr/share/Kvantum/themes
sudo cp -r ~/Documents/choutoulu-profile/airootfs/root/kvantum/themes/* /usr/share/Kvantum/themes/
```

---

## 3️⃣ Apply a theme (e.g., Mocha)

```bash
kvantummanager
```

* You can select any of the Catppuccin `.kvconfig` themes here.
* Or via command line:

```bash
kvantum-set-theme Catppuccin-Mocha
```

> You can replace `Catppuccin-Mocha` with `Macchiato`, `Frappe`, `Latte`, etc.

---

## 4️⃣ Make it the default for all users

To set it for future users or your live ISO:

```bash
mkdir -p /etc/skel/.config/Kvantum
cp -r /usr/share/Kvantum/themes/* /etc/skel/.config/Kvantum/themes/
echo "Catppuccin-Mocha" > /etc/skel/.config/Kvantum/Kvantum.kvconfig
```

* Every new user will get Catppuccin Mocha preloaded.

---

## 5️⃣ Optional: integrate with KDE

To fully integrate with Plasma:

* Open **System Settings → Application Style → Kvantum**
* Select the theme.
* Then go to **Plasma Style → Colors** → pick matching Catppuccin color scheme (you can export `.colors` from Catppuccin GTK themes).

---

## ✅ Pro tip

Since you’re building a live ISO:

* Add these commands to your **airootfs setup script** (`customize_airootfs.sh`) so Kvantum themes are automatically installed and selected on first boot.

```bash
#!/bin/bash
# Add Catppuccin Kvantum themes system-wide
mkdir -p /usr/share/Kvantum/themes
cp -r /root/kvantum/themes/* /usr/share/Kvantum/themes/
echo "Catppuccin-Mocha" > /etc/skel/.config/Kvantum/Kvantum.kvconfig
```

