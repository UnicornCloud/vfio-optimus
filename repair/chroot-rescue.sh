# https://askubuntu.com/questions/976894/install-package-to-ubuntu-16-04-installation-while-booted-into-live-cd

mount /dev/sda2 /mnt
mount --bind /dev /mnt/dev
mount --bind /sys /mnt/sys
mount --bind /proc /mnt/proc
mount --bind /run /mnt/run # if needed, as noted above
chroot /mnt
apt install gnucash # or whatever you need
