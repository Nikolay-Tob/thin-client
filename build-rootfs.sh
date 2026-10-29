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
    chmod 755 $R/opt/kiosk/kiosk.py $R/opt/kiosk/installer.py $R/opt/kiosk/session.sh $R/usr/local/sbin/kiosk-growdata $R/usr/local/sbin/kiosk-install
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

# installer needs efibootmgr (UEFI boot entry); added as a separate stage so existing rootfs caches stay usable
if ! stage s5-installer; then
    log installer-packages
    mounts
    rm -f $R/etc/resolv.conf; cp /etc/resolv.conf $R/etc/resolv.conf
    printf '#!/bin/sh\nexit 101\n' > $R/usr/sbin/policy-rc.d; chmod +x $R/usr/sbin/policy-rc.d
    chroot $R apt-get update -qq
    # apt refuses to install while the pruned Mesa/LLVM packages are 'broken': fetch the .debs and use dpkg
    chroot $R sh -c 'cd /tmp && apt-get download efibootmgr libefiboot1t64 libefivar1t64 libpopt0 && dpkg -i --force-depends /tmp/*.deb && rm -f /tmp/*.deb'
    chroot $R apt-get clean
    rm -rf $R/var/lib/apt/lists/* $R/var/cache/apt/* $R/usr/share/man $R/usr/share/doc/efibootmgr 2>/dev/null || true
    rm -f $R/usr/sbin/policy-rc.d $R/etc/resolv.conf
    ln -s ../run/NetworkManager/resolv.conf $R/etc/resolv.conf
    done_stage s5-installer
fi

# SSVNC viewer (local scaling, cursor modes) and NTP client; fetched as .debs (apt refuses to install into the pruned tree)
if ! stage s6-extras; then
    log extras
    mounts
    rm -f $R/etc/resolv.conf; cp /etc/resolv.conf $R/etc/resolv.conf
    chroot $R apt-get update -qq
    chroot $R sh -c 'cd /tmp && apt-get download ssvnc systemd-timesyncd && dpkg -i --force-depends /tmp/systemd-timesyncd_*.deb \
        && mkdir -p /tmp/ssvnc-x && dpkg-deb -x /tmp/ssvnc_*.deb /tmp/ssvnc-x \
        && install -D -m 755 /tmp/ssvnc-x/usr/lib/ssvnc/vncviewer /opt/ssvnc/ssvncviewer \
        && install -D -m 644 /tmp/ssvnc-x/usr/share/doc/ssvnc/copyright /opt/ssvnc/copyright \
        && rm -rf /tmp/*.deb /tmp/ssvnc-x'
    chroot $R systemctl enable systemd-timesyncd.service
    chroot $R apt-get clean
    rm -rf $R/var/lib/apt/lists/* $R/var/cache/apt/* $R/usr/share/man $R/usr/share/doc/systemd-timesyncd 2>/dev/null || true
    rm -f $R/etc/resolv.conf
    ln -s ../run/NetworkManager/resolv.conf $R/etc/resolv.conf
    done_stage s6-extras
fi

# boot splash (Plymouth, theme "sibintek": firmware/BGRT logo + company banner); .debs + dpkg as the tree is pruned
if ! stage s7-splash; then
    log splash
    mounts
    rm -f $R/etc/resolv.conf; cp /etc/resolv.conf $R/etc/resolv.conf
    printf '#!/bin/sh\nexit 101\n' > $R/usr/sbin/policy-rc.d; chmod +x $R/usr/sbin/policy-rc.d
    chroot $R apt-get update -qq
    chroot $R sh -c 'cd /tmp && apt-get download plymouth libplymouth5 plymouth-label plymouth-theme-spinner && dpkg -i --force-depends /tmp/*.deb; rm -f /tmp/*.deb'
    # plymouth-theme-spinner ships the two-step plugin; its own themes are replaced by ours
    # two-step needs the stock UI images (lock.png etc.); take them from the spinner theme, without its animation and logo
    rm -rf /tmp/ply-img; mkdir -p /tmp/ply-img
    [ -d $R/usr/share/plymouth/themes/spinner ] && (cd $R/usr/share/plymouth/themes/spinner && for f in *.png; do
        case "$f" in animation-*|watermark.png) ;; *) cp "$f" /tmp/ply-img/;; esac; done)
    rm -rf $R/usr/share/plymouth/themes/sibintek $R/usr/share/plymouth/themes/spinner $R/usr/share/plymouth/themes/bgrt $R/usr/share/plymouth/themes/tribar
    mkdir -p $R/usr/share/plymouth/themes/sibintek && cp /tmp/ply-img/*.png $R/usr/share/plymouth/themes/sibintek/ 2>/dev/null || true
    # (no spinner: the theme has a single transparent animation frame, see overlay/)
    cp -a "$KIT/overlay/." $R/
    chmod 755 $R/etc/initramfs-tools/hooks/kiosk-branding $R/etc/initramfs-tools/scripts/init-premount/branding
    chroot $R update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/sibintek/sibintek.plymouth 200
    chroot $R update-alternatives --set default.plymouth /usr/share/plymouth/themes/sibintek/sibintek.plymouth
    # no splash on shutdown/reboot (faster, fewer moving parts)
    chroot $R systemctl mask plymouth-poweroff.service plymouth-reboot.service plymouth-halt.service plymouth-kexec.service 2>&1 | tail -1
    KVER=$(cat "$OUT/stamps/kver")
    log "initramfs with splash"
    chroot $R mkinitramfs -o /tmp/initrd.img $KVER
    cp $R/tmp/initrd.img "$OUT/bootfiles/initrd.img"; rm -f $R/tmp/initrd.img
    chroot $R apt-get clean
    rm -rf $R/var/lib/apt/lists/* $R/var/cache/apt/* $R/usr/share/man $R/usr/share/doc/plymouth* $R/boot/* 2>/dev/null || true
    rm -f $R/usr/sbin/policy-rc.d $R/etc/resolv.conf
    ln -s ../run/NetworkManager/resolv.conf $R/etc/resolv.conf
    done_stage s7-splash
fi

# always refresh our own files (cheap, idempotent) so edits to overlay/ end up in the image
cp -a "$KIT/overlay/." $R/
chmod 755 $R/opt/kiosk/kiosk.py $R/opt/kiosk/installer.py $R/opt/kiosk/session.sh $R/usr/local/sbin/kiosk-growdata $R/usr/local/sbin/kiosk-install
umounts
log squashfs
rm -f "$OUT/root.sqsh"
mksquashfs $R "$OUT/root.sqsh" -comp zstd -Xcompression-level 12 -b 256K -noappend -no-xattrs -quiet
ls -lh "$OUT/root.sqsh"
echo ROOTFS_DONE
