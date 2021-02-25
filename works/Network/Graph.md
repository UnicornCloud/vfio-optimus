# Solved!
sch: https://www.google.com/search?q=qemu-system+-netdev+virbr0

Answer: https://www.reddit.com/r/VFIO/comments/5kwioi/qemu_failed_to_parse_default_acl_file/
  rel: https://wiki.qemu.org/Features/HelperNetworking

code: `qemu-system-i386 linux.img -net bridge,br=virbr0 -net nic,model=virtio`
