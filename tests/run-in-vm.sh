#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Ryan Lahfa <ryan.lahfa@numerique.gouv.fr>
#
# SPDX-License-Identifier: MIT

set -euo pipefail

# This is a Sécurix developer VM harness
# to test various changes on variants.
# It makes a fair amount of assumptions (Nix installed, qemu in the shell).
# It will produce a 30GB QCOW2 image by default and use 192.168.50.1/24 if instructed.
#
# Quick start:
# USB_PASSTHROUGH="auto-yubikey" VM_GRAPHICS=true VM_SERIAL=PC140V35 BRIDGE=vmboot ./run-in-vm.sh
# This will ask for a sudo privilege escalation if the bridge is not precreated.
# It will forward any Yubikey device detected on the host.
#
# Future work:
# - upstream this into Sécurix directly.
# - offer an option to test the USB installer with this.
# - use proper graphical acceleration.
# - use virtual-fido to emulate FIDO2 devices.
# - add TPM2 emulation.

# If blank, no bridge is used.
BRIDGE="${BRIDGE:-}"
BRIDGE_ADDR="${BRIDGE_ADDR:-192.168.50.1/24}"
ENABLE_NAT="${ENABLE_NAT:-false}"

VM_RAM="${VM_RAM:-4096}"
VM_CPUS="${VM_CPUS:-2}"

VM_DISK="${VM_DISK:-./vm-disk.qcow2}"
VM_DISK_SIZE="${VM_DISK_SIZE:-30G}"

VM_GRAPHICS="${VM_GRAPHICS:-false}"
VM_SERIAL="${VM_SERIAL:-}"

VM_EXTRA_QEMU_ARGS="${VM_EXTRA_QEMU_ARGS:-}"

OVMF_NIX_ATTR="${OVMF_NIX_ATTR:-OVMF}"

USB_PASSTHROUGH="${USB_PASSTHROUGH:-}"


_die() {
    echo "Error: $*" >&2
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 \
        || _die "Required binary '$1' not found in PATH"
}

SUDO="${SUDO:-}"

need_root() {
    # If SUDO is already set, we don't need to ask again
    if [[ -n "$SUDO" ]]; then
        return
    fi

    echo "[!] Root privileges are required to set up networking."
    echo "    We need this to:"
    echo "      - Create bridge: $BRIDGE"
    echo "      - Assign IP: $BRIDGE_ADDR"
    echo "      - Create TAP interface for the VM"
    echo

    read -p "Proceed with sudo? [Y/n] " ans
    case "${ans,,}" in
        n|no)
            echo "Aborting due to user choice."
            exit 1
            ;;
        *)
            echo "[!] Using sudo for privileged operations."
            SUDO=sudo
            ;;
    esac
}

detect_yubikeys() {
    mapfile -t yk < <(
        for dev in /sys/bus/usb/devices/*; do
            [[ -f "$dev/idVendor" && -f "$dev/idProduct" ]] || continue
            vid=$(cat "$dev/idVendor")
            pid=$(cat "$dev/idProduct")

            case "$vid:$pid" in
                # Common YubiKey IDs
                1050:0407|1050:0408|1050:0120|1050:0116|1050:0200|1050:0402|1050:407*)
                    echo "$vid:$pid"
                    ;;
            esac
        done
    )
    printf "%s\n" "${yk[@]}"
}

build_usb_passthrough_args() {
    local entries=()
    local devs=()

    case "$USB_PASSTHROUGH" in
        auto-yubikey)
            echo "[usb] Auto-detecting attached YubiKey devices." >&2
            mapfile -t devs < <(detect_yubikeys)
            ;;
        all-yubikey)
            echo "[usb] Passing all known YubiKey vendor/product IDs." >&2
            devs=("1050:0407" "1050:0408" "1050:0120" "1050:0116" "1050:0200" "1050:0402")
            ;;
        "")
            return 0
            ;;
        *)
            IFS=',' read -ra devs <<< "$USB_PASSTHROUGH"
            ;;
    esac

    if [[ ${#devs[@]} -eq 0 ]]; then
        echo "[usb] No matching USB devices found." >&2
        return 0
    fi

    # ensure we add a USB controller once
    entries+=(-device qemu-xhci)

    for d in "${devs[@]}"; do
        vid="0x${d%:*}"
        pid="0x${d#*:}"
        echo "[usb] Adding passthrough device: $d" >&2
        entries+=(-device "usb-host,vendorid=${vid},productid=${pid}")
    done

    echo "${entries[@]}"
}

enable_nft_nat() {
    [[ -z "$BRIDGE" ]] && return 0 # NAT can only be done with a bridge.
    [[ "$ENABLE_NAT" != "true" ]] && return 0

    local subnet="${BRIDGE_ADDR%/*}"
    local mask="${BRIDGE_ADDR#*/}"
    local tag="qemu-nat-$BRIDGE"

    echo "[nftables] Enabling NAT for $BRIDGE ($BRIDGE_ADDR)"

    $SUDO nft list table ip nat >/dev/null 2>&1 || \
        $SUDO nft add table ip nat

    $SUDO nft list chain ip nat postrouting >/dev/null 2>&1 || \
        $SUDO nft add chain ip nat postrouting '{ type nat hook postrouting priority srcnat; }'

    # Add if not present
    if ! $SUDO nft list chain ip nat postrouting | grep -q "$tag"; then
        echo "[nftables] Adding NAT rule"
        $SUDO nft add rule ip nat postrouting \
            oif != "$BRIDGE" ip saddr "$subnet/$mask" masquerade \
            comment "$tag"
    else
        echo "[nftables] NAT rule already present"
    fi
}

