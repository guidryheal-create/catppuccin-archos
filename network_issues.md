# 📄 QEMU VM Networking Debug Report (Arch Linux)

## 🖥️ Environment

* Host: Linux (OptiPlex 3020)
* Guest: Arch Linux (QEMU VM / Arch ISO-based system)
* Networking modes tested:

  * QEMU user-mode NAT (`10.0.2.0/24`)
  * QEMU bridge mode attempt (`br0`)
  * libvirt network (`virbr0` detected but not used)

---

## 🔍 Observed Behavior

### ✅ Working

* `dig google.com` succeeds
* `curl https://google.com` succeeds
* pacman works (HTTP/HTTPS mirrors reachable)
* DNS resolution functional via:

  * systemd-resolved
  * stub resolver at `127.0.0.53`
  * upstream DNS: `10.0.2.3` (QEMU)

---

### ❌ Not working

* `ping google.com` fails (100% packet loss)
* `ping 8.8.8.8` fails
* ICMP unreachable from VM

---

## 🧠 Key Technical Findings

### 1. DNS is NOT the issue

* `/etc/resolv.conf` correctly points to `127.0.0.53`
* `systemd-resolved` correctly forwards to `10.0.2.3`
* DNS resolution confirmed working via `dig`

---

### 2. Network mode in use

VM is operating under:

👉 **QEMU user-mode NAT networking**

* Subnet: `10.0.2.0/24`
* Gateway: `10.0.2.2`
* DNS: `10.0.2.3`

---

### 3. ICMP failure is isolated

* TCP traffic works (curl, pacman)
* UDP DNS works (dig)
* ICMP (ping) does not work

➡️ Indicates **ICMP is blocked or not forwarded in QEMU NAT layer**, not a VM misconfiguration.

---

### 4. Bridge networking attempt failed

* `br0` does not exist on host
* QEMU bridge helper error:

  ```
  failed to parse /etc/qemu/bridge.conf
  bridge helper failed
  ```
* No valid Linux bridge configured
* `virbr0` exists but is inactive and belongs to libvirt

---

### 5. Networking stack layering observed

```text
Application (ping / curl / dig)
        ↓
systemd-resolved (127.0.0.53)
        ↓
QEMU DNS (10.0.2.3)
        ↓
QEMU NAT (10.0.2.2)
        ↓
Host network
```

---

## ⚠️ Conclusion

### Root Cause

* VM is using **QEMU user-mode NAT networking**
* NAT stack does **not reliably support ICMP (ping)**

---

### Impact

* DNS: OK
* HTTP/HTTPS: OK
* Package manager: OK
* Ping: broken (expected in this mode)

---

## 🛠️ Recommendations

### Option A — Accept NAT behavior (simplest)

* Ignore ping failures
* Use curl/pacman for validation

---

### Option B — Fix proper networking (recommended)

Implement real bridge:

* Create `br0` bridge on host
* Attach physical NIC
* Use QEMU:

```bash
-netdev bridge,br=br0,id=net0
-device virtio-net-pci,netdev=net0
```

✔ Enables:

* full LAN visibility
* working ping
* no NAT limitations

---

### Option C — Use libvirt networking

* Activate `virbr0`

```bash
sudo virsh net-start default
```

* Use libvirt-managed NAT instead of raw QEMU user networking

---

## 🧪 Validation summary

| Feature             | Status           |
| ------------------- | ---------------- |
| DNS (dig)           | ✅                |
| HTTPS (curl/pacman) | ✅                |
| ICMP (ping)         | ❌                |
| Bridge networking   | ❌ not configured |
| NAT networking      | ✅ active         |

---

## 📌 Final Note

This is not a guest OS issue.
It is a **QEMU networking mode limitation (user-mode NAT)** where ICMP traffic is not reliably supported.
