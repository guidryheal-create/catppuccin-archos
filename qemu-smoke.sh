#!/usr/bin/env bash
# Boot the ISO in QEMU. Default: virtio VGA (no host GPU).
#
# Host GPU passthrough (test AMDGPU stack on real silicon): bind the card to vfio-pci,
# then either set the BDF explicitly or enable AMD auto-pick:
#   QEMU_VFIO_GPU=0000:0c:00.0 ./qemu-smoke.sh kitest.iso
#   QEMU_TRY_AMD_VFIO=1 ./qemu-smoke.sh kitest.iso
#
# BDF format: 0000:bus:dev.fn (from lspci). Needs KVM, IOMMU, and the GPU not in use by the host.
set -euo pipefail
ISO="${1:?Usage: $0 /path/to/kitest-*.iso}"
MEM="${MEM:-4096}"

accel=kvm
[[ -r /dev/kvm ]] || accel=tcg

vfio_gpu="${QEMU_VFIO_GPU:-}"
if [[ -z "$vfio_gpu" && "${QEMU_TRY_AMD_VFIO:-0}" == 1 ]] && command -v lspci >/dev/null; then
  line="$(lspci -nd '1002:' | grep -iE 'vga|display' | head -1 || true)"
  if [[ -n "$line" ]]; then
    bdf_short="${line%% *}"
    if [[ "$bdf_short" == 0000:* ]]; then
      vfio_gpu="$bdf_short"
    else
      vfio_gpu="0000:$bdf_short"
    fi
    dev="/sys/bus/pci/devices/${vfio_gpu}"
    drv="$(readlink -f "$dev/driver" 2>/dev/null || true)"
    if [[ "$drv" != *vfio_pci* ]]; then
      echo "QEMU_TRY_AMD_VFIO: $vfio_gpu is not bound to vfio-pci (driver: ${drv:-none}). Using virtio VGA." >&2
      vfio_gpu=""
    fi
  fi
fi

args=(
  -machine "q35,accel=$accel"
  -m "$MEM"
  -cdrom "$ISO"
  -boot order=d
  -netdev user,id=net0
  -device virtio-net-pci,netdev=net0
)

if [[ -n "$vfio_gpu" ]]; then
  echo "Using VFIO GPU host=$vfio_gpu (output on the passed GPU; no virtio framebuffer)." >&2
  args+=(-vga none -device "vfio-pci,host=$vfio_gpu,multifunction=on,x-vga=on")
else
  args+=(-vga virtio)
fi

exec qemu-system-x86_64 "${args[@]}"
