#!/bin/sh
# thin-client-build.sh - self-extracting builder for the RDP/VNC kiosk thin client (Ubuntu 24.04 based).
# Unpacks the build kit next to this script and builds thin-client.img (USB flash drive: BIOS + UEFI/Secure Boot)
# and thin-client.vhd (BIOS virtual machines).
# Needs: Ubuntu 24.04 (VM or WSL2 is fine), root, internet, ~8 GB free disk. Takes ~10-15 minutes.
# Usage: sudo sh thin-client-build.sh [output-dir]      (default: ./out)
set -eu
[ "$(id -u)" = 0 ] || { echo "Run as root: sudo sh $0 [output-dir]" >&2; exit 1; }
DEST=${KIT_DIR:-$PWD/thin-client-kit}
mkdir -p "$DEST"
echo "== unpacking the kit to $DEST"
cat > "$DEST/README.md" <<'__KIT_EOF__'
# Тонкий клиент на флешке (RDP/VNC, киоск)

Образ на базе Ubuntu 24.04: загружается с USB (BIOS и UEFI, в том числе Secure Boot), сразу подключается
к профилю «при загрузке». Рабочего стола нет. Настройки открываются горячими клавишами.

## Горячие клавиши (работают и во время сеанса)
| Клавиши | Действие |
|---|---|
| Ctrl+Alt+Shift+S | окно настроек и профилей |
| Ctrl+Alt+Shift+N | сетевые настройки (Ethernet, Wi-Fi, статический IP) |
| Ctrl+Alt+Shift+P | питание и система (язык RU/EN, раскладка, перезагрузка, выключение) |
| Ctrl+Alt+Shift+R | переподключиться |
| Ctrl+Alt+Shift+D | отключиться |
| Ctrl+Alt+Shift+Пробел | показать/скрыть окно |
| Esc | вернуться к сеансу |

## Запись на флешку
Образ ~0,9 ГБ, подойдёт любая флешка от 2 ГБ. Раздел с настройками при первом запуске сам расширяется на всё
свободное место. Windows: Rufus или balenaEtcher (режим «DD»). Linux: `sudo dd if=thin-client.img of=/dev/sdX bs=4M status=progress conv=fsync`.
Все данные на флешке будут стёрты.

## Первый запуск
1. Загрузитесь с флешки (в UEFI Secure Boot можно оставить включённым).
2. Окно настроек откроется само: «Добавить», заполните профиль, отметьте «Подключаться при загрузке», «Сохранить».
3. Сеть: DHCP по умолчанию; Wi-Fi и статический IP — вкладка «Сеть». Все настройки хранятся на флешке.

## Меню загрузчика
Скрыто. Нажмите Esc или Shift при старте: безопасный графический режим (nomodeset) и подробный лог загрузки.

## Сборка самостоятельно
Нужны Ubuntu 24.04 (подойдёт виртуальная машина или WSL2), root, интернет и ~8 ГБ места. Около 10–15 минут:

Вариант 1, один файл (самораспаковывающийся скрипт `thin-client-build.sh`):

    sudo sh thin-client-build.sh ./out        # -> out/thin-client.img и out/thin-client.vhd

Вариант 2, из архива с набором:

    tar xzf thin-client-kit.tar.gz && cd kit
    sudo sh build-all.sh ./out

Скрипты не используют loop-устройства. Состав: `build-rootfs.sh` (Ubuntu 24.04 + ядро 7.0 HWE + Xorg/openbox + FreeRDP 3 +
TigerVNC + NetworkManager, корень сжимается в squashfs), `build-image.sh` (разметка, BIOS- и UEFI-загрузчики),
`overlay/` (приложение `opt/kiosk/kiosk.py`, службы systemd, настройки), `boot/` (grub.cfg), `test/` (запуск в QEMU, тестовые VNC/RDP-серверы).
__KIT_EOF__
mkdir -p "$DEST/boot"
cat > "$DEST/boot/early.cfg" <<'__KIT_EOF__'
search --no-floppy --label --set=root KIOSKBOOT
set prefix=($root)/boot/grub
configfile $prefix/grub.cfg
__KIT_EOF__
mkdir -p "$DEST/boot"
cat > "$DEST/boot/grub.cfg" <<'__KIT_EOF__'
# Thin client boot menu (hidden: press Esc/Shift during boot to show it)
set timeout_style=hidden
set timeout=1
set default=0
search --no-floppy --label --set=root KIOSKBOOT

menuentry "Thin client" {
    linux /boot/vmlinuz root=PARTUUID=4b50d0c1-02 rootfstype=squashfs rw rootwait overlayroot=tmpfs:recurse=0 quiet loglevel=3 vt.global_cursor_default=0 systemd.show_status=0 usbcore.autosuspend=-1 fsck.mode=skip
    initrd /boot/initrd.img
}
menuentry "Thin client (safe graphics, nomodeset)" {
    linux /boot/vmlinuz root=PARTUUID=4b50d0c1-02 rootfstype=squashfs rw rootwait overlayroot=tmpfs:recurse=0 quiet loglevel=3 nomodeset vt.global_cursor_default=0 systemd.show_status=0 usbcore.autosuspend=-1 fsck.mode=skip
    initrd /boot/initrd.img
}
menuentry "Thin client (verbose boot log)" {
    linux /boot/vmlinuz root=PARTUUID=4b50d0c1-02 rootfstype=squashfs rw rootwait overlayroot=tmpfs:recurse=0 loglevel=7 usbcore.autosuspend=-1 console=tty0
    initrd /boot/initrd.img
}
__KIT_EOF__
cat > "$DEST/build-all.sh" <<'__KIT_EOF__'
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
__KIT_EOF__
cat > "$DEST/build-image.sh" <<'__KIT_EOF__'
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
mmd -i esp.img ::/EFI ::/EFI/BOOT ::/EFI/ubuntu ::/boot ::/boot/grub
mcopy -i esp.img /usr/lib/shim/shimx64.efi.signed ::/EFI/BOOT/BOOTX64.EFI
mcopy -i esp.img /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed ::/EFI/BOOT/grubx64.efi
mcopy -i esp.img /usr/lib/shim/mmx64.efi ::/EFI/BOOT/mmx64.efi
for d in boot/grub EFI/BOOT EFI/ubuntu; do mcopy -i esp.img "$KIT/boot/grub.cfg" ::/$d/grub.cfg; done
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
  biosdisk part_msdos part_gpt fat ext2 normal configfile linux search search_label search_fs_uuid echo test ls cat boot gzio minicmd
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
__KIT_EOF__
cat > "$DEST/build-rootfs.sh" <<'__KIT_EOF__'
#!/bin/sh
# Build the thin-client root filesystem (Ubuntu 24.04 noble) -> $OUT/root.sqsh and $OUT/bootfiles/{vmlinuz,initrd.img}
# Resumable: finished stages are recorded in $OUT/stamps. Needs root and network access to archive.ubuntu.com.
set -eu
KIT=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-/work}
R=${R:-/srv/rootfs}
export DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
mkdir -p "$OUT/stamps" "$OUT/cache" "$OUT/bootfiles"
log() { echo "== $(date +%T) $*"; }
stage() { [ -f "$OUT/stamps/$1" ]; }
done_stage() { touch "$OUT/stamps/$1"; }
mounts() { mountpoint -q $R/proc || mount -t proc proc $R/proc; mountpoint -q $R/sys || mount -t sysfs sys $R/sys
           mountpoint -q $R/dev || mount --bind /dev $R/dev; mountpoint -q $R/dev/pts || mount -t devpts devpts $R/dev/pts; }
umounts() { for m in dev/pts dev sys proc; do umount $R/$m 2>/dev/null || true; done; }
trap umounts EXIT

if ! stage s1-debootstrap; then
    log debootstrap
    rm -rf "$R"; mkdir -p "$R"
    debootstrap --variant=minbase --arch=amd64 --components=main,universe --cache-dir="$OUT/cache" noble "$R" http://archive.ubuntu.com/ubuntu
    done_stage s1-debootstrap
fi

if ! stage s2-packages; then
    log chroot-setup
    mounts
    cp /etc/resolv.conf $R/etc/resolv.conf
    rm -f $R/etc/apt/sources.list
    cat > $R/etc/apt/sources.list.d/ubuntu.sources <<'EOF'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu
Suites: noble-security
Components: main universe
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    printf '#!/bin/sh\nexit 101\n' > $R/usr/sbin/policy-rc.d; chmod +x $R/usr/sbin/policy-rc.d
    printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\nAcquire::Languages "none";\n' > $R/etc/apt/apt.conf.d/99kiosk
    chroot $R apt-get update -qq
    log base-packages
    chroot $R apt-get install -y -qq overlayroot initramfs-tools zstd
    sed -i 's/^COMPRESS=.*/COMPRESS=zstd/; s/^MODULES=.*/MODULES=most/' $R/etc/initramfs-tools/initramfs.conf
    KVER=$(chroot $R apt-cache depends linux-image-generic-hwe-24.04 | awk '$1=="Depends:" && $2 ~ /^linux-image-[0-9]/ {sub("linux-image-","",$2); print $2; exit}')
    echo "$KVER" > "$OUT/stamps/kver"
    log "kernel $KVER"
    chroot $R apt-get install -y -qq linux-image-$KVER linux-modules-$KVER linux-firmware intel-microcode amd64-microcode
    log desktop-packages
    chroot $R apt-get install -y -qq systemd systemd-sysv udev dbus libpam-systemd polkitd network-manager wpasupplicant iw rfkill \
        wireless-regdb ca-certificates iproute2 kmod pciutils usbutils fdisk xserver-xorg-core xserver-xorg-input-libinput \
        xserver-xorg-video-fbdev xinit x11-xserver-utils x11-xkb-utils xkb-data openbox python3 python3-gi gir1.2-gtk-3.0 \
        python3-cryptography fonts-dejavu-core adwaita-icon-theme librsvg2-common freerdp3-x11 tigervnc-viewer pulseaudio \
        pulseaudio-utils alsa-utils tzdata
    done_stage s2-packages
fi

