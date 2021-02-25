#!/bin/bash

rom=MSI-GTX1070-MaxQ.rom
image=/var/lib/libvirt/images/ubuntu20.10.qcow2

if=ide
iso=/home/me/uni/iso/19042.631.201119-0144.20h2_release_svc_refresh_CLIENTENTERPRISEEVAL_OEMRET_x64FRE_en-us.iso


# Refer https://github.com/saveriomiroddi/qemu-pinning for how to set your cpu affinity properly
qemu-system-x86_64 \
  -name "Windows10-QEMU" \
  -machine type=q35,accel=kvm \
  -global ICH9-LPC.disable_s3=1 \
  -global ICH9-LPC.disable_s4=1 \
  -enable-kvm \
  -cpu host,kvm=off,hv_vapic,hv_relaxed,hv_spinlocks=0x1fff,hv_time,hv_vendor_id=12alphanum \
  -smp 6,sockets=1,cores=3,threads=2 \
  -m 8G \
  -mem-prealloc \
  -rtc clock=host,base=localtime \
  -device ich9-intel-hda -device hda-output \
  -device qxl,bus=pcie.0,addr=1c.4,id=video.2 \
  -vga none \
  -nographic \
  -serial none \
  -parallel none \
  -k en-us \
  -spice port=5901,addr=127.0.0.1,disable-ticketing \
  -usb \
  -device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1 \
    -device vfio-pci,host=01:00.0,x-vga=on,multifunction=on,romfile=$rom \
    -device vfio-pci,host=01:00.1 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
  -drive if=pflash,format=raw,file=WIN_VARS.fd \
  -boot menu=on \
  -boot order=c \
  -drive id=disk0,if=$if,cache=none,format=qcow2,file=$image \
\
  -device pci-bridge,addr=12.0,chassis_nr=2,id=head.2 \
  -device usb-tablet \
  -netdev user,id=user.0 -device e1000,netdev=user.0