cleanup_nft_nat() {
    [[ -z "$BRIDGE" ]] && return 0
    [[ "$ENABLE_NAT" != "true" ]] && return 0

    local tag="qemu-nat-$BRIDGE"

    echo "[nftables] Cleaning NAT rule(s) tagged: $tag"

    # If table doesn't exist, skip
    if ! $SUDO nft list table ip nat >/dev/null 2>&1; then
        echo "[nftables] NAT table missing, nothing to clean"
        return 0
    fi

    # If chain missing, skip
    if ! $SUDO nft list chain ip nat postrouting >/dev/null 2>&1; then
        echo "[nftables] POSTROUTING chain missing, nothing to clean"
        return 0
    fi

    # Remove any rules containing our tag
    mapfile -t handles < <(
        $SUDO nft -a list chain ip nat postrouting \
        | grep "$tag" \
        | awk -F'handle' '{print $2}'
    )

    if [[ ${#handles[@]} -eq 0 ]]; then
        echo "[nftables] No NAT rules to delete for tag: $tag"
        return 0
    fi

    for h in "${handles[@]}"; do
        h="${h//[[:space:]]/}"
        echo "[nftables] Removing NAT rule handle: $h"
        $SUDO nft delete rule ip nat postrouting handle "$h" || true
    done
}


ensure_bridge() {
    [[ -z "$BRIDGE" ]] && return 0

    if ! ip link show "$BRIDGE" >/dev/null 2>&1; then
        need_root
        echo "[vmbridge] Creating missing bridge: $BRIDGE"
        $SUDO ip link add name "$BRIDGE" type bridge
        $SUDO ip link set "$BRIDGE" up
    else
        echo "[vmbridge] Using existing bridge: $BRIDGE"
    fi

    if ! ip addr show "$BRIDGE" | grep -q "$BRIDGE_ADDR"; then
        echo "[vmbridge] Assigning IP $BRIDGE_ADDR"
        need_root
        $SUDO ip addr add "$BRIDGE_ADDR" dev "$BRIDGE" || true
    fi
}

create_tap() {
    [[ -z "$BRIDGE" ]] && return 0

    TAP="tap-bureautix"

    if ip link show "$TAP" >/dev/null 2>&1; then
        echo "[vmbridge] TAP exists: $TAP"
    else
        need_root
        echo "[vmbridge] Creating TAP: $TAP"
        $SUDO ip tuntap add dev "$TAP" mode tap user "$USER"
        $SUDO ip link set "$TAP" up
        $SUDO ip link set "$TAP" master "$BRIDGE"
    fi

    cleanup() {
        echo "[vmbridge] Cleaning TAP: $TAP"
        $SUDO ip link set "$TAP" down || true
        $SUDO ip tuntap del dev "$TAP" mode tap || true

        cleanup_nft_nat
    }
    trap cleanup EXIT
}

# Pre-flight checks
require qemu-system-x86_64
require nix

VM_TEMP_DIR=$(mktemp -d)

# Resolve OVMF CODE and VARS from nix-build
OVMF_BUILD_DIR=$(nix-build '<nixpkgs>' -A "$OVMF_NIX_ATTR.fd") || {
    echo "Error: Failed to build OVMF from nixpkgs attribute '$OVMF_NIX_ATTR'" >&2
    exit 1
}

OVMF_CODE="${OVMF_BUILD_DIR}/FV/OVMF_CODE.fd"
OVMF_TEMPLATE_VARS="${OVMF_BUILD_DIR}/FV/OVMF_VARS.fd"
OVMF_VARS="${OVMF_VARS:-}"

ensure_bridge
enable_nft_nat
create_tap
TAP_IFACE="tap-bureautix"

[[ -f "$OVMF_CODE" ]] || _die "OVMF code binary (UEFI firmware) not found: $OVMF_CODE"

# Ensure writable OVMF_VARS exists
if [[ ! -e "$OVMF_VARS" || ! -w "$OVMF_VARS" ]]; then
    OVMF_VARS="$VM_TEMP_DIR/uefi-vars.fd"
    echo "Creating writable UEFI variables at $OVMF_VARS"
    cp "$OVMF_TEMPLATE_VARS" "$OVMF_VARS"
    chmod +w "$OVMF_VARS"
fi

# Ensure persistent disk exists
if [[ ! -f "$VM_DISK" ]]; then
    echo "Creating persistent disk: $VM_DISK ($VM_DISK_SIZE)"
    qemu-img create -f qcow2 "$VM_DISK" "$VM_DISK_SIZE"
fi


# Build QEMU args
QEMU_ARGS=(
  -cpu host
  -accel kvm
  -machine q35
  -m "$VM_RAM"
  -smp "$VM_CPUS"

  # Enable UEFI boot with network option ROMs
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE"
  -drive if=pflash,format=raw,file="$OVMF_VARS"

  # Persistent disk
  -drive file="$VM_DISK",if=none,id=nvme0 \
  -device nvme,drive=nvme0,serial=deadbeef
)

USB_ARGS=($(build_usb_passthrough_args))
QEMU_ARGS+=("${USB_ARGS[@]}")

if [[ -n "$VM_SERIAL" ]]; then
    QEMU_ARGS+=(
      -smbios type=1,serial="$VM_SERIAL"
    )
fi

# Graphics
if [[ "$VM_GRAPHICS" == "true" ]]; then
    QEMU_ARGS+=()
else
    QEMU_ARGS+=(-nographic -serial mon:stdio)
fi

# UEFI PXE boot happens automatically when network device has PXE ROM
# QEMU_ARGS+=(-boot n)

if [[ -n "$BRIDGE" ]]; then
    echo "[vm] Bridge mode active: using TAP interface: $TAP_IFACE"
    QEMU_ARGS+=(
        -netdev tap,id=net0,ifname="$TAP_IFACE",script=no,downscript=no
        -device virtio-net,netdev=net0
    )
else
    echo "[vm] No bridge configured: using user-mode networking"
    QEMU_ARGS+=(
        -netdev user,id=net0,hostfwd=tcp::2222-:22
        -device virtio-net,netdev=net0
    )
fi

# Add extra QEMU args
if [[ -n "$VM_EXTRA_QEMU_ARGS" ]]; then
    QEMU_ARGS+=($VM_EXTRA_QEMU_ARGS)
fi

echo "=================================================="
echo " Starting UEFI PXE test VM"
echo "--------------------------------------------------"
echo " Serial:      ${VM_SERIAL:-<default>}"
echo " RAM:         $VM_RAM MiB"
echo " CPUs:        $VM_CPUS"
echo " Disk:        $VM_DISK"
echo " OVMF_CODE:   $OVMF_CODE"
echo " OVMF_VARS:   $OVMF_VARS"
echo " Bridge:      ${BRIDGE:-<none>}"
echo " NAT enabled: $ENABLE_NAT"
echo " SSH:         localhost:2222"
echo "=================================================="

exec qemu-system-x86_64 "${QEMU_ARGS[@]}" "$@"