if ! stage s3-configure; then
    log configure
    mounts
    cp -a "$KIT/overlay/." $R/
    chmod 755 $R/opt/kiosk/kiosk.py $R/opt/kiosk/session.sh $R/usr/local/sbin/kiosk-growdata
    for g in audio video plugdev input render; do chroot $R getent group $g >/dev/null || chroot $R groupadd -r $g; done
    chroot $R id kiosk >/dev/null 2>&1 || chroot $R useradd -m -u 1000 -s /bin/bash -G audio,video,plugdev,input,render kiosk
    chroot $R systemctl enable kiosk.service kiosk-growdata.service NetworkManager.service
    chroot $R systemctl set-default multi-user.target
    chroot $R systemctl mask getty@.service autovt@.service NetworkManager-wait-online.service apt-daily.timer \
        apt-daily-upgrade.timer motd-news.timer e2scrub_all.timer fstrim.timer systemd-remount-fs.service 2>&1 | tail -2
    printf '127.0.0.1 localhost\n127.0.1.1 kiosk\n' > $R/etc/hosts
    ln -sf /usr/share/zoneinfo/UTC $R/etc/localtime; echo UTC > $R/etc/timezone
    mkdir -p $R/data $R/etc/NetworkManager/system-connections
    printf 'LANG=C.UTF-8\n' > $R/etc/default/locale
    log initramfs
    chroot $R update-initramfs -u -k all
    done_stage s3-configure
fi

