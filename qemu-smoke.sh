#!/usr/bin/env bash
# Boot ISO in QEMU.
# - Live session works with ISO only.
# - Persistent live requires a writable block device labeled KITEST_PERSIST.
#   Use QEMU_PERSIST=1 (recommended) to auto-create/attach a raw ext4 image, or
#   provide QEMU_PERSIST_IMG=/path/to/raw.img (already formatted/labeled).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  qemu-smoke.sh [--persist] [/path/to/kitest-*.iso]

Environment:
  MEM=4096                 RAM in MiB
  QEMU_CPU=...             override CPU model string

  QEMU_PERSIST=1           auto-create/attach persistence disk (raw ext4, LABEL=KITEST_PERSIST)
  QEMU_PERSIST_IMG=...     path to persistence disk image (raw recommended; must be labeled KITEST_PERSIST)
  QEMU_PERSIST_SIZE=8G     size when auto-creating (default: 8G)
  QEMU_PERSIST_PATH=...    path when auto-creating (default: alongside ISO, *.persist.img)
  QEMU_PERSIST_KEEP=1      keep existing auto persistence image (default: recreate for clean testing)

  QEMU_GPU=virtio          QEMU display device (default: virtio-gl)
  QEMU_GPU=virtio-gl       virtio-vga-gl + gtk GL (often fixes Plasma black screens)
  QEMU_GPU=qxl             QXL (fallback for debugging)

  QEMU_HEADLESS=1          run without GTK window (serial console only)

  QEMU_EXTRA_ARGS=...      extra qemu args (quoted string), e.g. -serial stdio for kernel log on this terminal

  QEMU_HOSTFWD=...         optional extra -netdev user options after id=net0 (comma-separated), e.g.
                             hostfwd=tcp::2222-:22   (host 127.0.0.1:2222 -> guest :22 for ssh)
                             hostfwd=tcp::2222-:22,hostfwd=tcp::8443-:443
EOF
}

persist_enabled=0
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi
if [[ "${1:-}" == "--persist" ]]; then
  persist_enabled=1
  shift
fi

ISO="${1:-}"
if [[ -z "$ISO" ]]; then
  # Auto-pick newest ISO in ./out for convenience.
  if compgen -G "out/kitest-*.iso" >/dev/null; then
    ISO="$(ls -t out/kitest-*.iso 2>/dev/null | head -n 1 || true)"
  fi
fi
if [[ -z "$ISO" || ! -r "$ISO" ]]; then
  echo "ISO not found/readable. Pass path or ensure out/kitest-*.iso exists." >&2
  usage >&2
  exit 2
fi

if [[ "${QEMU_PERSIST:-0}" == 1 ]]; then
  persist_enabled=1
fi

MEM="${MEM:-4096}"

accel=kvm
[[ -r /dev/kvm ]] || accel=tcg

# ---------------- CPU handling ----------------
if [[ -n "${QEMU_CPU:-}" ]]; then
  cpu=$QEMU_CPU
elif [[ "$accel" == kvm ]]; then
  if grep -qiE '^vendor_id\s*:\s*AuthenticAMD' /proc/cpuinfo 2>/dev/null; then
    cpu=host
  else
    cpu=host,-svm
  fi
else
  cpu=qemu64
fi

# ---------------- GPU detection ----------------
vfio_gpu="${QEMU_VFIO_GPU:-}"
vfio_gpu_audio=""

auto_detect_gpu() {
  command -v lspci >/dev/null || return 1

  # Detect first discrete GPU (AMD or NVIDIA)
  local line
  line="$(lspci -nn | grep -iE 'vga|3d|display' | grep -E 'NVIDIA|AMD' | head -1 || true)"
  [[ -z "$line" ]] && return 1

  local bdf_short="${line%% *}"
  if [[ "$bdf_short" != 0000:* ]]; then
    vfio_gpu="0000:$bdf_short"
  else
    vfio_gpu="$bdf_short"
  fi

  # Try to find matching audio function (same slot)
  local slot="${vfio_gpu%.*}"
  local audio_line
  audio_line="$(lspci -nn | grep "^${slot}" | grep -i audio || true)"
  if [[ -n "$audio_line" ]]; then
    vfio_gpu_audio="${slot}.1"
  fi
}

# Auto-detect if requested
if [[ -z "$vfio_gpu" && "${QEMU_TRY_VFIO:-0}" == 1 ]]; then
  auto_detect_gpu
fi

# ---------------- VFIO validation ----------------
check_vfio_bound() {
  local dev="$1"
  local path="/sys/bus/pci/devices/$dev"
  [[ -e "$path" ]] || return 1

  local drv
  drv="$(readlink -f "$path/driver" 2>/dev/null || true)"
  [[ "$drv" == *vfio_pci* ]]
}

if [[ -n "$vfio_gpu" ]]; then
  if ! check_vfio_bound "$vfio_gpu"; then
    echo "GPU $vfio_gpu is not bound to vfio-pci. Falling back to virtio." >&2
    vfio_gpu=""
    vfio_gpu_audio=""
  fi
fi

