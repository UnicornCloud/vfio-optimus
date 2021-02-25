sudo mkdir /etc/qemu
echo "allow virbr0" | sudo tee /etc/qemu/bridge.conf
sudo nano /etc/qemu/bridge.conf
sudo chmod -R 640 /etc/qemu/bridge.conf 
#sudo chown -R root:qemu /etc/qemu/bridge.conf 
sudo chown -R root:root /etc/qemu/bridge.conf 
