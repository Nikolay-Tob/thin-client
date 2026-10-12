#!/bin/sh
# One command: builds thin-client.img (flash drive, BIOS+UEFI/Secure Boot) and thin-client.vhd (BIOS VMs).
# Needs: Ubuntu 24.04 (a VM or WSL2 is fine), root, internet, ~8 GB free disk. Takes ~10-15 minutes.
# Usage: sudo ./build-all.sh [output-dir]      (default: ./out)
set -eu
KIT=$(cd "$(dirname "$0")" && pwd)
OUTDIR=$(mkdir -p "${1:-./out}" && cd "${1:-./out}" && pwd)
[ "$(id -u)" = 0 ] || { echo "Run as root: sudo $0" >&2; exit 1; }
export OUT=${OUT:-$OUTDIR/work}
export R=${R:-$OUT/rootfs}
export DEBIAN_FRONTEND=noninteractive
mkdir -p "$OUT"
echo "== host packages"
apt-get update -qq || true
apt-get install -y -qq debootstrap qemu-utils dosfstools e2fsprogs squashfs-tools grub-pc-bin grub-efi-amd64-bin \
    grub-common mtools fdisk shim-signed grub-efi-amd64-signed zstd python3
sh "$KIT/build-rootfs.sh"
sh "$KIT/build-image.sh"
cp "$OUT/build/disk.img" "$OUTDIR/thin-client.img"
echo "== VHD (dynamic, 4 GiB virtual size; the data partition grows to fill it on first boot)"
cp "$OUT/build/disk.img" "$OUT/build/vhd-src.img"
truncate -s 4096M "$OUT/build/vhd-src.img"
qemu-img convert -f raw -O vpc -o subformat=dynamic,force_size=on "$OUT/build/vhd-src.img" "$OUTDIR/thin-client.vhd"
rm -f "$OUT/build/vhd-src.img"
ls -lh "$OUTDIR/thin-client.img" "$OUTDIR/thin-client.vhd"
echo "DONE: $OUTDIR/thin-client.img  $OUTDIR/thin-client.vhd   (you can delete $OUT to free space)"
