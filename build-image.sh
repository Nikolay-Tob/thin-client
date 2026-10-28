#!/bin/sh
# Assemble the bootable disk image from root.sqsh + boot files: BIOS (embedded GRUB) and UEFI (signed shim/GRUB, Secure Boot).
# Layout: MBR; p1 ESP FAT32 "KIOSKBOOT" (128M), p2 squashfs root, p3 ext4 "KIOSKDATA" (grows to fill the device on first boot).
set -eu
KIT=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-/work}
W=$OUT/build; mkdir -p "$W"; cd "$W"
rm -f disk.img esp.img data.img core.img
ESP_MIB=128; DATA_MIB=128
ROOT_BYTES=$(stat -c %s "$OUT/root.sqsh"); ROOT_MIB=$(( (ROOT_BYTES + 1048575) / 1048576 ))
TOTAL_MIB=$((1 + ESP_MIB + ROOT_MIB + DATA_MIB))
echo "root=${ROOT_MIB}MiB total=${TOTAL_MIB}MiB"

# --- ESP: signed shim + GRUB (UEFI / Secure Boot), grub.cfg, kernel, initrd
truncate -s ${ESP_MIB}M esp.img
mkfs.vfat -F 32 -n KIOSKBOOT esp.img >/dev/null
mmd -i esp.img ::/EFI ::/EFI/BOOT ::/EFI/ubuntu ::/boot ::/boot/grub ::/boot/grub/fonts
mcopy -i esp.img /usr/lib/shim/shimx64.efi.signed ::/EFI/BOOT/BOOTX64.EFI
mcopy -i esp.img /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed ::/EFI/BOOT/grubx64.efi
mcopy -i esp.img /usr/lib/shim/mmx64.efi ::/EFI/BOOT/mmx64.efi
for d in boot/grub EFI/BOOT EFI/ubuntu; do mcopy -i esp.img "$KIT/boot/grub.cfg" ::/$d/grub.cfg; done
mcopy -i esp.img /usr/share/grub/unicode.pf2 ::/boot/grub/unicode.pf2
mcopy -i esp.img "$OUT/bootfiles/vmlinuz" ::/boot/vmlinuz
mcopy -i esp.img "$OUT/bootfiles/initrd.img" ::/boot/initrd.img

# --- data partition (ext4)
rm -rf dd; mkdir -p dd/kiosk dd/nm
chown 1000:1000 dd/kiosk; chmod 700 dd/kiosk; chown 0:0 dd/nm; chmod 755 dd/nm
mke2fs -q -t ext4 -L KIOSKDATA -E root_owner=0:0 -d dd data.img ${DATA_MIB}M

# --- disk with MBR; disk id 4b50d0c1 makes root=PARTUUID=4b50d0c1-02
truncate -s ${TOTAL_MIB}M disk.img
sfdisk -q disk.img <<EOF
label: dos
label-id: 0x4b50d0c1
unit: sectors

start=2048, size=$((ESP_MIB*2048)), type=ef, bootable
start=$((2048+ESP_MIB*2048)), size=$((ROOT_MIB*2048)), type=83
start=$((2048+ESP_MIB*2048+ROOT_MIB*2048)), size=$((DATA_MIB*2048)), type=83
EOF
dd if=esp.img of=disk.img bs=1M seek=1 conv=notrunc status=none
dd if="$OUT/root.sqsh" of=disk.img bs=1M seek=$((1+ESP_MIB)) conv=notrunc status=none
dd if=data.img of=disk.img bs=1M seek=$((1+ESP_MIB+ROOT_MIB)) conv=notrunc status=none

# --- BIOS GRUB: core.img written straight into the gap after the MBR (no loop devices needed)
grub-mkimage -d /usr/lib/grub/i386-pc -O i386-pc -o core.img -c "$KIT/boot/early.cfg" -p '(hd0,msdos1)/boot/grub' \
  biosdisk part_msdos part_gpt fat ext2 normal configfile linux search search_label search_fs_uuid echo test ls cat boot gzio minicmd \
  font gfxterm all_video video video_fb loadenv terminal
python3 - "$W/disk.img" "$W/core.img" <<'PY'
import struct, sys
disk, corep = sys.argv[1:3]
boot = bytearray(open('/usr/lib/grub/i386-pc/boot.img', 'rb').read())
core = bytearray(open(corep, 'rb').read())
nsec = (len(core) + 511) // 512
assert nsec < 2000, nsec
core += b'\0' * (nsec * 512 - len(core))
struct.pack_into('<Q', boot, 0x5c, 1)                         # core.img starts at LBA 1
struct.pack_into('<QHH', core, 512 - 12, 2, nsec - 1, 0x820)  # blocklist: the rest of core.img
with open(disk, 'r+b') as f:
    mbr = f.read(512)
    f.seek(0); f.write(bytes(boot[:440]) + mbr[440:512])      # keep disk id + partition table
    f.seek(512); f.write(core)
print("BIOS grub embedded: core", nsec, "sectors")
PY
echo BUILD_OK; ls -lh disk.img
