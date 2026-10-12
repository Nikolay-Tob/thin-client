#!/bin/sh
# Copy of disk.img with a VNC profile preconfigured (10.0.2.2 = the host as seen from QEMU user-net)
# and a serial debug shell enabled on the kernel command line.
set -e
cd /work/build
cp disk.img test.img
rm -rf td; mkdir -p td/kiosk td/nm
cat > td/kiosk/config.json <<J
{"lang":"ru","default":"t1","autoreconnect":true,"keyboard":"us",
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
