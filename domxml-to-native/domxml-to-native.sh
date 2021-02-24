virsh dumpxml windows > try.xml
virsh domxml-to-native qemu-argv try.xml > try.sh
chmod +x try.sh