if ! stage s4-prune; then
    log prune
    mounts
    KVER=$(cat "$OUT/stamps/kver")
    cp $R/boot/vmlinuz-$KVER "$OUT/bootfiles/vmlinuz"
    cp $R/boot/initrd.img-$KVER "$OUT/bootfiles/initrd.img"
    # software-only graphics: drop Mesa/LLVM and Ghostscript (huge, pulled in as library dependencies)
    PK=$(chroot $R dpkg-query -W -f='${Package}\n' 'libllvm*' mesa-libgallium libgl1-mesa-dri 'libgs10*' libgs-common poppler-data libspectre1 2>/dev/null | tr '\n' ' ')
    [ -n "$PK" ] && chroot $R dpkg --force-depends -r $PK 2>&1 | tail -3 || true
    rm -f $R/usr/lib/x86_64-linux-gnu/imlib2/loaders/ps.so
    (cd $R/usr/lib/firmware && rm -rf mellanox netronome qed dpaa2 cxgb4 bnx2x liquidio nvidia qcom mrvl/prestera)
    chroot $R apt-get clean
    rm -rf $R/boot/* $R/usr/share/man $R/usr/share/info $R/usr/share/lintian $R/usr/share/doc-base
    find $R/usr/share/doc -type f ! -name copyright -delete; find $R/usr/share/doc -type d -empty -delete 2>/dev/null || true
    find $R/usr/share/locale -mindepth 1 -maxdepth 1 ! -name locale.alias -exec rm -rf {} +
    rm -rf $R/var/lib/apt/lists/* $R/var/cache/apt/* $R/var/cache/debconf/*-old $R/var/lib/dpkg/*-old $R/tmp/* $R/root/.cache 2>/dev/null || true
    find $R/var/log -type f -exec truncate -s 0 {} + 2>/dev/null || true
    rm -f $R/usr/sbin/policy-rc.d $R/etc/resolv.conf
    ln -s ../run/NetworkManager/resolv.conf $R/etc/resolv.conf
    : > $R/etc/machine-id; rm -f $R/var/lib/dbus/machine-id; ln -sf /etc/machine-id $R/var/lib/dbus/machine-id
    done_stage s4-prune
fi

# always refresh our own files (cheap, idempotent) so edits to overlay/ end up in the image
cp -a "$KIT/overlay/." $R/
chmod 755 $R/opt/kiosk/kiosk.py $R/opt/kiosk/session.sh $R/usr/local/sbin/kiosk-growdata
umounts
log squashfs
rm -f "$OUT/root.sqsh"
mksquashfs $R "$OUT/root.sqsh" -comp zstd -Xcompression-level 12 -b 256K -noappend -no-xattrs -quiet
ls -lh "$OUT/root.sqsh"
echo ROOTFS_DONE
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/NetworkManager/conf.d"
: > "$DEST/overlay/etc/NetworkManager/conf.d/10-dns-resolved.conf"
mkdir -p "$DEST/overlay/etc/NetworkManager/conf.d"
: > "$DEST/overlay/etc/NetworkManager/conf.d/10-globally-managed-devices.conf"
mkdir -p "$DEST/overlay/etc/NetworkManager/conf.d"
cat > "$DEST/overlay/etc/NetworkManager/conf.d/kiosk.conf" <<'__KIT_EOF__'
[main]
plugins=keyfile
dns=default
[device]
wifi.scan-rand-mac-address=no
[connectivity]
enabled=false
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/X11/xorg.conf.d"
cat > "$DEST/overlay/etc/X11/xorg.conf.d/10-kiosk.conf" <<'__KIT_EOF__'
Section "ServerFlags"
    Option "DontVTSwitch" "true"
    Option "DontZap" "true"
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
EndSection
__KIT_EOF__
mkdir -p "$DEST/overlay/etc"
cat > "$DEST/overlay/etc/fstab" <<'__KIT_EOF__'
# Root is a read-only squashfs with a RAM overlay (overlayroot).
# The persistent data partition (LABEL=KIOSKDATA) is mounted on /data by kiosk-growdata.service.
__KIT_EOF__
mkdir -p "$DEST/overlay/etc"
cat > "$DEST/overlay/etc/hostname" <<'__KIT_EOF__'
kiosk
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/polkit-1/rules.d"
cat > "$DEST/overlay/etc/polkit-1/rules.d/50-kiosk.rules" <<'__KIT_EOF__'
polkit.addRule(function(action, subject) {
    if (subject.user == "kiosk" &&
        (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 ||
         action.id.indexOf("org.freedesktop.login1.") == 0)) {
        return polkit.Result.YES;
    }
});
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/sysctl.d"
cat > "$DEST/overlay/etc/sysctl.d/90-kiosk.conf" <<'__KIT_EOF__'
kernel.sysrq = 0
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/systemd/journald.conf.d"
cat > "$DEST/overlay/etc/systemd/journald.conf.d/kiosk.conf" <<'__KIT_EOF__'
[Journal]
Storage=volatile
RuntimeMaxUse=16M
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/systemd/logind.conf.d"
cat > "$DEST/overlay/etc/systemd/logind.conf.d/kiosk.conf" <<'__KIT_EOF__'
[Login]
NAutoVTs=0
ReserveVT=0
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleLidSwitch=ignore
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/systemd/system/NetworkManager.service.d"
cat > "$DEST/overlay/etc/systemd/system/NetworkManager.service.d/kiosk.conf" <<'__KIT_EOF__'
[Unit]
After=kiosk-growdata.service
Wants=kiosk-growdata.service
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/systemd/system"
cat > "$DEST/overlay/etc/systemd/system/kiosk-growdata.service" <<'__KIT_EOF__'
[Unit]
Description=Prepare persistent data partition (grow, check, mount)
After=systemd-udevd.service systemd-udev-trigger.service local-fs.target
Before=NetworkManager.service kiosk.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/kiosk-growdata
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/systemd/system"
cat > "$DEST/overlay/etc/systemd/system/kiosk.service" <<'__KIT_EOF__'
[Unit]
Description=Thin client kiosk session (Xorg + launcher)
After=systemd-user-sessions.service systemd-logind.service kiosk-growdata.service NetworkManager.service
Wants=kiosk-growdata.service
Wants=NetworkManager.service

[Service]
User=kiosk
PAMName=login
TTYPath=/dev/tty1
StandardInput=tty
StandardOutput=journal
StandardError=journal
UtmpIdentifier=tty1
UtmpMode=user
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
ExecStart=/usr/bin/xinit /opt/kiosk/session.sh -- /usr/bin/Xorg :0 vt1 -keeptty -nolisten tcp -noreset
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
__KIT_EOF__
mkdir -p "$DEST/overlay/etc/udev/rules.d"
cat > "$DEST/overlay/etc/udev/rules.d/90-kiosk-usb.rules" <<'__KIT_EOF__'
# allow the kiosk user to redirect any USB device into the remote session
SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", MODE="0666"
__KIT_EOF__
mkdir -p "$DEST/overlay/opt/kiosk"
cat > "$DEST/overlay/opt/kiosk/kiosk.py" <<'__KIT_EOF__'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Thin-client kiosk: connection profiles (RDP/VNC), network and system settings.

Runs inside a bare X session (openbox). Hotkeys call `kiosk.py --ctl <cmd>`,
which talks to the running instance over a unix datagram socket.
"""
import os
import sys
import socket

SOCK = "/tmp/kiosk-ctl.sock"

if len(sys.argv) >= 3 and sys.argv[1] == "--ctl":
    _s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    try:
        _s.sendto(sys.argv[2].encode(), SOCK)
    except OSError:
        sys.exit(1)
    sys.exit(0)

import json
import re
import time
import uuid
import ipaddress
import subprocess
import threading

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib, Gdk  # noqa: E402

VERSION = "1.2"


def _wait_data():
    """The data partition is mounted by systemd; give it a moment on slow media."""
    if os.path.exists("/dev/disk/by-label/KIOSKDATA"):
        for _ in range(60):
            if os.path.ismount("/data"):
                break
            time.sleep(0.5)
    return os.path.ismount("/data")


PERSISTENT = _wait_data()
DATA_DIR = "/data/kiosk" if PERSISTENT else os.path.expanduser("~/.config/kiosk")
CONF = os.path.join(DATA_DIR, "config.json")
CLIENT_LOG = "/tmp/kiosk-client.log"
VNC_PASS = "/tmp/kiosk-vncpass"
# one saved NetworkManager profile per link type, not bound to an interface name
# (interface names differ between computers the flash drive is moved to)
NM_PROFILE = {"ethernet": "kiosk-ethernet", "wifi": "kiosk-wifi"}

# NB: layout switching must not use Alt+Shift or Ctrl+Shift: those combinations are part of the
# Ctrl+Alt+Shift hotkeys, and X switches the group before the hotkey letter arrives, so the hotkey is lost.
KEYBOARDS = [
    ("us", "English (US)", ["us"], None),
    ("us-ru-caps", "English + Русская (CapsLock)", ["us,ru"], "grp:caps_toggle"),
    ("us-ru-win", "English + Русская (Win+Пробел)", ["us,ru"], "grp:win_space_toggle"),
]
OLD_KEYBOARD_IDS = {"us-ru-alt": "us-ru-caps", "us-ru-ctrl": "us-ru-caps"}

TR = {
    "ru": {
        "title": "Тонкий клиент",
        "tab_conn": "Подключение", "tab_net": "Сеть", "tab_sys": "Система",
        "profiles": "Профили", "add": "Добавить", "dup": "Копия", "delete": "Удалить",
        "name": "Название", "proto": "Протокол", "host": "Адрес сервера", "port": "Порт",
        "user": "Пользователь", "password": "Пароль", "domain": "Домен",
        "fullscreen": "На весь экран", "multimon": "Использовать все мониторы",
        "size": "Размер окна", "sound": "Звук", "clipboard": "Общий буфер обмена",
        "usb": "Проброс USB-устройств", "ignorecert": "Не проверять сертификат",
        "extra": "Доп. параметры клиента",
        "save": "Сохранить", "connect": "Подключиться", "boot": "Подключаться при загрузке",
        "default_mark": "при загрузке", "new_profile": "Новый профиль",
        "back": "Вернуться к сеансу", "disconnect": "Отключиться",
        "status_ready": "Готово. Выберите профиль и нажмите «Подключиться».",
        "status_noprofile": "Профилей нет. Добавьте профиль слева и сохраните его.",
        "status_wait_net": "Ожидание сети…",
        "status_connecting": "Подключение: {}…",
        "status_ended": "Сеанс завершён (код {}). {}",
        "status_retry": "Повтор через {} с. Любое нажатие отменяет автоповтор.",
        "status_saved": "Сохранено.",
        "status_nohost": "Укажите адрес сервера.",
        "status_notpersist": "Внимание: раздел данных не примонтирован, настройки не сохранятся!",
        "ask_creds": "Введите учётные данные",
        "ok": "OK", "cancel": "Отмена",
        "net_iface": "Интерфейс", "net_mode": "Настройка IP", "dhcp": "Автоматически (DHCP)",
        "static": "Вручную", "ip": "IP-адрес", "mask": "Маска / префикс", "gw": "Шлюз",
        "dns": "DNS (через запятую)", "ssid": "Сеть Wi-Fi", "wifi_pass": "Пароль Wi-Fi",
        "hidden": "Скрытая сеть", "scan": "Найти сети", "apply": "Применить",
        "net_status": "Состояние сети", "scanning": "Поиск сетей…", "no_dev": "Сетевых интерфейсов нет",
        "net_applied": "Сеть настроена.", "net_failed": "Ошибка: {}", "bad_ip": "Неверный IP-адрес или маска.",
        "signal": "Сигнал", "security": "Защита",
        "language": "Язык интерфейса", "autoreconnect": "Автоматически переподключаться",
        "keyboard": "Раскладка клавиатуры", "power": "Питание",
        "reboot": "Перезагрузить", "shutdown": "Выключить",
        "confirm_reboot": "Перезагрузить компьютер?", "confirm_shutdown": "Выключить компьютер?",
        "hotkeys": "Горячие клавиши",
        "hotkeys_text": (
            "Ctrl+Alt+Shift+S — окно настроек и профилей\n"
            "Ctrl+Alt+Shift+N — сетевые настройки\n"
            "Ctrl+Alt+Shift+P — питание и система\n"
            "Ctrl+Alt+Shift+R — переподключиться\n"
            "Ctrl+Alt+Shift+D — отключиться\n"
            "Ctrl+Alt+Shift+Пробел — показать/скрыть это окно\n"
            "Esc — вернуться к сеансу"),
        "version": "Версия {}",
    },
    "en": {
        "title": "Thin client",
        "tab_conn": "Connection", "tab_net": "Network", "tab_sys": "System",
        "profiles": "Profiles", "add": "Add", "dup": "Copy", "delete": "Delete",
        "name": "Name", "proto": "Protocol", "host": "Server address", "port": "Port",
        "user": "User", "password": "Password", "domain": "Domain",
        "fullscreen": "Fullscreen", "multimon": "Use all monitors",
        "size": "Window size", "sound": "Sound", "clipboard": "Shared clipboard",
        "usb": "USB device redirection", "ignorecert": "Ignore certificate errors",
        "extra": "Extra client options",
        "save": "Save", "connect": "Connect", "boot": "Connect at boot",
        "default_mark": "at boot", "new_profile": "New profile",
        "back": "Back to session", "disconnect": "Disconnect",
        "status_ready": "Ready. Pick a profile and press Connect.",
        "status_noprofile": "No profiles yet. Add one on the left and save it.",
        "status_wait_net": "Waiting for network…",
        "status_connecting": "Connecting: {}…",
        "status_ended": "Session ended (code {}). {}",
        "status_retry": "Retrying in {} s. Any click cancels auto-retry.",
        "status_saved": "Saved.",
        "status_nohost": "Enter the server address.",
        "status_notpersist": "Warning: data partition is not mounted, settings will not be saved!",
        "ask_creds": "Enter credentials",
        "ok": "OK", "cancel": "Cancel",
        "net_iface": "Interface", "net_mode": "IP configuration", "dhcp": "Automatic (DHCP)",
        "static": "Manual", "ip": "IP address", "mask": "Mask / prefix", "gw": "Gateway",
        "dns": "DNS (comma separated)", "ssid": "Wi-Fi network", "wifi_pass": "Wi-Fi password",
        "hidden": "Hidden network", "scan": "Scan", "apply": "Apply",
        "net_status": "Network status", "scanning": "Scanning…", "no_dev": "No network interfaces",
        "net_applied": "Network configured.", "net_failed": "Error: {}", "bad_ip": "Invalid IP address or mask.",
        "signal": "Signal", "security": "Security",
        "language": "Interface language", "autoreconnect": "Reconnect automatically",
        "keyboard": "Keyboard layout", "power": "Power",
        "reboot": "Reboot", "shutdown": "Shut down",
        "confirm_reboot": "Reboot the computer?", "confirm_shutdown": "Shut the computer down?",
        "hotkeys": "Hotkeys",
        "hotkeys_text": (
            "Ctrl+Alt+Shift+S — settings and profiles\n"
            "Ctrl+Alt+Shift+N — network settings\n"
            "Ctrl+Alt+Shift+P — power and system\n"
            "Ctrl+Alt+Shift+R — reconnect\n"
            "Ctrl+Alt+Shift+D — disconnect\n"
            "Ctrl+Alt+Shift+Space — show/hide this window\n"
            "Esc — back to the session"),
        "version": "Version {}",
    },
}

DEFAULT_PROFILE = {
    "name": "", "proto": "rdp", "host": "", "port": "", "user": "", "password": "",
    "domain": "", "fullscreen": True, "multimon": False, "width": 1920, "height": 1080,
    "sound": True, "clipboard": True, "usb": False, "ignorecert": True, "extra": "",
}


# ----------------------------------------------------------------- helpers
def run(args, timeout=30):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout or "") + (r.stderr or "")
    except Exception as e:  # noqa: BLE001
        return 1, str(e)


def nm_split(line):
    """Split nmcli terse output on unescaped ':' and unescape."""
    return [p.replace("\\:", ":").replace("\\\\", "\\") for p in re.split(r"(?<!\\):", line)]


def vnc_obfuscate(password):
    """VNC password file contents (DES with the fixed, bit-reversed key)."""
    from cryptography.hazmat.primitives.ciphers import Cipher, modes
    try:
        from cryptography.hazmat.decrepit.ciphers.algorithms import TripleDES
    except ImportError:
        from cryptography.hazmat.primitives.ciphers.algorithms import TripleDES
    key = bytes(int("{:08b}".format(b)[::-1], 2) for b in (23, 82, 107, 6, 35, 78, 88, 7))
    pw = password.encode("latin-1", "replace")[:8].ljust(8, b"\0")
    enc = Cipher(TripleDES(key * 3), modes.ECB()).encryptor()
    return enc.update(pw) + enc.finalize()


def apply_keyboard(key):
    for k, _label, layout, opt in KEYBOARDS:
        if k == key:
            cmd = ["setxkbmap", "-layout", layout[0], "-option", ""]
            if opt:
                cmd += ["-option", opt]
            run(cmd, 5)
            return


# ------------------------------------------------------------------- config
class Config:
    def __init__(self):
        self.data = {"lang": "ru", "default": "", "autoreconnect": True,
                     "keyboard": "us-ru-caps", "profiles": []}
        self.load()

    def load(self):
        try:
            with open(CONF, "r", encoding="utf-8") as f:
                self.data.update(json.load(f))
        except Exception:  # noqa: BLE001
            pass
        kb = self.data.get("keyboard")
        if kb in OLD_KEYBOARD_IDS:  # Alt+Shift / Ctrl+Shift switching broke the hotkeys
            self.data["keyboard"] = OLD_KEYBOARD_IDS[kb]

    def save(self):
        try:
            os.makedirs(DATA_DIR, exist_ok=True)
            tmp = CONF + ".tmp"
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(self.data, f, ensure_ascii=False, indent=2)
                f.flush()
                os.fsync(f.fileno())
            os.chmod(tmp, 0o600)
            os.replace(tmp, CONF)
            return True
        except Exception:  # noqa: BLE001
            return False

    def profile(self, pid):
        for p in self.data["profiles"]:
            if p.get("id") == pid:
                return p
        return None


# --------------------------------------------------------------------- app
class Kiosk:
    def __init__(self):
        self.cfg = Config()
        self.proc = None
        self.started = 0.0
        self.user_stop = False
        self.interacted = False
        self.retry_id = 0
        self.retry_left = 0
        self.net_wait_id = 0
        self.current_pid = ""
        self.sel_id = ""
        self.loading_form = False
        self.net_devs = []
        self.scan_busy = False

        css = Gtk.CssProvider()
        Gtk.Settings.get_default().set_property("gtk-application-prefer-dark-theme", True)
        css.load_from_data(b"""
            * { font-size: 12pt; }
            .status { padding: 4px 6px; }
            button { padding: 4px 12px; }
            entry { padding: 3px 6px; }
            notebook > header > tabs > tab { padding: 6px 18px; }
        """)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.win = Gtk.Window()
        self.win.set_decorated(False)
        self.win.connect("delete-event", lambda *a: True)
        self.win.connect("key-press-event", self.on_key)
        self.win.connect("button-press-event", lambda *a: self.touch())
        self.build_ui()
        self.start_ctl()
        apply_keyboard(self.cfg.data.get("keyboard", "us"))
        GLib.timeout_add_seconds(3, self.refresh_net_status)
        GLib.idle_add(self.startup)

    # ------------------------------------------------------------- i18n
    def _(self, key, *a):
        s = TR.get(self.cfg.data.get("lang", "ru"), TR["en"]).get(key, key)
        return s.format(*a) if a else s

    # --------------------------------------------------------------- UI
    def build_ui(self):
        old = self.win.get_child()
        if old:
            self.win.remove(old)
        self.win.set_title(self._("title"))
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        root.set_border_width(10)
        self.nb = Gtk.Notebook()
        self.nb.append_page(self.build_conn_tab(), Gtk.Label(label=self._("tab_conn")))
        self.nb.append_page(self.build_net_tab(), Gtk.Label(label=self._("tab_net")))
        self.nb.append_page(self.build_sys_tab(), Gtk.Label(label=self._("tab_sys")))
        self.nb.connect("switch-page", lambda *a: self.touch())
        root.pack_start(self.nb, True, True, 0)

        bar = Gtk.Box(spacing=8)
        self.status = Gtk.Label(xalign=0)
        self.status.set_line_wrap(True)
        self.status.get_style_context().add_class("status")
        bar.pack_start(self.status, True, True, 0)
        self.btn_back = Gtk.Button(label=self._("back"))
        self.btn_back.connect("clicked", lambda *a: self.hide_window())
        self.btn_disc = Gtk.Button(label=self._("disconnect"))
        self.btn_disc.connect("clicked", lambda *a: self.disconnect())
        bar.pack_end(self.btn_disc, False, False, 0)
        bar.pack_end(self.btn_back, False, False, 0)
        root.pack_start(bar, False, False, 0)
        self.win.add(root)
        self.reload_profiles()
        self.update_buttons()
        root.show_all()
        self.update_buttons()

    def build_conn_tab(self):
        box = Gtk.Box(spacing=14)
        box.set_border_width(10)
        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        left.pack_start(Gtk.Label(label=self._("profiles"), xalign=0), False, False, 0)
        self.store = Gtk.ListStore(str, str)
        self.tree = Gtk.TreeView(model=self.store)
        self.tree.set_headers_visible(False)
        self.tree.append_column(Gtk.TreeViewColumn("p", Gtk.CellRendererText(), text=1))
        self.tree.get_selection().connect("changed", self.on_profile_selected)
        sw = Gtk.ScrolledWindow()
        sw.set_size_request(300, -1)
        sw.add(self.tree)
        left.pack_start(sw, True, True, 0)
        row = Gtk.Box(spacing=6)
        for key, cb in (("add", self.add_profile), ("dup", self.dup_profile), ("delete", self.del_profile)):
            b = Gtk.Button(label=self._(key))
            b.connect("clicked", cb)
            row.pack_start(b, True, True, 0)
        left.pack_start(row, False, False, 0)
        box.pack_start(left, False, False, 0)

        g = Gtk.Grid(column_spacing=10, row_spacing=7)
        self.f = {}

        def add_row(r, key, widget):
            lab = Gtk.Label(label=self._(key), xalign=1)
            g.attach(lab, 0, r, 1, 1)
            g.attach(widget, 1, r, 3, 1)
            widget.set_hexpand(True)
            self.f[key] = widget
            self.f[key + "_label"] = lab

        r = 0
        add_row(r, "name", Gtk.Entry()); r += 1
        proto = Gtk.ComboBoxText()
        proto.append("rdp", "RDP (Windows)")
        proto.append("vnc", "VNC")
        proto.connect("changed", lambda *a: self.on_proto_changed())
        add_row(r, "proto", proto); r += 1
        add_row(r, "host", Gtk.Entry()); r += 1
        add_row(r, "port", Gtk.Entry()); r += 1
        add_row(r, "user", Gtk.Entry()); r += 1
        pw = Gtk.Entry()
        pw.set_visibility(False)
        add_row(r, "password", pw); r += 1
        add_row(r, "domain", Gtk.Entry()); r += 1
        cbg = Gtk.Grid(column_homogeneous=True, column_spacing=12, row_spacing=4)
        for i, key in enumerate(("fullscreen", "multimon", "sound", "clipboard", "usb", "ignorecert")):
            cb = Gtk.CheckButton(label=self._(key))
            cbg.attach(cb, i % 2, i // 2, 1, 1)
            self.f[key] = cb
        g.attach(cbg, 1, r, 3, 1)
        r += 1
        self.f["fullscreen"].connect("toggled", lambda *a: self.on_proto_changed())
        sz = Gtk.Box(spacing=6)
        self.f["width"] = Gtk.SpinButton.new_with_range(640, 7680, 10)
        self.f["height"] = Gtk.SpinButton.new_with_range(480, 4320, 10)
        sz.pack_start(self.f["width"], False, False, 0)
        sz.pack_start(Gtk.Label(label="×"), False, False, 0)
        sz.pack_start(self.f["height"], False, False, 0)
        lab = Gtk.Label(label=self._("size"), xalign=1)
        g.attach(lab, 0, r, 1, 1)
        g.attach(sz, 1, r, 3, 1)
        self.f["size_label"] = lab
        self.f["size_box"] = sz
        r += 1
        add_row(r, "extra", Gtk.Entry()); r += 1

        btns = Gtk.Box(spacing=8)
        self.f["boot"] = Gtk.CheckButton(label=self._("boot"))
        btns.pack_start(self.f["boot"], True, True, 0)
        save = Gtk.Button(label=self._("save"))
        save.connect("clicked", lambda *a: self.save_form(True))
        conn = Gtk.Button(label=self._("connect"))
        conn.get_style_context().add_class("suggested-action")
        conn.connect("clicked", lambda *a: self.connect_selected())
        btns.pack_end(conn, False, False, 0)
        btns.pack_end(save, False, False, 0)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.add(g)
        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        right.set_hexpand(True)
        right.pack_start(scroll, True, True, 0)
        right.pack_start(btns, False, False, 0)
        box.pack_start(right, True, True, 0)
        return box

    def build_net_tab(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.set_border_width(10)
        self.net_info = Gtk.Label(xalign=0)
        self.net_info.set_selectable(False)
        box.pack_start(Gtk.Label(label=self._("net_status"), xalign=0), False, False, 0)
        box.pack_start(self.net_info, False, False, 0)

        g = Gtk.Grid(column_spacing=10, row_spacing=7)
        self.n = {}
        r = 0
        self.n["dev"] = Gtk.ComboBoxText()
        self.n["dev"].connect("changed", lambda *a: self.on_net_dev_changed())
        g.attach(Gtk.Label(label=self._("net_iface"), xalign=1), 0, r, 1, 1)
        g.attach(self.n["dev"], 1, r, 2, 1)
        r += 1
        self.n["mode"] = Gtk.ComboBoxText()
        self.n["mode"].append("auto", self._("dhcp"))
        self.n["mode"].append("manual", self._("static"))
        self.n["mode"].set_active_id("auto")
        self.n["mode"].connect("changed", lambda *a: self.on_net_mode_changed())
        g.attach(Gtk.Label(label=self._("net_mode"), xalign=1), 0, r, 1, 1)
        g.attach(self.n["mode"], 1, r, 2, 1)
        r += 1
        for key in ("ip", "mask", "gw", "dns"):
            e = Gtk.Entry()
            e.set_hexpand(True)
            self.n[key] = e
            g.attach(Gtk.Label(label=self._(key), xalign=1), 0, r, 1, 1)
            g.attach(e, 1, r, 2, 1)
            r += 1
        self.wifi_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.wstore = Gtk.ListStore(str, str, str)
        self.wtree = Gtk.TreeView(model=self.wstore)
        for i, title in enumerate((self._("ssid"), self._("signal"), self._("security"))):
            self.wtree.append_column(Gtk.TreeViewColumn(title, Gtk.CellRendererText(), text=i))
        self.wtree.get_selection().connect("changed", self.on_ssid_selected)
        wsw = Gtk.ScrolledWindow()
        wsw.set_min_content_height(140)
        wsw.add(self.wtree)
        self.wifi_box.pack_start(wsw, True, True, 0)
        wg = Gtk.Grid(column_spacing=10, row_spacing=7)
        self.n["ssid"] = Gtk.Entry()
        self.n["ssid"].set_hexpand(True)
        self.n["wpass"] = Gtk.Entry()
        self.n["wpass"].set_visibility(False)
        self.n["wpass"].set_hexpand(True)
        self.n["hidden"] = Gtk.CheckButton(label=self._("hidden"))
        scan = Gtk.Button(label=self._("scan"))
        scan.connect("clicked", lambda *a: self.scan_wifi())
        wg.attach(Gtk.Label(label=self._("ssid"), xalign=1), 0, 0, 1, 1)
        wg.attach(self.n["ssid"], 1, 0, 1, 1)
        wg.attach(scan, 2, 0, 1, 1)
        wg.attach(Gtk.Label(label=self._("wifi_pass"), xalign=1), 0, 1, 1, 1)
        wg.attach(self.n["wpass"], 1, 1, 1, 1)
        wg.attach(self.n["hidden"], 1, 2, 2, 1)
        self.wifi_box.pack_start(wg, False, False, 0)
        g.attach(self.wifi_box, 0, r, 3, 1)
        r += 1
        apply_btn = Gtk.Button(label=self._("apply"))
        apply_btn.get_style_context().add_class("suggested-action")
        apply_btn.connect("clicked", lambda *a: self.apply_net())
        apply_btn.set_halign(Gtk.Align.END)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.add(g)
        box.pack_start(scroll, True, True, 0)
        box.pack_start(apply_btn, False, False, 0)
        GLib.idle_add(self.load_net_devs)
        return box

    def build_sys_tab(self):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_border_width(14)
        g = Gtk.Grid(column_spacing=10, row_spacing=8)
        lang = Gtk.ComboBoxText()
        lang.append("ru", "Русский")
        lang.append("en", "English")
        lang.set_active_id(self.cfg.data.get("lang", "ru"))
        lang.connect("changed", self.on_lang_changed)
        g.attach(Gtk.Label(label=self._("language"), xalign=1), 0, 0, 1, 1)
        g.attach(lang, 1, 0, 1, 1)
        kb = Gtk.ComboBoxText()
        for k, label, _l, _o in KEYBOARDS:
            kb.append(k, label)
        kb.set_active_id(self.cfg.data.get("keyboard", "us"))
        kb.connect("changed", self.on_kb_changed)
        g.attach(Gtk.Label(label=self._("keyboard"), xalign=1), 0, 1, 1, 1)
        g.attach(kb, 1, 1, 1, 1)
        ar = Gtk.CheckButton(label=self._("autoreconnect"))
        ar.set_active(bool(self.cfg.data.get("autoreconnect", True)))
        ar.connect("toggled", self.on_autoreconnect_toggled)
        g.attach(ar, 1, 2, 1, 1)
        box.pack_start(g, False, False, 0)
        box.pack_start(Gtk.Label(label=self._("hotkeys"), xalign=0), False, False, 0)
        hk = Gtk.Label(label=self._("hotkeys_text"), xalign=0)
        hk.set_selectable(False)
        box.pack_start(hk, False, False, 0)
        pw = Gtk.Box(spacing=8)
        b1 = Gtk.Button(label=self._("reboot"))
        b1.connect("clicked", lambda *a: self.power("reboot"))
        b2 = Gtk.Button(label=self._("shutdown"))
        b2.connect("clicked", lambda *a: self.power("poweroff"))
        pw.pack_start(b1, False, False, 0)
        pw.pack_start(b2, False, False, 0)
        box.pack_start(Gtk.Label(label=self._("power"), xalign=0), False, False, 0)
        box.pack_start(pw, False, False, 0)
        box.pack_end(Gtk.Label(label=self._("version", VERSION), xalign=0), False, False, 0)
        return box

    # ------------------------------------------------------ window control
    def show_window(self, tab=None):
        if tab is not None:
            self.nb.set_current_page(tab)
        self.win.fullscreen()
        self.win.set_keep_above(True)
        self.win.show_all()
        self.update_buttons()
        self.win.present()

    def hide_window(self):
        if self.running():
            self.win.hide()

    def running(self):
        return self.proc is not None and self.proc.poll() is None

    def update_buttons(self):
        run_now = self.running()
        self.btn_back.set_visible(run_now)
        self.btn_disc.set_visible(run_now)
        self.btn_back.set_no_show_all(not run_now)
        self.btn_disc.set_no_show_all(not run_now)

    def set_status(self, text):
        self.status.set_text(text)

    def touch(self):
        """User interacted: stop auto-retry/auto-start timers."""
        self.interacted = True
        if self.retry_id:
            GLib.source_remove(self.retry_id)
            self.retry_id = 0
        if self.net_wait_id:
            GLib.source_remove(self.net_wait_id)
            self.net_wait_id = 0
        return False

    def on_key(self, w, ev):
        self.touch()
        if ev.keyval == Gdk.KEY_Escape and self.running():
            self.hide_window()
            return True
        return False

    # -------------------------------------------------------------- control
    def start_ctl(self):
        try:
            os.unlink(SOCK)
        except OSError:
            pass
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        self.sock.bind(SOCK)
        self.sock.setblocking(False)
        GLib.io_add_watch(self.sock.fileno(), GLib.IO_IN, self.on_ctl)

    def on_ctl(self, fd, cond):
        try:
            cmd = self.sock.recv(256).decode().strip()
        except OSError:
            return True
        self.touch()
        if cmd == "settings":
            self.show_window(0)
        elif cmd == "network":
            self.show_window(1)
        elif cmd == "power":
            self.show_window(2)
        elif cmd == "disconnect":
            self.disconnect()
        elif cmd == "reconnect":
            self.reconnect()
        elif cmd == "toggle":
            if self.win.get_visible() and self.running():
                self.hide_window()
            else:
                self.show_window()
        return True

    # ----------------------------------------------------------- profiles
    def reload_profiles(self, select=None):
        self.loading_form = True
        self.store.clear()
        sel_iter = None
        default = self.cfg.data.get("default", "")
        for p in self.cfg.data["profiles"]:
            label = p.get("name") or p.get("host") or "?"
            if p["id"] == default:
                label += "  ★ " + self._("default_mark")
            it = self.store.append([p["id"], label])
            if p["id"] == (select or self.sel_id):
                sel_iter = it
        self.loading_form = False
        if sel_iter is None and len(self.store) > 0:
            sel_iter = self.store.get_iter_first()
        if sel_iter is not None:
            self.tree.get_selection().select_iter(sel_iter)
        else:
            self.sel_id = ""
            self.fill_form(dict(DEFAULT_PROFILE), False)

    def on_profile_selected(self, sel):
        if self.loading_form:
            return
        model, it = sel.get_selected()
        if it is None:
            return
        pid = model[it][0]
        self.sel_id = pid
        p = self.cfg.profile(pid)
        if p:
            self.fill_form(p, self.cfg.data.get("default") == pid)

    def fill_form(self, p, is_default):
        self.loading_form = True
        f = self.f
        for key in ("name", "host", "port", "user", "password", "domain", "extra"):
            f[key].set_text(str(p.get(key, "")))
        f["proto"].set_active_id(p.get("proto", "rdp"))
        for key in ("fullscreen", "multimon", "sound", "clipboard", "usb", "ignorecert"):
            f[key].set_active(bool(p.get(key, DEFAULT_PROFILE[key])))
        f["width"].set_value(int(p.get("width", 1920)))
        f["height"].set_value(int(p.get("height", 1080)))
        f["boot"].set_active(is_default)
        self.loading_form = False
        self.on_proto_changed()

    def read_form(self):
        f = self.f
        p = {"id": self.sel_id or uuid.uuid4().hex[:8]}
        for key in ("name", "host", "port", "user", "password", "domain", "extra"):
            p[key] = f[key].get_text().strip() if key not in ("password",) else f[key].get_text()
        p["proto"] = f["proto"].get_active_id() or "rdp"
        for key in ("fullscreen", "multimon", "sound", "clipboard", "usb", "ignorecert"):
            p[key] = f[key].get_active()
        p["width"] = int(f["width"].get_value())
        p["height"] = int(f["height"].get_value())
        if not p["name"]:
            p["name"] = p["host"]
        return p

    def on_proto_changed(self):
        if self.loading_form:
            return
        rdp = self.f["proto"].get_active_id() != "vnc"
        for key in ("user", "domain", "sound", "usb", "ignorecert", "extra", "clipboard"):
            self.f[key].set_sensitive(rdp or key in ("clipboard",))
            lab = self.f.get(key + "_label")
            if lab:
                lab.set_sensitive(rdp)
        fs = self.f["fullscreen"].get_active()
        self.f["size_box"].set_sensitive(not fs)
        self.f["size_label"].set_sensitive(not fs)
        self.f["multimon"].set_sensitive(fs)

    def save_form(self, notify=False):
        p = self.read_form()
        profiles = self.cfg.data["profiles"]
        for i, old in enumerate(profiles):
            if old["id"] == p["id"]:
                profiles[i] = p
                break
        else:
            profiles.append(p)
        self.sel_id = p["id"]
        if self.f["boot"].get_active():
            self.cfg.data["default"] = p["id"]
        elif self.cfg.data.get("default") == p["id"]:
            self.cfg.data["default"] = ""
        ok = self.cfg.save()
        self.reload_profiles(p["id"])
        if notify:
            self.set_status(self._("status_saved") if ok else "Save failed")
        return p

    def add_profile(self, *a):
        self.sel_id = ""
        self.tree.get_selection().unselect_all()
        p = dict(DEFAULT_PROFILE)
        p["name"] = self._("new_profile")
        self.fill_form(p, not self.cfg.data["profiles"])

    def dup_profile(self, *a):
        p = self.read_form()
        self.sel_id = ""
        p["name"] = p["name"] + " (2)"
        self.tree.get_selection().unselect_all()
        self.fill_form(p, False)

    def del_profile(self, *a):
        if not self.sel_id:
            return
        self.cfg.data["profiles"] = [p for p in self.cfg.data["profiles"] if p["id"] != self.sel_id]
        if self.cfg.data.get("default") == self.sel_id:
            self.cfg.data["default"] = ""
        self.sel_id = ""
        self.cfg.save()
        self.reload_profiles()

    def connect_selected(self):
        p = self.save_form()
        self.interacted = False
        self.connect(p)

    # ------------------------------------------------------------ sessions
    def startup(self):
        if not PERSISTENT:
            self.set_status(self._("status_notpersist"))
        prof = self.cfg.profile(self.cfg.data.get("default", ""))
        self.show_window(0)
        if prof and prof.get("host"):
            self.current_pid = prof["id"]
            self.set_status(self._("status_wait_net"))
            self.net_deadline = time.time() + 40
            self.net_wait_id = GLib.timeout_add(1000, self.wait_net)
        else:
            self.set_status(self._("status_noprofile") if not self.cfg.data["profiles"]
                            else self._("status_ready"))
        return False

    def wait_net(self):
        rc, out = run(["nmcli", "-t", "-g", "STATE", "general"], 4)
        state = out.strip()
        if state.startswith("connected") or time.time() > self.net_deadline:
            self.net_wait_id = 0
            prof = self.cfg.profile(self.current_pid)
            if prof:
                self.connect(prof)
            return False
        return True

    def reconnect(self):
        prof = self.cfg.profile(self.current_pid) or self.cfg.profile(self.cfg.data.get("default", ""))
        if not prof:
            self.show_window(0)
            return
        self.interacted = False
        self.connect(prof)

    def ask_credentials(self, prof):
        d = Gtk.Dialog(title=self._("ask_creds"), transient_for=self.win, modal=True)
        d.add_button(self._("cancel"), Gtk.ResponseType.CANCEL)
        d.add_button(self._("ok"), Gtk.ResponseType.OK)
        d.set_default_response(Gtk.ResponseType.OK)
        g = Gtk.Grid(column_spacing=10, row_spacing=8)
        g.set_border_width(14)
        eu, ep = Gtk.Entry(), Gtk.Entry()
        eu.set_text(prof.get("user", ""))
        ep.set_visibility(False)
        ep.set_activates_default(True)
        eu.set_activates_default(True)
        g.attach(Gtk.Label(label=self._("user"), xalign=1), 0, 0, 1, 1)
        g.attach(eu, 1, 0, 1, 1)
        g.attach(Gtk.Label(label=self._("password"), xalign=1), 0, 1, 1, 1)
        g.attach(ep, 1, 1, 1, 1)
        d.get_content_area().add(g)
        d.show_all()
        (ep if eu.get_text() else eu).grab_focus()
        resp = d.run()
        res = (eu.get_text(), ep.get_text()) if resp == Gtk.ResponseType.OK else None
        d.destroy()
        return res

    def build_cmd(self, p):
        host = p["host"].strip()
        port = p.get("port", "").strip()
        if p["proto"] == "vnc":
            cmd = ["xtigervncviewer", "-Shared"]
            if p.get("fullscreen", True):
                cmd.append("-FullScreen")
                if p.get("multimon"):
                    cmd.append("-FullScreenMode=All")
            # FullscreenSystemKeys=0: do not grab the keyboard, so the Ctrl+Alt+Shift hotkeys keep working
            cmd += ["-MenuKey", "none", "-ReconnectOnError=0", "-FullscreenSystemKeys=0"]
            if p.get("password"):
                with open(VNC_PASS, "wb") as f:
                    f.write(vnc_obfuscate(p["password"]))
                os.chmod(VNC_PASS, 0o600)
                cmd += ["-passwd", VNC_PASS]
            cmd.append("{}::{}".format(host, port) if port else host)
            return cmd
        target = "{}:{}".format(host, port) if port else host
        cmd = ["xfreerdp3", "/v:" + target]
        if p.get("user"):
            cmd.append("/u:" + p["user"])
        if p.get("password"):
            cmd.append("/p:" + p["password"])
        if p.get("domain"):
            cmd.append("/d:" + p["domain"])
        if p.get("fullscreen", True):
            cmd.append("/f")
            if p.get("multimon"):
                cmd.append("/multimon")
        else:
            cmd.append("/size:{}x{}".format(p.get("width", 1280), p.get("height", 720)))
        cmd.append("+clipboard" if p.get("clipboard", True) else "-clipboard")
        if p.get("sound", True):
            cmd += ["/sound:sys:pulse", "/microphone:sys:pulse"]
        if p.get("usb"):
            cmd.append("/usb:auto")
        if p.get("ignorecert", True):
            cmd.append("/cert:ignore")
        cmd += ["-grab-keyboard", "+auto-reconnect", "/auto-reconnect-max-retries:3",
                "/dynamic-resolution", "/network:auto"]
        if p.get("extra"):
            import shlex
            cmd += shlex.split(p["extra"])
        return cmd

    def connect(self, prof):
        self.touch_timers_only()
        prof = dict(prof)
        if not prof.get("host"):
            self.show_window(0)
            self.set_status(self._("status_nohost"))
            return
        self.current_pid = prof.get("id", "")
        if prof["proto"] == "rdp" and (not prof.get("user") or not prof.get("password")):
            self.show_window(0)
            creds = self.ask_credentials(prof)
            if creds is None:
                return
            prof["user"], prof["password"] = creds
        if self.running():
            self.user_stop = True
            self.proc.terminate()
            try:
                self.proc.wait(3)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        cmd = self.build_cmd(prof)
        self.user_stop = False
        try:
            log = open(CLIENT_LOG, "w")
            self.proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT,
                                         stdin=subprocess.DEVNULL, start_new_session=True)
        except Exception as e:  # noqa: BLE001
            self.proc = None
            self.show_window()
            self.set_status(self._("status_ended", "-", str(e)))
            return
        self.started = time.time()
        self.set_status(self._("status_connecting", prof.get("name") or prof["host"]))
        GLib.child_watch_add(GLib.PRIORITY_DEFAULT, self.proc.pid, self.on_exit)
        GLib.timeout_add_seconds(3, self.hide_if_alive, self.proc.pid)
        if prof["proto"] == "vnc":
            # TigerVNC keeps a modal error dialog open instead of exiting: watch its log.
            GLib.timeout_add_seconds(1, self.watch_vnc_log, self.proc.pid)
        self.update_buttons()

    def touch_timers_only(self):
        if self.retry_id:
            GLib.source_remove(self.retry_id)
            self.retry_id = 0
        if self.net_wait_id:
            GLib.source_remove(self.net_wait_id)
            self.net_wait_id = 0

    def watch_vnc_log(self, pid):
        if self.proc is None or self.proc.pid != pid or self.proc.poll() is not None:
            return False
        try:
            with open(CLIENT_LOG, "r", errors="replace") as f:
                text = f.read()
        except OSError:
            return True
        if re.search(r"(unable to connect|Failed to connect|Authentication (failed|failure)|"
                     r"No matching security|Connection (refused|reset|closed|timed out)|"
                     r"Disconnected)", text):
            try:
                self.proc.terminate()
            except OSError:
                pass
            return False
        return True

    def hide_if_alive(self, pid):
        if self.proc is not None and self.proc.pid == pid and self.proc.poll() is None:
            self.win.hide()
        return False

    def on_exit(self, pid, status):
        code = os.waitstatus_to_exitcode(status) if hasattr(os, "waitstatus_to_exitcode") else status
        if self.proc is None or self.proc.pid != pid:
            return
        self.proc.poll()
        self.proc = None
        try:
            os.unlink(VNC_PASS)
        except OSError:
            pass
        if self.user_stop:
            self.user_stop = False
            self.show_window(0)
            self.set_status(self._("status_ready"))
            return
        tail = ""
        try:
            with open(CLIENT_LOG, "r", errors="replace") as f:
                lines = [ln.strip() for ln in f.read().splitlines() if ln.strip()]
            tail = " | ".join(lines[-2:])[-220:]
        except OSError:
            pass
        self.show_window(0)
        self.set_status(self._("status_ended", code, tail))
        if self.cfg.data.get("autoreconnect", True) and not self.interacted:
            self.retry_left = 10 if time.time() - self.started < 15 else 3
            self.retry_id = GLib.timeout_add_seconds(1, self.retry_tick, tail, code)

    def retry_tick(self, tail, code):
        if self.interacted:
            self.retry_id = 0
            return False
        self.retry_left -= 1
        if self.retry_left <= 0:
            self.retry_id = 0
            self.reconnect()
            return False
        self.set_status(self._("status_ended", code, tail) + "\n" + self._("status_retry", self.retry_left))
        return True

    def disconnect(self):
        if self.running():
            self.user_stop = True
            self.proc.terminate()
        else:
            self.show_window(0)

    # ------------------------------------------------------------- network
    def run_async(self, fn, done):
        def worker():
            res = fn()
            GLib.idle_add(done, res)
        threading.Thread(target=worker, daemon=True).start()

    def load_net_devs(self):
        rc, out = run(["nmcli", "-t", "-f", "DEVICE,TYPE", "device"], 6)
        devs = []
        for line in out.splitlines():
            parts = nm_split(line)
            if len(parts) >= 2 and parts[1] in ("ethernet", "wifi"):
                devs.append((parts[0], parts[1]))
        self.net_devs = devs
        cb = self.n["dev"]
        cb.remove_all()
        for d, t in devs:
            cb.append(d, "{} ({})".format(d, "Wi-Fi" if t == "wifi" else "Ethernet"))
        if devs:
            cb.set_active(0)
        else:
            cb.append("", self._("no_dev"))
            cb.set_active(0)
        self.on_net_mode_changed()
        return False

    def cur_dev(self):
        did = self.n["dev"].get_active_id()
        for d, t in self.net_devs:
            if d == did:
                return d, t
        return None, None

    def on_net_dev_changed(self):
        d, t = self.cur_dev()
        self.wifi_box.set_visible(t == "wifi")
        self.wifi_box.set_no_show_all(t != "wifi")
        self.load_saved_net()
        if t == "wifi":
            self.scan_wifi()

    def load_saved_net(self):
        """Show the saved profile of the selected link type in the form."""
        d, t = self.cur_dev()
        if not t:
            return
        rc, out = run(["nmcli", "-t", "-s", "-f",
                       "ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,"
                       "802-11-wireless.ssid,802-11-wireless.hidden,802-11-wireless-security.psk",
                       "connection", "show", NM_PROFILE[t]], 10)
        vals = {}
        if rc == 0:
            for line in out.splitlines():
                k, _, v = line.partition(":")
                v = v.replace("\\:", ":").strip()
                vals[k] = "" if v == "--" else v
        manual = vals.get("ipv4.method") == "manual"
        addr = re.split(r"[,\s|]+", vals.get("ipv4.addresses", "").strip())[0]
        ip, _, prefix = addr.partition("/")
        self.n["mode"].set_active_id("manual" if manual else "auto")
        self.n["ip"].set_text(ip if manual else "")
        self.n["mask"].set_text(prefix if manual else "")
        self.n["gw"].set_text(vals.get("ipv4.gateway", "") if manual else "")
        self.n["dns"].set_text(",".join(x for x in re.split(r"[,\s|]+", vals.get("ipv4.dns", "")) if x)
                               if manual else "")
        if t == "wifi":
            self.n["ssid"].set_text(vals.get("802-11-wireless.ssid", ""))
            self.n["wpass"].set_text(vals.get("802-11-wireless-security.psk", ""))
            self.n["hidden"].set_active(vals.get("802-11-wireless.hidden") == "yes")
        self.on_net_mode_changed()

    def on_net_mode_changed(self):
        manual = self.n["mode"].get_active_id() == "manual"
        for k in ("ip", "mask", "gw", "dns"):
            self.n[k].set_sensitive(manual)
        d, t = self.cur_dev()
        self.wifi_box.set_visible(t == "wifi")

    def scan_wifi(self):
        d, t = self.cur_dev()
        if t != "wifi" or self.scan_busy:
            return
        self.scan_busy = True
        self.set_status(self._("scanning"))

        def work():
            return run(["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list",
                        "ifname", d, "--rescan", "yes"], 25)

        def done(res):
            self.scan_busy = False
            rc, out = res
            self.wstore.clear()
            seen = set()
            for line in out.splitlines():
                parts = nm_split(line)
                if len(parts) >= 3 and parts[0] and parts[0] not in seen:
                    seen.add(parts[0])
                    self.wstore.append([parts[0], parts[1] + "%", parts[2] or "—"])
            self.set_status("")
            return False
        self.run_async(work, done)

    def on_ssid_selected(self, sel):
        model, it = sel.get_selected()
        if it is not None:
            self.n["ssid"].set_text(model[it][0])

    def refresh_net_status(self):
        def work():
            _, a = run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"], 5)
            _, b = run(["ip", "-4", "-o", "addr", "show", "scope", "global"], 5)
            return a, b

        def done(res):
            a, b = res
            ips = {}
            for line in b.splitlines():
                m = re.match(r"\d+:\s+(\S+)\s+inet\s+(\S+)", line)
                if m:
                    ips[m.group(1)] = m.group(2)
            lines = []
            for line in a.splitlines():
                p = nm_split(line)
                if len(p) >= 4 and p[1] in ("ethernet", "wifi"):
                    lines.append("{}: {} {} {}".format(p[0], p[2], p[3], ips.get(p[0], "")).strip())
            self.net_info.set_text("\n".join(lines) or "—")
            return False
        if self.win.get_visible():
            self.run_async(work, done)
        return True

    def apply_net(self):
        dev, typ = self.cur_dev()
        if not dev:
            return
        mode = self.n["mode"].get_active_id()
        name = NM_PROFILE[typ]
        args = []
        if mode == "manual":
            try:
                mask = self.n["mask"].get_text().strip()
                ip = ipaddress.ip_address(self.n["ip"].get_text().strip())
                prefix = mask.lstrip("/") if mask.lstrip("/").isdigit() else \
                    str(ipaddress.ip_network("0.0.0.0/" + mask).prefixlen)
                gw = self.n["gw"].get_text().strip()
                if gw:
                    ipaddress.ip_address(gw)
                args = ["ipv4.method", "manual", "ipv4.addresses", "{}/{}".format(ip, prefix)]
                if gw:
                    args += ["ipv4.gateway", gw]
                dns = ",".join(x.strip() for x in self.n["dns"].get_text().split(",") if x.strip())
                if dns:
                    args += ["ipv4.dns", dns]
            except ValueError:
                self.set_status(self._("bad_ip"))
                return
        else:
            args = ["ipv4.method", "auto"]
        ssid = self.n["ssid"].get_text().strip()
        wpass = self.n["wpass"].get_text()
        hidden = self.n["hidden"].get_active()

        def work():
            for old_name in (name, "kiosk-" + dev):  # the second one: profiles of older versions
                run(["nmcli", "-w", "30", "connection", "delete", old_name], 40)
            base = ["nmcli", "connection", "add", "type", typ, "ifname", "*", "con-name", name,
                    "connection.autoconnect", "yes"]
            if typ == "wifi":
                if not ssid:
                    return 1, "SSID?"
                base += ["ssid", ssid]
                if hidden:
                    base += ["802-11-wireless.hidden", "yes"]
                if wpass:
                    base += ["wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.psk", wpass]
            rc, out = run(base + args, 20)
            if rc != 0:
                return rc, out
            return run(["nmcli", "-w", "40", "connection", "up", name, "ifname", dev], 50)

        def done(res):
            rc, out = res
            self.set_status(self._("net_applied") if rc == 0 else self._("net_failed", out.strip()[:200]))
            return False
        self.set_status("…")
        self.run_async(work, done)

    # -------------------------------------------------------------- system
    def on_lang_changed(self, cb):
        lang = cb.get_active_id()
        if lang and lang != self.cfg.data.get("lang"):
            self.cfg.data["lang"] = lang
            self.cfg.save()
            page = self.nb.get_current_page()
            self.build_ui()
            self.nb.set_current_page(page)
            self.win.show_all()

    def on_kb_changed(self, cb):
        k = cb.get_active_id()
        if k:
            self.cfg.data["keyboard"] = k
            self.cfg.save()
            apply_keyboard(k)

    def on_autoreconnect_toggled(self, cb):
        self.cfg.data["autoreconnect"] = cb.get_active()
        self.cfg.save()

    def power(self, what):
        msg = self._("confirm_reboot" if what == "reboot" else "confirm_shutdown")
        d = Gtk.MessageDialog(transient_for=self.win, modal=True, message_type=Gtk.MessageType.QUESTION,
                              buttons=Gtk.ButtonsType.NONE, text=msg)
        d.add_button(self._("cancel"), Gtk.ResponseType.CANCEL)
        d.add_button(self._("ok"), Gtk.ResponseType.OK)
        resp = d.run()
        d.destroy()
        if resp == Gtk.ResponseType.OK:
            run(["systemctl", what], 10)


def main():
    Kiosk()
    Gtk.main()


if __name__ == "__main__":
    main()
__KIT_EOF__
mkdir -p "$DEST/overlay/opt/kiosk"
cat > "$DEST/overlay/opt/kiosk/rc.xml" <<'__KIT_EOF__'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <resistance><strength>10</strength><screen_edge_strength>20</screen_edge_strength></resistance>
  <focus><focusNew>yes</focusNew><followMouse>no</followMouse><focusLast>yes</focusLast><underMouse>no</underMouse><focusDelay>200</focusDelay><raiseOnFocus>yes</raiseOnFocus></focus>
  <placement><policy>Smart</policy><center>yes</center><monitor>Primary</monitor><primaryMonitor>1</primaryMonitor></placement>
  <theme><name>Clearlooks</name><titleLayout>NLIMC</titleLayout><keepBorder>no</keepBorder><animateIconify>no</animateIconify></theme>
  <desktops><number>1</number><firstdesk>1</firstdesk><popupTime>0</popupTime></desktops>
  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>
    <keybind key="C-A-S-s"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl settings</command></action></keybind>
    <keybind key="C-A-S-n"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl network</command></action></keybind>
    <keybind key="C-A-S-p"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl power</command></action></keybind>
    <keybind key="C-A-S-r"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl reconnect</command></action></keybind>
    <keybind key="C-A-S-d"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl disconnect</command></action></keybind>
    <keybind key="C-A-S-space"><action name="Execute"><command>/opt/kiosk/kiosk.py --ctl toggle</command></action></keybind>
  </keyboard>
  <mouse><dragThreshold>8</dragThreshold><doubleClickTime>400</doubleClickTime></mouse>
  <applications>
    <application class="*"><decor>no</decor></application>
  </applications>
</openbox_config>
__KIT_EOF__
mkdir -p "$DEST/overlay/opt/kiosk"
cat > "$DEST/overlay/opt/kiosk/session.sh" <<'__KIT_EOF__'
#!/bin/sh
# X session of the kiosk user: no desktop, only openbox (for hotkeys) + the launcher.
export GDK_BACKEND=x11 NO_AT_BRIDGE=1 GTK_A11Y=none LANG=C.UTF-8
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
xset s off -dpms s noblank 2>/dev/null
xsetroot -solid '#20232a' -cursor_name left_ptr 2>/dev/null
pulseaudio --start --exit-idle-time=-1 --log-target=syslog 2>/dev/null
( sleep 3; pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ 85% ) >/dev/null 2>&1 &
openbox --config-file /opt/kiosk/rc.xml >/dev/null 2>&1 &
exec /opt/kiosk/kiosk.py
__KIT_EOF__
mkdir -p "$DEST/overlay/usr/local/sbin"
cat > "$DEST/overlay/usr/local/sbin/kiosk-growdata" <<'__KIT_EOF__'
#!/bin/sh
# Prepare persistent storage: grow the last (data) partition to fill the device,
# check/grow its filesystem, mount it on /data and bind NetworkManager profiles from it.
DEV=$(blkid -L KIOSKDATA 2>/dev/null)
if [ -b "$DEV" ]; then
    SYS=/sys/class/block/$(basename "$DEV")
    PART=$(cat "$SYS/partition" 2>/dev/null)
    DISK=/dev/$(basename "$(readlink -f "$SYS/..")")
    DISK_SECT=$(blockdev --getsz "$DISK" 2>/dev/null)
    START=$(cat "$SYS/start" 2>/dev/null); SIZE=$(cat "$SYS/size" 2>/dev/null)
    GREW=0
    if [ -n "$PART" ] && [ -n "$DISK_SECT" ] && [ $((DISK_SECT - START - SIZE)) -gt 8192 ]; then
        echo ", +" | sfdisk --no-reread -N "$PART" "$DISK" >/dev/null 2>&1
        partx -u "$DISK" >/dev/null 2>&1 || partprobe "$DISK" >/dev/null 2>&1
        udevadm settle --timeout=15 >/dev/null 2>&1
        GREW=1
    fi
    if [ $GREW = 1 ]; then
        e2fsck -fp "$DEV" >/dev/null 2>&1
        resize2fs "$DEV" >/dev/null 2>&1
    else
        e2fsck -p "$DEV" >/dev/null 2>&1
    fi
    mkdir -p /data
    mountpoint -q /data || mount -t ext4 -o noatime "$DEV" /data
    if mountpoint -q /data; then
        mkdir -p /data/nm /data/kiosk
        chown 1000:1000 /data/kiosk; chmod 700 /data/kiosk
        mkdir -p /etc/NetworkManager/system-connections
        mountpoint -q /etc/NetworkManager/system-connections || \
            mount --bind /data/nm /etc/NetworkManager/system-connections
        # Ubuntu's NetworkManager saves new connections as netplan YAML in /etc/netplan:
        # keep it on the data partition and regenerate the NM profiles before NetworkManager starts.
        mkdir -p /data/netplan /etc/netplan
        chmod 700 /data/netplan
        mountpoint -q /etc/netplan || mount --bind /data/netplan /etc/netplan
        netplan generate >/dev/null 2>&1
    fi
fi
exit 0
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/mk-test-image.sh" <<'__KIT_EOF__'
#!/bin/sh
# Copy of disk.img with a VNC profile preconfigured (10.0.2.2 = the host as seen from QEMU user-net)
# and a serial debug shell enabled on the kernel command line.
set -e
cd /work/build
cp disk.img test.img
rm -rf td; mkdir -p td/kiosk td/nm
cat > td/kiosk/config.json <<J
{"lang":"ru","default":"t1","autoreconnect":true,"keyboard":"us-ru-alt",
 "profiles":[{"id":"t1","name":"Test VNC","proto":"vnc","host":"10.0.2.2","port":"5900","user":"","password":"test123","domain":"","fullscreen":true,"multimon":false,"width":1280,"height":720,"sound":true,"clipboard":true,"usb":false,"ignorecert":true,"extra":""}]}
J
chown -R 1000:1000 td/kiosk; chmod 700 td/kiosk; chown 0:0 td/nm
rm -f tdata.img; mke2fs -q -t ext4 -L KIOSKDATA -E root_owner=0:0 -d td tdata.img 128M
START=$(sfdisk -d disk.img | awk '/disk.img3/ {gsub(",","",$4); print $4}')
dd if=tdata.img of=test.img bs=512 seek=$START conv=notrunc status=none
sed -e 's/ quiet loglevel=3/ loglevel=4 console=tty0 console=ttyS0,115200 systemd.debug-shell=\/dev\/ttyS0 systemd.mask=serial-getty@ttyS0.service/' /work/kit/boot/grub.cfg > /work/grub-debug.cfg
mcopy -o -i test.img@@1048576 /work/grub-debug.cfg ::/boot/grub/grub.cfg
for d in EFI/BOOT EFI/ubuntu; do mcopy -o -i test.img@@1048576 /work/grub-debug.cfg ::/$d/grub.cfg; done
echo TEST_IMAGE_OK start=$START
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/qmon.py" <<'__KIT_EOF__'
#!/usr/bin/env python3
import socket, sys, time
cmd = " ".join(sys.argv[1:])
s = socket.socket(socket.AF_UNIX); s.connect("/work/qmon"); s.settimeout(3)
try: s.recv(4096)
except Exception: pass
s.sendall((cmd + "\n").encode()); time.sleep(0.8)
try: print(s.recv(65536).decode(errors="replace")[-400:])
except Exception: pass
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/rdpsrv.sh" <<'__KIT_EOF__'
#!/bin/sh
export DISPLAY=:98
exec freerdp-shadow-cli3 /port:3389 -auth -sec-nla > /work/rdpsrv.log 2>&1
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/run-qemu.sh" <<'__KIT_EOF__'
#!/bin/sh
# usage: [SNAP=on|off] run-qemu.sh bios|uefi [image] [vpc]
MODE=$1; IMG=${2:-/work/build/disk.img}; FMT=${3:-raw}
FW=""
if [ "$MODE" = uefi ]; then
  cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd /work/ovmf_vars.fd
  FW="-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd -drive if=pflash,format=raw,file=/work/ovmf_vars.fd -machine q35,smm=on -global driver=cfi.pflash01,property=secure,value=on"
fi
rm -f /work/qmon /work/ser.sock
exec qemu-system-x86_64 -m 2048 -smp 1 $FW \
  -drive if=none,id=usb0,file=$IMG,format=$FMT,snapshot=${SNAP:-on} \
  -device qemu-xhci -device usb-storage,drive=usb0,bootindex=0 \
  -vga std -display none \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -device intel-hda -device hda-duplex \
  -monitor unix:/work/qmon,server,nowait -serial unix:/work/ser.sock,server,nowait
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/ser.py" <<'__KIT_EOF__'
#!/usr/bin/env python3
"""usage: ser.py 'command' [timeout]  -- run a command in the guest debug shell on the serial socket"""
import socket, sys, time, uuid
cmd = sys.argv[1]; tmo = float(sys.argv[2]) if len(sys.argv) > 2 else 20
s = socket.socket(socket.AF_UNIX); s.connect("/work/ser.sock"); s.settimeout(1)
mark = "END" + uuid.uuid4().hex[:8]
s.sendall(("\n" + cmd + "; echo " + mark + "\n").encode())
buf = b""; t0 = time.time()
while time.time() - t0 < tmo:
    try:
        d = s.recv(65536)
        if not d: break
        buf += d
        if buf.count(mark.encode()) >= 2: break
    except socket.timeout:
        pass
out = buf.decode(errors="replace")
i = out.rfind(mark); j = out.find(mark)
print(out[j+len(mark):i] if i != j else out[-3000:])
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/uitest.py" <<'__KIT_EOF__'
import importlib.util, json, os, sys
os.environ["HOME"] = "/tmp/kh"; os.makedirs("/tmp/kh", exist_ok=True)
spec = importlib.util.spec_from_file_location("kiosk", "/work/kit/overlay/opt/kiosk/kiosk.py")
k = importlib.util.module_from_spec(spec); spec.loader.exec_module(k)
conf = k.CONF
if os.path.exists(conf): os.remove(conf)
app = k.Kiosk()
# new profile: RDP
app.add_profile()
f = app.f
f["name"].set_text("Office RDP"); f["host"].set_text("10.1.2.3"); f["port"].set_text("3390")
f["user"].set_text("ivan"); f["password"].set_text("p@ss"); f["domain"].set_text("CORP")
f["multimon"].set_active(True); f["usb"].set_active(True); f["boot"].set_active(True)
app.save_form(True)
# second profile: VNC
app.add_profile()
f["name"].set_text("Lab VNC"); f["proto"].set_active_id("vnc"); f["host"].set_text("192.168.0.5"); f["password"].set_text("secret")
app.save_form(True)
data = json.load(open(conf))
print("profiles:", [(p["name"], p["proto"], p["host"], p["port"]) for p in data["profiles"]], "default ->", [p["name"] for p in data["profiles"] if p["id"] == data["default"]])
# command lines the app would run
for p in data["profiles"]:
    c = app.build_cmd(dict(p)); print(p["proto"], "->", " ".join(x if not x.startswith("/p:") else "/p:***" for x in c))
# reload from disk
k2 = k.Config(); print("reloaded:", len(k2.data["profiles"]), "profiles, default ok:", k2.data["default"] == data["default"])
print("file mode:", oct(os.stat(conf).st_mode & 0o777))
# delete + language switch
app.sel_id = data["profiles"][1]["id"]; app.del_profile()
print("after delete:", len(json.load(open(conf))["profiles"]))
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/uitest.sh" <<'__KIT_EOF__'
#!/bin/sh
export DISPLAY=:99 NO_AT_BRIDGE=1 HOME=/tmp/kh
mkdir -p /tmp/kh; rm -f /tmp/kh/uitest.out
Xvfb :99 -screen 0 1366x768x24 >/dev/null 2>&1 &
XP=$!
sleep 2
/usr/bin/python3.12 /work/kit/test/uitest.py > /work/uitest.out 2>&1
kill $XP
echo done >> /work/uitest.out
__KIT_EOF__
mkdir -p "$DEST/test"
cat > "$DEST/test/vncsrv.sh" <<'__KIT_EOF__'
#!/bin/sh
export DISPLAY=:98
Xvfb :98 -screen 0 1280x720x24 >/dev/null 2>&1 &
sleep 2
xsetroot -solid '#2a5a8a' 2>/dev/null
xclock -geometry 300x300+60+60 >/dev/null 2>&1 &
xterm -geometry 70x12+420+80 -e 'sh -c "echo REMOTE VNC DESKTOP OK; date; sleep 100000"' >/dev/null 2>&1 &
x11vnc -display :98 -rfbport 5900 -passwd test123 -forever -shared -noxdamage -quiet >/work/x11vnc.log 2>&1 &
wait
__KIT_EOF__
echo "== verifying unpacked files"
cat > "$DEST/.manifest.sha256" <<'__KIT_EOF__'
ce7b080b9f4cb872dbb2f349f59a70f19f3cc72b3b5d7d719690ff8fa7c33a72  README.md
0158a9592d09a6d130fdbdb1abacc08673de0543926cc3815fb172ec9858d648  boot/early.cfg
753bedb83224707f6df1bc13d8c0f60cf5dcd8688e1195008c37294434eaa143  boot/grub.cfg
dd028468a5d7a13cf9e7776142400c8c110ded810d2b6f6d703eb6473d61fb31  build-all.sh
0e5d137f5ad33640350012be67de9219c65c22c0e9814142d64ddf43f71a68e0  build-image.sh
9a20fd2497cbd17b0b84dc3871402c05fce2db51df2dd94805c09fa2ce162399  build-rootfs.sh
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  overlay/etc/NetworkManager/conf.d/10-dns-resolved.conf
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  overlay/etc/NetworkManager/conf.d/10-globally-managed-devices.conf
daecdafe66e474402395c4fb23eb20bb1db1bf45fc8a1da89d286a57570a869e  overlay/etc/NetworkManager/conf.d/kiosk.conf
8edab7a076b0802812991f94c7bf1fe1556669e91b46020ef11ac4c4b0ed5b09  overlay/etc/X11/xorg.conf.d/10-kiosk.conf
c20cd567970bb1fd7364af1e68baeb47ad8be67a8ab8766a1ff2031c5141d9cc  overlay/etc/fstab
48bef90bf3804ed0a3a3a2ad6cb6c2a0ccd06ab0d169e55aba89f92943add2de  overlay/etc/hostname
8e1cebeaa97f7d2b59e078ffe5c6cb10ad144049277e37d83ef7cecfcf0a0afd  overlay/etc/polkit-1/rules.d/50-kiosk.rules
1a25306c51ebefbe547f20a43603bbbadf8f2464f510ff755445a7a70a1f2733  overlay/etc/sysctl.d/90-kiosk.conf
b86aaef6227a5824e04d89c3ce772d8479fadd5e6a1e13d908cce627bfd5f7cc  overlay/etc/systemd/journald.conf.d/kiosk.conf
9a8764b2132a80abcc30d5a6a30180a90177ba8eddf0741d0455349a5ddfded8  overlay/etc/systemd/logind.conf.d/kiosk.conf
4368449caebff4de8fb38f73787b63c7a575aa49862f6921de34a28d4764b8d3  overlay/etc/systemd/system/NetworkManager.service.d/kiosk.conf
41f6a7b7e7d48646734c2c937f4fc1eef56102048a63420d349bb6d2155af230  overlay/etc/systemd/system/kiosk-growdata.service
9fbf7d8db6455969f2e62cba6087cdf04f5170f6553fa5bf34ea4ad3bcf19769  overlay/etc/systemd/system/kiosk.service
6a2a46a868a19fdbab9db2c85831059c428cfabc94ad9b461b8a6c4a4f07c6b4  overlay/etc/udev/rules.d/90-kiosk-usb.rules
9ad7344ca3eb63785d4dcbcf7d3056eae65d3bc3aef70dfc75043b7a3e8a481e  overlay/opt/kiosk/kiosk.py
a838dc4e90eb75bd01d0732accfa7449b7ecc9f345bf2a57a08d7ea1f7cc4c06  overlay/opt/kiosk/rc.xml
ed3602962138a6b2408c77bbb1eda7cc8065f2bbc6a965e4d19727f1d70ddb39  overlay/opt/kiosk/session.sh
94c0c1bde0f7cb4817684f73d8b01bc193828656ab99fe38ae63f0a125b2bcdb  overlay/usr/local/sbin/kiosk-growdata
4a7733f237ed0ce1f06686ae02be449c15fcbfabc6c7a7123ea950c76660d837  test/mk-test-image.sh
e76eb83ffb324ff644b69fb65d8ab6cec97d35369d2a1056bc9513a397b5360a  test/qmon.py
d39714cda94e064594b9aac27d7931c744d1354fc4440fba6b3f3f8c2776fbd8  test/rdpsrv.sh
10b8e9bfac8efd870c0e811df98834e296ea9b714c44dac3d7669ac9afc1ab88  test/run-qemu.sh
046a8b46568db8a62e395a65e470af520544396c4df7e9b5f68b93d3c2c96f13  test/ser.py
43bdaf2e4726e98fec849d41c687a8fb5ddca3feb96fb45524fa4b82b6d804ae  test/uitest.py
f666170a9c3910d292a7c41229b33be88c014765909be84f9a001322096c9da4  test/uitest.sh
35ecd03f14be2d2a19da60dd3594b28e7518e52bf15ada8a50718275b71eca1c  test/vncsrv.sh
__KIT_EOF__
( cd "$DEST" && sha256sum -c --quiet .manifest.sha256 ) || { echo "ERROR: the script was damaged during copying (checksum mismatch). Re-download it." >&2; exit 1; }
chmod +x "$DEST/build-all.sh" "$DEST/build-rootfs.sh" "$DEST/build-image.sh" "$DEST/overlay/opt/kiosk/kiosk.py" "$DEST/overlay/opt/kiosk/session.sh" "$DEST/overlay/usr/local/sbin/kiosk-growdata"
[ -n "${KIT_ONLY:-}" ] && { echo "kit unpacked (KIT_ONLY set), not building"; exit 0; }
exec sh "$DEST/build-all.sh" "${1:-$PWD/out}"
