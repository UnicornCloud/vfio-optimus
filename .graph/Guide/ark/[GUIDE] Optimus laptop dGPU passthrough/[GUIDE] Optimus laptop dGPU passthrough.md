[Reddit post (Archived)](https://www.reddit.com/r/VFIO/comments/7d27sz/you_can_now_passthrough_your_dgpu_as_you_wish/)

#### Table of Content

- [What to expect?](#what-to-expect)
  - [Some TLDR about the idea behind](#some-tldr-about-the-idea-behind)
- [Prerequisites](#prerequisites)
  - [Hardware](#hardware)
  - [System & Software](#system--software)
  - [Update: Attention for MUXless laptop](#update-attention-for-muxless-laptop)
    - [Some success report](#some-success-reports)
    - [Some fail report](#some-fail-reports)
- [Bumblebee setup guide](#bumblebee-setup-guide)
- [dGPU passthrough guide](#dgpu-passthrough-guide)
  - [System & Environment setup](#system--environment-setup)
  - [Prepare your script](#prepare-your-script)
  - [Run your VM and configure guest side](#run-your-vm-and-configure-guest-side)
  - [RemoteFX configure and fine tuning](#remotefx-configure-and-fine-tuning)
  - [Steam in-home Streaming](#steam-in-home-streaming)
  - [External display setup](#external-display-setup)
    - [Looking glass](#looking-glass)
- [FAQ](#faq)
  - [How did you extract you vBIOS?](#how-did-you-extract-you-vbios)
  - [Did you success with AMD CPU?](#did-you-success-with-amd-cpu)
  - [Regarding AMD CPU/GPU?](#regarding-amd-cpugpu)
  - [What about GVT-g? Can I replicate a Optimus system inside a VM?](#what-about-gvt-g-can-i-replicate-a-optimus-system-inside-a-vm)
  - [What about those bare-bone laptop?](#what-about-those-bare-bone-laptop)
  - [Options other than RemoteFX?](#options-other-than-remotefx)
- [Known issue](#known-issue)
- [Reference](#reference)

This is a guide for passing through you dGPU on your laptop for your VM. This guide only apply to laptops that does not load dGPU firmware through acpi call, which include all MUXed laptop and some MUXless laptop. For laptops that use acpi call to load dGPU firmware, please refer to  to [u/jscinoz](https://www.reddit.com/u/jscinoz) 's [optimus-vfio-docs](https://github.com/jscinoz/optimus-vfio-docs). 

Sorry but currently I don't know how to check if your dGPU load its firmware through acpi call. 

**Update**: Use hexadecimal id directly instead of convert it to decimal, add some note for romfile option

**Update**: Forget that `-vga none` would cause `Guest has not initialized the display (yet)` problem if you don't have a system installed

**Update**: Use qemu 2.11.2 with pulse audio patch and vcpupin, add some caveats for 18.04

**Update**: Outdated link to VirtIO windows-guest drivers, thanks to @pascalav, who also attach [a link of how to embed an ACPI table for VBIOS](https://gist.github.com/Misairu-G/616f7b2756c488148b7309addc940b28#gistcomment-2573646)

# What to expect?

Depends on your hardware, you can have a laptop that:

- Physically running a Linux distribution as the host machine,
- Can power on/off and utilize your Nvidia dGPU on demand with bumblebee,
- Can pass your Nvidia dGPU to your VM when you don't need it in your host machine,
- Can have your dGPU back when the VM shutdown,
- Can use your dGPU with bumblebee again without any problem,
- No need to reboot during this dGPU binding/unbinding process,
- No need for external display (depend on your hardware and the version of Windows your VM running),
- Can connect external display directly to your VM (only some machine with specific setup).

![Frame rate test](https://i.imgur.com/tJCPjMu.jpg)

![Unigine Heaven 4.0 Basic test](https://i.imgur.com/YVTTyfN.jpg)

Steam in-home streaming between Windows VM and host:

- Both game use high preset with V-Sync enabled.
- Max fps of Witcher 3 has set to 60.
- No extra monitor what so ever.

![DOOM](https://i.imgur.com/c86OGKF.png)

![Witcher 3](https://i.imgur.com/HCXzaX7.png)

\*This is my laptop running in Optimus mode with a 1080p@120Hz panel (I swapped the original 1080p@60Hz myself) and a MXM form factor Quadro P5000(QS). This laptop is MUXed.

## Some TLDR about the idea behind

As you might read after, this tutorial is pretty much the same as most passthrough guide. The keypoint, however, is to assign Subsystem ID for the dGPU using some vfio-pci options. My dGPU appears to have a Subsystem ID 00000000 inside the VM by default.

About one display setup, although frames are rendered in GPU memory, display ports is not the only way to get those frames. Nvidia itself provides API to capture things in GPU memory, this is why we can have technology like Steam in-home streaming and Geforce experience. For me, I have RemoteFX working, and that is the only reason why I put that in this tutorial. Despite I use a Quadro, this mobile version GPU does not support NvFBC capture API (the same as other consumer card), which means it's capability is no more than a GeForce, so you should be able to get RemoteFX working with Geforce.

Some might be heard of [gnif's phenomenal work](https://forum.level1techs.com/t/a-little-teaser-of-what-is-to-come/121641), which made a huge step forward for one-display setup. Unfortunately, a dummy device is still required for that setup, which is a no go for laptop. Even with a MUXed laptop, having a dummy device plug-in still means that your GPU needs to expose some form of display output signal physically, but most Laptop don't support this. As far as I know, Dell precision 7000 line-up can enable DisplayPortDirectOutput mode in BIOS, which would route GPU signal directly to video output port, while keeping iGPU rendering the built-in display. 

# Prerequisites

Please noted that this tutorial does not support every Optimus laptop. Generally, a good laptop with some specific hardware capability is required. If you have a laptop that come with a swappable MXM form factor graphics card, its highly possible that you'll success. 

Also, due to the nature that laptop varies so much from manufacture to manufacture, there is no way you can tell if it is MUXed, or MUXless, or how a MUXless laptop load its firmware before you get your hands on it. However, the firmware loading mechanism of your GPU is crucial for resolving the infamous Code 43 problem. So please do enough homework (find some success report in particular) before you plan to purchase a laptop for this purpose.

## Hardware

- A CPU that support hardware virtualization (Intel VT-x) and IOMMU (Intel VT-d).

  - Check [here](https://ark.intel.com/Search/FeatureFilter?productType=processors&VTD=true&MarketSegment=Mobile) for a full list of qualified CPU

- A motherboard that support IOMMU with decent IOMMU layout e.g. your dGPU is in its own IOMMU group aside from other devices.

  - For the reason that there is no ACS support for laptop (maybe some bare-bone does), so far, a decent IOMMU layout is crucial since the ACS override patch is not applicable.

- Verification:

  - Boot with `intel_iommu=on` kernel parameter and use `dmesg | grep -i iommu` to verify you IOMMU support, this will also print your IOMMU layout.

  - Example:

    - ```
      # From "lspci":
      # 00:01.0 PCI bridge: Intel Corporation Sky Lake PCIe Controller (x16) (rev 05)
      # 01:00.0 VGA compatible controller: NVIDIA Corporation Device 1bb6 (rev a1)

      # From "dmesg | grep iommu"
      [    0.000000] DMAR: IOMMU enabled
      [    0.086383] DMAR-IR: IOAPIC id 2 under DRHD base  0xfed91000 IOMMU 1
      [    1.271222] iommu: Adding device 0000:00:00.0 to group 0
      [    1.271236] iommu: Adding device 0000:00:01.0 to group 1
      [    1.271244] iommu: Adding device 0000:00:04.0 to group 2
      [    1.271257] iommu: Adding device 0000:00:14.0 to group 3
      [    1.271264] iommu: Adding device 0000:00:14.2 to group 3
      [    1.271277] iommu: Adding device 0000:00:15.0 to group 4
      [    1.271284] iommu: Adding device 0000:00:15.1 to group 4
      [    1.271293] iommu: Adding device 0000:00:16.0 to group 5
      [    1.271301] iommu: Adding device 0000:00:17.0 to group 6
      [    1.271313] iommu: Adding device 0000:00:1c.0 to group 7
      [    1.271325] iommu: Adding device 0000:00:1c.2 to group 8
      [    1.271339] iommu: Adding device 0000:00:1c.4 to group 9
      [    1.271360] iommu: Adding device 0000:00:1f.0 to group 10
      [    1.271367] iommu: Adding device 0000:00:1f.2 to group 10
      [    1.271375] iommu: Adding device 0000:00:1f.3 to group 10
      [    1.271382] iommu: Adding device 0000:00:1f.4 to group 10
      [    1.271390] iommu: Adding device 0000:00:1f.6 to group 10
      [    1.271395] iommu: Adding device 0000:01:00.0 to group 1
      [    1.271407] iommu: Adding device 0000:02:00.0 to group 11
      [    1.271418] iommu: Adding device 0000:03:00.0 to group 12
      ```

    - Here the GPU and its root port are in the same group, and there is no other device in this group, thus make it a decent IOMMU layout.

## System & Software

- Host:
  - I'm currently running Ubuntu 16.04 (with 4.15 kernel), but it should also work on other distribution.
  - System should be installed in UEFI mode, and boot via UEFI.
- Guest:
  - Windows that support RemoteFX. Windows 10 Pro for example.
- QEMU:
  - Currently running QEMU 2.11.2 with pulse audio and vcpupin patch
  - If you you use QEMU 2.10 or higher and encounter a boot hang (dots spinning forever), check your OVMF version, it might need an upgrade. Refer [here](https://bugs.launchpad.net/qemu/+bug/1715700) for further detail.
- RDP Client:
  - Freerdp 2.0 or above for RDP 8 with RemoteFX connection.

**Note**: Keep your dual-boot Windows if you still want to run software like XTU.

## Update: Attention for MUXless laptop

~~Not sure anyone succeseded with a MUXless laptop yet (Or failed with a MUXed laptop)~~. If you do success, please consider leave a comment with your setup (laptop model, year of production/purchase, etc.), so that other people can have some reference.

Now for switchable graphics, there are three different solutions: MUXed(Old), MUXless and MUXed(New)

![Circuits diagram](https://i.imgur.com/GI7v8Gk.jpg)

Most modern Optimus laptop use MUXless scheme, while some others, HP/Thinkpad/Dell mobile workstation, Clevo P650, some Alienware, etc. use MUXed scheme. At the dark age before Optimus solution came out, there is an old MUXed scheme which require reboot to switch graphics card and can only use one at a time, while the modern MUXed allow switch between Optimus and dGPU only, and can even have display output port hooked directly to the dGPU when using Optimus (only applicable for some laptop).

For people who encounter Code 43 with a MUXless scheme, that is to say, you can see your dGPU in guest, can even have nvidia driver installed without any problem, but still have this error code. This is because [ACPI call failed for firmware loading](https://www.reddit.com/r/VFIO/comments/6q7bf5/short_report_wip_got_the_nvidia_gpu_to/), in short:

- Nvidia driver try to read your dGPU ROM from system BIOS instead of using the ROM you provided through vfio-pci (this is actually how a real MUXless dGPU get its ROM).


- Please refer to [u/jscinoz](https://www.reddit.com/u/jscinoz) 's [optimus-vfio-docs](https://github.com/jscinoz/optimus-vfio-docs) if you encounter such problem

### Some success reports 

- [Perdouille got a MUXless laptop working](https://www.reddit.com/r/VFIO/comments/7d27sz/you_can_now_passthrough_your_dgpu_as_you_wish/dqo6jxf/), with MSI GS60-040XFR with an i7-4720HQ and a 970m. 
- [qgnox got a MUXless laptop working](https://www.reddit.com/r/VFIO/comments/7d27sz/you_can_now_passthrough_your_dgpu_as_you_wish/drq3ewm/), with MSI GS60 2PC with GTX860M. 
- ASUS G751JM (i7-4710HQ, NVIDIA gtx 860m), thanks to @d0ku

# Bumblebee setup guide

**Note**: For people who don't want to setup bumblebee, follow [this](https://www.reddit.com/r/VFIO/comments/7d27sz/you_can_now_passthrough_your_dgpu_as_you_wish/dpvwka6/) to get your GPU's ACPI address, and power it on/off by refering script [here](https://www.reddit.com/r/VFIO/comments/7d27sz/you_can_now_passthrough_your_dgpu_as_you_wish/dpvubpd/). (Credit to Verequies from reddit) 

**Note**: You might need to disable secure boot before following continue on this part.

We will first go through my bumblebee setup process. I did install bumblebee first and setup passthrough the second. But it should work the other way around.

1. (Optional) Solving the known interference between TLP and Bumblebee 

   - If you don't want to use tlp, please skip this part.

   - TLP is a must have for a Linux laptop since it provides extra policies to save your battery. Install TLP by `sudo apt install tlp` 
   - Add the output of `lspci | grep "NVIDIA" | cut -b -8` to `RUNTIME_PM_BLACKLIST` in `/etc/default/tlp`, uncomment it if necessary. This will solve the interference.

2. Install Nvidia proprietary driver through Ubuntu system settings (Or other install method you prefer).

3. (Trouble shooting) Solving the library linking problem in Nvidia driver.

   - If error messages show up after executing  `sudo prime-select intel` or `sudo prime-select nvidia`, follow instructions below.

   - ```bash
     # Replace 'xxx' to the velrsion of nvidia driver you installed
     # You might need to perform this operation everytime your upgrade your nvidia driver.
     sudo mv /usr/lib/nvidia-xxx/libEGL.so.1 /usr/lib/nvidia-xxx/libEGL.so.1.org
     sudo mv /usr/lib32/nvidia-xxx/libEGL.so.1 /usr/lib32/nvidia-xxx/libEGL.so.1.org
     sudo ln -s /usr/lib/nvidia-xxx/libEGL.so.375.66 /usr/lib/nvidia-xxx/libEGL.so.1
     sudo ln -s /usr/lib32/nvidia-xxx/libEGL.so.375.66 /usr/lib32/nvidia-xxx/libEGL.so.1
     ```

   - If everything work correctly, `sudo prime-select nvidia` and then logout will give you a login loop. While `sudo prime-select intel` (do this in other tty with Ctrl+Alt+F2) will solve the login loop problem.

   - It is recommended to switch back and forth for once, if you run into some problem after a nvidia driver update.

4. Blocking nouveau

   - Adding content below to `/etc/modprobe.d/blacklist-nouveau.conf`:

     - ```
       blacklist nouveau
       options nouveau modeset=0
       ```

   - `sudo update-initramfs -u` when finish.

   - If you have a DM running under wayland (such as Ubuntu 18.04, it runs GDM in wayland mode, despite GNOME is running under X11), some extra work might be needed to prevent nouveau from loading. Refer [here](https://askubuntu.com/questions/1031511/cant-disable-nouveau-drivers-in-ubuntu-18-04) for details.

5. (Optional) Install CUDA, since the CUDA installation process is [well guided by Nvidia](http://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html), I will skip this part.

   - For CUDA, I personally recommend runfile installation. It is far more easy to maintain compare to other installation method. Just make sure neither the display driver (self-contain in the runfile) nor the OpenGL libraries is checked during the runfile installation process. ONLY install the CUDA Toolkit and don't run `nvidia-xconfig`.

6. Solve some ACPI problem before bumblebee install:

   - Add `nogpumanager acpi_osi=! acpi_osi=Linux acpi_osi=\"Windows 2015\" pcie_port_pm=off` for `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`
     - `nogpumanager` is actually part of the CUDA installation guide.
     - You might need `acpi_osi=\"Windows 2009\"`, if `2015` disable you trackpad.
     - For further information about these parameters, check:
       - https://github.com/Bumblebee-Project/bbswitch/issues/140
       - https://github.com/Bumblebee-Project/Bumblebee/issues/764
       - https://github.com/Bumblebee-Project/Bumblebee/issues/810
   - `sudo update-grub` when finish.
   - (Trouble shooting) If `prime-select` command updates grub, be sure to check your grub file again, as it does not handle escape character correctly, `\"` would become `\`

7. Install bumblebee

   - ```shell
     # For Ubuntu 18.04, the official ppa should work
     sudo add-apt-repository ppa:bumblebee/testing
     sudo apt update

     sudo apt install bumblebee bumblebee-nvidia
     ```

   - Edit `/etc/bumblebee/bumblebee.conf`:

     - Change `Driver=` to `Driver=nvidia`
     - Change all occurrences of `nvidia-current` to `nvidia-xxx` (`xxx` is your nvidia driver version)
     - `KernelDriver=nvidia-xxx`
     - It appears that nvidia driver change its location in Ubuntu 18.04, refer [here](https://github.com/Bumblebee-Project/Bumblebee/issues/951) for details and solutions.

   - Save the file and `sudo service bumblebeed restart`

8. Kernel module loading modification:

   - Make sure corresponding section in `/etc/modprobe.d/bumblebee.conf` look like below

     - ```shell
       # Again, xxx is your nvidia driver version.
       blacklist nvidia-xxx
       blacklist nvidia-xxx-drm
       blacklist nvidia-xxx-updates
       blacklist nvidia-experimental-xxx
       ```

   - Add content below to `/etc/modules-load.d/modules.conf`

     - ```
       i915
       bbswitch
       ```

   - `sudo update-initramfs -u` when finish.

9. (Optional) Create a group for bumblebee so that you don't need to `sudo` every time:

   - If `cat /etc/group | grep $(whoami)` already gives your user name under bumblebee group, skip this part.

   - `groupadd bumblebee && gpasswd -a $(whoami) bumblebee`

10. (Trouble shooting) Try `optirun nvidia-smi`, if encounter `[ERROR][XORG] (EE) Failed to load module "mouse" (module does not exist, 0)`, add lines below to `/etc/bumblebee/xorg.conf.nvidia`

   - ```
     Section "Screen"
       Identifier "Default Screen"
       Device "DiscreteNvidia"
     EndSection
     ```

   - Check [here](https://github.com/Bumblebee-Project/Bumblebee/issues/867) for more information about this problem.

11. Verification:

    - `cat /proc/acpi/bbswitch` should gives you  `Ouput:0000:01:00.0 OFF`

    - `optirun cat /proc/acpi/bbswitch` should gives you  `Ouput:0000:01:00.0 ON`

    - `nvidia-smi` should give you something like:

      - ```
        NVIDIA-SMI couldn't find libnvidia-ml.so library in your system. Please make sure that the NVIDIA Display Driver is properly installed and present in your system.
        Please also try adding directory that contains libnvidia-ml.so to your system PATH.
        ```

    - `optirun nvidia-smi` should gives you something like:

      - ```
        Wed Nov 15 00:36:53 2017       
        +-----------------------------------------------------------------------------+
        | NVIDIA-SMI 384.90                 Driver Version: 384.90                    |
        |-------------------------------+----------------------+----------------------+
        | GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
        | Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
        |===============================+======================+======================|
        |   0  Quadro P5000        Off  | 00000000:01:00.0 Off |                  N/A |
        | N/A   44C    P0    30W /  N/A |      9MiB / 16273MiB |      3%      Default |
        +-------------------------------+----------------------+----------------------+
                                                                                       
        +-----------------------------------------------------------------------------+
        | Processes:                                                       GPU Memory |
        |  GPU       PID   Type   Process name                             Usage      |
        |=============================================================================|
        |    0      7934      G   /usr/lib/xorg/Xorg                             9MiB |
        +-----------------------------------------------------------------------------+
        ```

12. Congratulations, stay and enjoy this moment a little bit before running into the next part.

# dGPU passthrough guide

## System & Environment setup

1. Set up QEMU:

   - QEMU from Ubuntu official PPA should work, just `sudo apt install qemu-kvm qemu-utils qemu-efi ovmf`.

     - Please note that QEMU 2.10 or above require a higher version of OVMF (say if you use UEFI for your VM), otherwise will cause boot hang. Refer [here](https://bugs.launchpad.net/qemu/+bug/1715700) for details about which version. Simplest solution is to use [ovmf package from 18.04 ppa](https://launchpad.net/ubuntu/bionic/+package/ovmf) directly.

   - Here I use QEMU 2.11.2 with pulse audio patch from [spheenik](https://www.reddit.com/user/spheenik) to provide better audio quality and resolve the crackling issue, and vcpupin patch from [saveriomiroddi](https://github.com/saveriomiroddi) for better performance.

     - Details about pulse audio patch:
       - [Improved Pulse Audio Driver for QEMU - Testers/coders needed! (archived)](https://www.reddit.com/r/VFIO/comments/74vokw/improved_pulse_audio_driver_for_qemu/)
       - [Heads up: QEMU audio patch rebased onto 2.12 ](https://www.reddit.com/r/VFIO/comments/8ptqbd/heads_up_qemu_audio_patch_rebased_onto_212/)
       - [Github Gist](https://gist.github.com/spheenik/8140a4405f819c5cd2465a65c8bb6d09/9735bcfaaaef45cf47e1b5d92c5006adf6ecd737)
       - [Github](https://github.com/spheenik/qemu)
     - Details about vcpupin patch
       - [QEMU fork with pinning (with hyper threading support) (archived)](https://www.reddit.com/r/VFIO/comments/79z4q2/qemu_fork_with_pinning_with_hyper_threading/)
       - [Github](https://github.com/saveriomiroddi/qemu-pinning)

   - Follow instructions below to build the QEMU I use (only if you prefer):

     - ```shell
       # Clone saveriomiroddi's vcpupin version of QEMU
       git clone https://github.com/saveriomiroddi/qemu-pinning.git qemu
       cd qemu
       git checkout v2.11.2-pinning

       # Apply pulseaudio from spheenik's git, we're applying the v1 version.
       wget -O - https://gist.githubusercontent.com/spheenik/8140a4405f819c5cd2465a65c8bb6d09/raw/9735bcfaaaef45cf47e1b5d92c5006adf6ecd737/v1.patch | patch -p0

       # (Optional)
       # You might need to set your git email or name before commiting changes
       git commit -am "Apply pulse audio patch"

       # Install dependencies
       sudo apt install libjpeg-turbo8-dev libepoxy-dev libdrm-dev libgbm-dev libegl1-mesa-dev libboost-thread1.58-dev libboost-random1.58-dev libiscsi-dev libnfs-dev libfdt-dev libpixman-1-dev libssl-dev socat libsdl1.2-dev libspice-server-dev autoconf libtool xtightvncviewer tightvncserver x11vnc libsdl1.2-dev uuid-runtime uuid uml-utilities bridge-utils python-dev liblzma-dev libc6-dev libusb-1.0-0-dev checkinstall virt-viewer cpu-checker nettle-dev libaio-dev

       # Prepare to build
       mkdir build
       cd build

       # QEMU does not support python3
       ../configure --prefix=/usr \
           --audio-drv-list=alsa,pa,oss \
           --enable-kvm \
           --disable-xen \
           --enable-sdl \
           --enable-vnc \
           --enable-vnc-jpeg \
           --enable-opengl \
           --enable-libusb \
           --enable-vhost-net \
           --enable-spice \
           --target-list=x86_64-softmmu \
           --python=/usr/bin/python2

       make -j8

       # QEMU does not provide 'make uninstall'
       # Use checkinstall here so that you can remove it by 'dpkg -r'
       # Assign a version number start with numeric number is mandatory when using checkinstall
       sudo checkinstall
       ```

2. Setup kernel module and parameters:

   - Add `intel_iommu=on,igfx_off kvm.ignore_msrs=1` to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, then `sudo update-grub`.

     - From [here](https://github.com/intel/gvt-linux/wiki/GVTg_Setup_Guide#34-grub-update): Since some windows guest 3rd patry application / tools (like GPU-Z / Passmark9.0) will trigger MSR read / write directly, if it access the unhandled msr register, guest will trigger BSOD soon. So we added the `kvm.ignore_msrs=1` into grub for workaround.

   - Add content below to `/etc/initramfs-tools/modules` (order matters!)

     - ```
       vfio
       vfio_iommu_type1
       vfio_pci
       vfio_virqfd
       vhost-net
       ```

     - `sudo update-initramfs -u` when finish.

   - Reboot.

   - `lsmod` for verification.

3. (Optional) Setup hugepages

   - [Reasons to use hugepages](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#Static_huge_pages)

   - Check `cat /proc/cpuinfo` see if it has the `pse` flag (for 2MB pages) or the `pdpe1gb` flag (for 1GB pages)
   - For `pdpe1gb`:
     - Add `default_hugepagesz=1G hugepagesz=1G hugepages=8 transparent_hugepage=never` to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, this will assign a 8GB huge page.
   - For `pse`:
     - Add `default_hugepagesz=2M hugepagesz=2M hugepages=4096 transparent_hugepage=never` to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, this does the same thing above.
   - `sudo update-grub` when finish.
   - Reboot.
   - `ls /dev | grep hugepages` for verification.

## Prepare your script

1. Get your Subsystem ID (SSID) and Subsystem Vendor ID (SVID):

   - Run `optirun lspci -nnk -s 01:00.0`, which will gives you an output like this:

     - ```
       01:00.0 VGA compatible controller [0300]: NVIDIA Corporation Device [10de:1bb6] (rev a1)
       	Subsystem: Dell Device [1028:07b1]
       	Kernel driver in use: nvidia
       	Kernel modules: nvidiafb, nouveau, nvidia_384_drm, nvidia_384
       ```

   - Here, `1028` is the SVID and `07b1` is the SSID. We will use them later.

2. Setup audio:

   - Please refer to [Archwiki/PCI passthrough/Passing VM audio to host via PulseAudio](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#Passing_VM_audio_to_host_via_PulseAudio) and [Archwiki/pulseaudio/Allowing multiple users to use PulseAudio at the same time](https://wiki.archlinux.org/index.php/PulseAudio/Examples#Allowing_multiple_users_to_use_PulseAudio_at_the_same_time)


3. Setup VM:

   - **Note**: Command here only serve as a reference, checkout QEMU documentation for more detail.

   - **Note**: I personally don't prefer libvirt as editing xml is annoying for me. Use libvirt if you like.  `virsh domxml-from-native qemu-argv xxx.sh` can help you converting a QEMU startup script to libvirt XML. Refer [here](https://libvirt.org/drvqemu.html#imex) for more information.

   - **Note**: If you would like to put you GPU at some other address, refer [here](https://www.redhat.com/archives/libvir-list/2013-February/msg00440.html) for details about ICH9 and GMCH (Graphics & Memory Controller Hub) defines. Layout of PCIe devices of your guest machines should follow these guidelines, as to prevent potential problem.

   - **Note**: The `romfile` option in the script below is not required if there is a stand alone GPU ROM chip bundled with your GPU (the case for MXM, not sure for soldered). However, if you decide to use the `romfile` option, please extract it yourself instead of download a copy from the Internet.

   - Create a disk image for your VM:

     - `qemu-img create -f raw WindowsVM.img 75G`

   - Install `iptables` and `tunctl` if you don't have it.

   - Create two script for tap networking:

     - `tap_ifup` (check files below in this gist)
     - `tap_ifdown` (check files below in this gist)

   - Use `dpkg -L ovmf` to locate your `OVMF_VARS.fd` file, copy that to the directory where you store your VM image, then rename it to `WIN_VARS.fd`(or other names you like).

   - Create a script for starting your VM:

     - Recall that our GPU have a SVID `1028`, and a SSID `07b1`, use these two value to set the corresponding vfio-pci options (see script below).

       - This will solve the SSID/SVID all zero problem inside the VM.

     - Don't forget to get a copy of [VirtIO Driver](https://www.linux-kvm.org/page/WindowsGuestDrivers/Download_Drivers)

     - ```shell
       #!/bin/bash

       # Set audio output options
       export QEMU_AUDIO_DRV=pa
       export QEMU_PA_SERVER="<your-pulse-socket>"
       export QEMU_AUDIO_TIMER_PERIOD=500

       # Use command below to generate a MAC address
       # printf '52:54:BE:EF:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256))

       # Refer https://github.com/saveriomiroddi/qemu-pinning for how to set your cpu affinity properly
       qemu-system-x86_64 \
         -name "Windows10-QEMU" \
         -machine type=q35,accel=kvm \
         -global ICH9-LPC.disable_s3=1 \
         -global ICH9-LPC.disable_s4=1 \
         -enable-kvm \
         -cpu host,kvm=off,hv_vapic,hv_relaxed,hv_spinlocks=0x1fff,hv_time,hv_vendor_id=12alphanum \
         -smp 6,sockets=1,cores=3,threads=2 \
         -vcpu vcpunum=0,affinity=1 -vcpu vcpunum=1,affinity=5 \
         -vcpu vcpunum=2,affinity=2 -vcpu vcpunum=3,affinity=6 \
         -vcpu vcpunum=4,affinity=3 -vcpu vcpunum=5,affinity=7 \
         -m 8G \
         -mem-path /dev/hugepages \
         -mem-prealloc \
         -balloon none \
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
         -device vfio-pci,host=01:00.0,bus=root.1,addr=00.0,x-pci-sub-device-id=0x07b1,x-pci-sub-vendor-id=0x1028,multifunction=on,romfile=MyGPU.rom \
         -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
         -drive if=pflash,format=raw,file=WIN_VARS.fd \
         -boot menu=on \
         -boot order=c \
         -drive id=disk0,if=virtio,cache=none,format=raw,file=WindowsVM.img \
         -drive file=windows10.iso,index=1,media=cdrom \
         -drive file=virtio-win-0.1.141.iso,index=2,media=cdrom \
         -netdev type=tap,id=net0,ifname=tap0,script=tap_ifup,downscript=tap_ifdown,vhost=on \
         -device virtio-net-pci,netdev=net0,addr=19.0,mac=<address your generate>
         -device pci-bridge,addr=12.0,chassis_nr=2,id=head.2 \
         -device usb-tablet
         
       # The -device usb-tablet will not be accurate regarding the pointer in some cases, another option is to use 
       # -device virtio-keyboard-pci,bus=head.2,addr=03.0,display=video.2 \
       # -device virtio-mouse-pci,bus=head.2,addr=04.0,display=video.2 \
       ```

     - For libvirt, refer [here](https://gist.github.com/anonymous/500f1edf89d6f22c40bd2cbbdec6490b) for an example of how to masquerade your Subsystem ID. (Credit to jscinoz)

## Run your VM and configure guest side

1. Binding your dGPU to vfio-pci driver:
   - `echo "10de 1bb6" > "/sys/bus/pci/drivers/vfio-pci/new_id"`
2. Run the script to launch your VM
   - Install your Windows system through host side VNC (`remote-viewer spice://127.0.0.1:5930`). 
     - `-device qxl,bus=pcie.0,addr=1c.4,id=video.2` need to be comment out, change `-vga none` to `-vga qxl` so that QXL would become the first GPU and can see POST screen from spice client.
     - Change back once you have everything working.
   - **IMPORTANT**: Driver could be a cause for Code 43, please try both the driver your manufacture provided, and the driver from Nvidia website.
   - Add `192.168.99.0/24` to your Windows VM firewall exception:
     - In `Control Panel\System and Security\Windows Defender Firewall`, click `Advance settings` in the right panel, and `Inbound Rules` -> `New rules`. 
     - Make sure you can `ping` to your VM from host.
     - Some details about setting up VirtIO driver not included here.
   - Enable remote desktop in Windows VM:
     - Right click `This PC`, click `Remote settings` in the right panel.
   - Verify that your GPU (in guest) have the correct hardware ID. `Device manager` -> double click your dGPU -> `Detail`tab -> `Hardware Ids`
     - For me, its `PCI\VEN_10DE&DEV_1BB6&SUBSYS_07B11028`. I'll get `PCI\VEN_10DE&DEV_1BB6&SUBSYS_00000000` if I did't have it masqueraded.
     - In some cases, you will find your dGPU as a `Video controller(VGA compatible)` under `Unknown Device` before your install nvidia driver.
   - Install the official nvidia driver.
     - If everything goes smoothly, you will now be able to see your GPU within `Performance` tab in `Task Manager`.
3. Post VM shut down operation:
   - Unbind your dGPU from vfio-pci driver, `echo "0000:01:00.0" > "/sys/bus/pci/drivers/vfio-pci/0000:01:00.0/driver/unbind"`
   - Power off your dGPU, `echo "OFF" >> /proc/acpi/bbswitch`
   - Run `optirun nvidia-smi` for verification.

## RemoteFX configure and fine tuning

Configure RemoteFX

1. Run `gpedit.msc` through `Win`+`R`.
2. Locate yourself to `Computer Configuration` -> `Administrative Templates` -> `Windows Components` -> `Remote Desktop Service` -> `Remote Desktop Session Host` -> `Remote Session Environment`
   - Enable `Use advanced RemoteFX graphics for RemoteApp`
   - (Optional) Enable `Configure image quality for RemoteFX adaptive Graphics`, set it to `High`
   - Enable `Enable RemoteFX encoding for RemoteFX clients designed for Windows Servier 2008 R2 SP1`
   - Enable `Configure compression for RemoteFX data`, set it to `Do not use an RDP compression algorithm`
     - Connection compression will result extra latency for encode and decode, we don't want this.
3. Locate yourself to `Computer Configuration` -> `Administrative Templates` -> `Windows Components` -> `Remote Desktop Service` -> `Remote Desktop Session Host` -> `Remote Session Environment` -> `RemoteFX for Windows Server 2008 R2`
   - Enable `Configure RemoteFX`
   - (Optional) Enable `Optimize visual experience when using RemoteFX`, set both option to `Highest`.

FreeRDP client configuration:

- Make sure your have FreeRDP 2.0 (Do NOT use Remmina from Ubuntu Official PPA)
  - Compile one yourself or get a nightly build from [here](https://ci.freerdp.com/job/freerdp-nightly-binaries/)
- Get your Windows VM IP address (or assign a static one), here we use `192.168.99.2` as an example.
- `xfreerdp /v:192.168.99.2:3389 /w:1600 /h:900 /bpp:32 +clipboard +fonts /gdi:hw /rfx /rfx-mode:video /sound:sys:pulse +menu-anims +window-drag`
  - Refer [here](https://github.com/awakecoding/FreeRDP-Manuals/blob/master/User/FreeRDP-User-Manual.markdown) for more detail.

Lifting 30-ish fps restriction:

1. Start Registry Editor.
2. Locate and then click the following registry subkey: 
   **HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations**
3. On the **Edit** menu, click **New**, and then click **DWORD(32-bit) Value**.
4. Type DWMFRAMEINTERVAL, and then press Enter. 
5. Right-click **DWMFRAMEINTERVAL**, click **Modify**.
6. Click **Decimal**, type 15 in the **Value data** box, and then click **OK**. This sets the maximum frame rate to 60 frames per second (FPS).

Verify codec usage and fine tuning your frame rate:

- Bring up your task manager, if a simple start menu pop-up animation (Windows 10) could consume you 40+ Mbps, then you are NOT using RemoteFX codec but just vanilla RDP. With a 1600x900 resolution, the start menu pop-up animation should consume a bandwidth less than 25 Mbps, while a 1600x900 Heaven benchmark consume less than 170 Mbps at peak.
- Fire up a benchmark like Unigine Heaven in the VM, check if your dGPU can maintain a higher than 90~95% utility stably. If not, tune down your resolution and try again. You will find a sweet spot that suits your hardware.
- For those don't concern much about image quality, try adding `/gfx-h264:AVC444` option to your FreeRDP script. This will use RDP 8.1 with H.264 444 codec, which consume only 20~30-ish bandwidth even when runing full window Heaven benchmark. But artifacts this codec bring is more than noticeable. 

For gaming:

- 1600x900 or lower resolution RFX connection is recommended for most Core i7 laptop. 
- 1080p connection with game running at 1600x900 windowed mode have the same performance as above.

For other task:

- Tasks that are more GPU compute intensive (which does its operation asynchronously from display update) will not be bottlenecked by CPU, thus you can choose a higher resolution like 1080p.

## Steam in-home Streaming

For the [limitations of RemoteFX](#known-issue), service like Steam in-home streaming or Geforce Experience is more recommended for gaming scenario. 

Extra precautions should be taken for Steam in-home Streaming:

- A Remote desktop connection that use dGPU inside the VM to render its display is still required, or the game will literally not running on the dGPU you just passed.
  - Not 100 percent about this. Maybe manually tell the game to use which GPU is possible?
  - One more thing, Nvidia control panel is not accessible within a RDP session. Nothing will pop-up no matter how hard you click it.
- Make sure your dGPU is the ONLY display adapter enabled inside the VM.
- Use [this method](https://steamcommunity.com/groups/homestream/discussions/0/617335934139051123/) to unlock the remote screen, note that current RDP session will be terminated once unlock success.
  - Pro or higher version of Windows is required.
  - Do not launch the script until the game appears in taskbar, otherwise it won't use your dGPU.

## External display setup

External display require a BIOS setting that can rarely be seen on Optimus laptop. 

- For some Dell laptop (such as mine), There is a `Display port direct output mode` option in `Video` -> `Switchable Graphics`, enable it and it will assign all display port (mDP, HDMI, Thunder Bolt etc.) directly to the dGPU. Check if your BIOS offer some similar options.
  - To also get the audio output from display port, follow [this guide](https://www.reddit.com/r/VFIO/comments/7d27sz/you_can_now_passthrough_your_dgpu_as_you_wish/dpvwka6/) and [this reference script](https://pastebin.com/zLQPHPQk). Thanks for Verequies from reddit.
- However, you will lose your capability to extend your host machine display. As there is no display output port connect to the iGPU, e.g. your host. 
- While RemoteFX will compress the image in exchange for performance (which is not good if you required extreme image quality for professional use), such problem don't exist for external display setup, as it hook the dGPU directly.

### Looking glass

- If your machine can expose video output port to dGPU, then using Looking Glass is possible. 
- Moreover, if you have a Quadro card, you can load EDID directly from file in Nvidia Control Panel, and don't need to plug anything. Can even run without physical video output port expost to dGPU.
  - Though you still need to plug something for the first time setup otherwise Nvidia Control Panel won't show.

# FAQ

## How did you extract you vBIOS?

Well, except for laptop that use MXM graphics card, vBIOS of onboard graphics card is actually part of the system BIOS.

- For the record, I did success without `romfile` option, but there is no guarantee for this approach.
- For MXM graphics card, try using nvflash instead of GPU-Z. (In Windows) Disable your dGPU in device manager and  run command `nvflash -6 xxx.rom` with privilege will extract your vBIOS as xxx.rom (This is the way I did). Try different version of nvflash if you fail.
- For on board GPU:
  - Put the AFUDOS.EXE (or other BIOS backup tool depending on your BIOS) in a DOS-bootable USB device, then use it to extract your entire BIOS.
  - Then boot to windows and use PhoenixTool (or other similar tools) to extract modules contain in that BIOS. 
    - Noted that those extracted modules will have weird name thus you can't be sure which one is for your onboard graphics card. 
  - Finally use some vBIOS Tweaker (MaxwellBiosTweaker or Mobile Pascal Tweaker or other equivalence) to find out which module is your vBIOS. 
    - Simply drag those module rom to the tweaker. Module roms that are not a vBIOS will be displayed as Unsupport Device, while vBIOS (typically around 50~300KB in size) will be successfully readed and show is information like device ID and vendor ID. 
    - Manufactures tend to include several vBIOS for generic purpose. Be sure you find the correct vBIOS that have the same device ID as the one shown in device manager.
    - **Disclaimer**: I just know that you can use this method to extract the vBIOS of onboard graphics in the old days. However laptop BIOS may vary and I am not sure either the extraction process can go smoothly or the extracted and identified vBIOS rom can be used in QEMU without any problem.

## Regarding AMD CPU/GPU?

Never own a laptop with AMD CPU/GPU myself, worth trying though.

## What about GVT-g? Can I replicate a Optimus system inside a VM?

Recently GVT project successful expose guest screen with dmabuf, might be some hope?

Last time I try this, passing dGPU to a GVT-g VM is possible, but the dGPU will report Code 12 with "no enough resources" inside the VM. No idea why.

## What about those bare-bone laptop?

Bare-bone laptop with desktop CPU already have their iGPU disabled in a way you cannot revert (as far as I know), and can only use their dGPU to render the display. Thus there will be no display if you pass it to your VM. 

For those bare-bone laptops who have two dGPUs, passing one to your VM sounds possible? Not sure. Just take extra care if you have two identical dGPU. Check [here](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#Using_identical_guest_and_host_GPUs) for more detail.

## Options other than RemoteFX?

Try nvidia gamestream with moonlight client, or Parsec. Or just pick whatever handful for you.

# Known issue

For RemoteFX connection with xfreerdp: 

- Only windowed game can work, full screen will triger d3d11 0x087A0001 cannot set resolution blablabla problem. Media player does not affect by this.
  - As a solution, use [borderless gaming](https://github.com/Codeusa/Borderless-Gaming) or other equivalence.
  - Windowed client doesn't seems to have this problem.
- Mouse will go wild due to relative mouse is unsupported in RDSH/RDVH connection.
  - Redirect a XBOX controller or USB joystick might solve this? 
  - Use Synergy (v1) with relative mouse mode enabled
  - [RemoteFX Question](https://social.technet.microsoft.com/Forums/windowsserver/en-US/28373bb0-d9a6-4876-bf0b-02f2ba6ea6b3/remotefx-question?forum=winserverhyperv)
  - [Erratic mouse movement in 3D games over RDP with RemoteFX](https://superuser.com/questions/849918/erratic-mouse-movement-in-3d-games-over-rdp-with-remotefx)

# Reference

[XPS-15 9560 Getting Nvidia To Work on KDE Neon](https://gist.github.com/whizzzkid/37c0d365f1c7aa555885d102ec61c048)

[Hexadecimal to Decimal Converter](http://www.binaryhexconverter.com/hex-to-decimal-converter)

[FreeRDP-User-Manual](https://github.com/awakecoding/FreeRDP-Manuals/blob/master/User/FreeRDP-User-Manual.markdown)

[PCI passthrough via OVMF - Arch Wiki](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF)

[CUDA installation guide](http://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html)

[Frame rate is limited to 30 FPS in Windows 8 and Windows Server 2012 remote sessions](https://support.microsoft.com/en-us/help/2885213/frame-rate-is-limited-to-30-fps-in-windows-8-and-windows-server-2012-r)