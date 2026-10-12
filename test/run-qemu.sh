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