# ---------------- QEMU args ----------------
args=(
  -machine "q35,accel=$accel"
  -m "$MEM"
  -cpu "$cpu"
  # Attach the ISO in two ways:
  # - as a traditional ATAPI CDROM (-cdrom) (gives /dev/sr0 path)
  # - as a readonly virtio-blk disk (gives /dev/vda path)
  #
  # Some initramfs/kernel combos can fail to expose one of these in early boot.
  -cdrom "$ISO"
  -drive "file=$ISO,if=virtio,media=disk,readonly=on,format=raw"
  -boot order=d
)

# User networking: guest can reach host at 10.0.2.2; optional QEMU_HOSTFWD for host->guest (e.g. SSH).
net_user_args="id=net0,net=10.0.2.0/24,dhcpstart=10.0.2.15"

if [[ -n "${QEMU_HOSTFWD:-}" ]]; then
  net_user_args="${net_user_args},${QEMU_HOSTFWD}"
fi

args+=(
  -netdev "user,${net_user_args}"
  -device e1000,netdev=net0
)

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

persist_label_ok() {
  local img="$1"
  command -v blkid >/dev/null 2>&1 || return 1
  local label
  label="$(blkid -s LABEL -o value "$img" 2>/dev/null || true)"
  [[ "$label" == "KITEST_PERSIST" ]]
}

mk_persist_img() {
  local img="$1"
  local size="$2"
  require_cmd truncate
  require_cmd mkfs.ext4
  echo "Creating persistence disk: $img ($size, LABEL=KITEST_PERSIST)" >&2
  truncate -s "$size" "$img"
  mkfs.ext4 -F -L KITEST_PERSIST "$img" >/dev/null
}

persist_img="${QEMU_PERSIST_IMG:-}"
persist_auto=0
if [[ $persist_enabled -eq 1 && -z "$persist_img" ]]; then
  iso_dir="$(cd -- "$(dirname -- "$ISO")" && pwd -P)"
  iso_base="$(basename -- "$ISO")"
  persist_img="${QEMU_PERSIST_PATH:-$iso_dir/${iso_base}.persist.img}"
  persist_auto=1
fi

if [[ -n "$persist_img" ]]; then
  if [[ $persist_enabled -eq 1 && $persist_auto -eq 1 && "${QEMU_PERSIST_KEEP:-0}" != 1 ]]; then
    rm -f -- "$persist_img"
  fi

  if [[ $persist_enabled -eq 1 && ! -e "$persist_img" ]]; then
    if ! mk_persist_img "$persist_img" "${QEMU_PERSIST_SIZE:-8G}"; then
      # If ISO directory isn't writable (common when ISO owned by root), fall back to /tmp.
      persist_img="/tmp/${iso_base}.persist.img"
      persist_auto=1
      [[ "${QEMU_PERSIST_KEEP:-0}" != 1 ]] && rm -f -- "$persist_img"
      mk_persist_img "$persist_img" "${QEMU_PERSIST_SIZE:-8G}"
    fi
  fi

  if [[ ! -f "$persist_img" ]]; then
    echo "Persistence image is not a regular file: $persist_img" >&2
    exit 1
  fi

  if ! persist_label_ok "$persist_img"; then
    echo "Persistence image does not look like LABEL=KITEST_PERSIST: $persist_img" >&2
    echo "Hint: mkfs.ext4 -F -L KITEST_PERSIST \"$persist_img\"  (or use QEMU_PERSIST=1 to auto-create)" >&2
    exit 1
  fi

  echo "Attaching persistence disk: $persist_img" >&2
  args+=(-drive "if=virtio,format=raw,file=$persist_img,cache=writeback")
fi

# ---------------- GPU passthrough ----------------
if [[ -n "$vfio_gpu" ]]; then
  echo "Using VFIO GPU: $vfio_gpu" >&2

  args+=(-vga none)

  # GPU
  args+=(-device "vfio-pci,host=$vfio_gpu,multifunction=on,x-vga=on")

  # Audio function (if present)
  if [[ -n "$vfio_gpu_audio" && -e "/sys/bus/pci/devices/$vfio_gpu_audio" ]]; then
    echo "Adding GPU audio: $vfio_gpu_audio" >&2
    args+=(-device "vfio-pci,host=$vfio_gpu_audio")
  fi
else
  case "${QEMU_GPU:-virtio-gl}" in
    virtio)
      args+=(-vga virtio)
      ;;
    virtio-gl)
      if [[ "${QEMU_HEADLESS:-0}" == 1 ]]; then
        args+=(-vga virtio)
      else
        args+=(-device virtio-vga-gl -display gtk,gl=on)
      fi
      ;;
    qxl)
      args+=(-vga qxl)
      ;;
    *)
      echo "Unknown QEMU_GPU value: ${QEMU_GPU}" >&2
      echo "Valid: virtio | virtio-gl | qxl" >&2
      exit 2
      ;;
  esac
fi

if [[ "${QEMU_HEADLESS:-0}" == 1 ]]; then
  args+=(-display none -serial mon:stdio)
fi

if [[ -n "${QEMU_EXTRA_ARGS:-}" ]]; then
  # Intentional word-splitting so you can pass: QEMU_EXTRA_ARGS="-serial stdio"
  # shellcheck disable=SC2206
  extra_qemu=( ${QEMU_EXTRA_ARGS} )
  args+=("${extra_qemu[@]}")
fi

exec qemu-system-x86_64 "${args[@]}"
