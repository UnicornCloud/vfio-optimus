# Discuss
https://gist.github.com/Misairu-G/616f7b2756c488148b7309addc940b28#gistcomment-2622108

```I have been using gpu passthrough for years on an msi gt70-2pe.
It is a muxless laptop as far as i know.
not sure.
basically, if you use uefi (ovmf) it will not work as the windows side sees optimus and demands that you have the intel video shared with qemu also, thus the code 43 error.
if i use seabios then windows cannot see that i have optimus and the nvdiai driver will work.
i have an gtx 880m 8gb.
i boot windows 7 with seabios.
i upgraded a copy of windows 7 to windows 10, thus maintaining seabios and thus code 43 does not happen.
```


https://gist.github.com/Misairu-G/616f7b2756c488148b7309addc940b28#gistcomment-2647387
```Pilo11 commented on Jul 14, 2018 • 
@s2156945

I've got the exact same problem as you (Clevo N957TP6). I used Arch Linux as native OS and created vm with virtmanager and got Code 43. I am very sure it has something to do with the NVidia driver for Windows.
Why am I so sure?

Because I created a qemu VM with the same usual settings as hidden kvm, fake hyperv id et cetera...
But I installed an Arch Linux guest. And this guest was able to use the Nvidia card (with ROM. Without it did not work). I ran Unigine Heaven to test it on Linux (I did not use nouveau, I use original nvidia driver for Linux). Furthermore I could plug in an external monitor (DP) and saw the Linux guest there.

I am too silly to understand these ROM UEFI ACPI things. But now I am thinking it is most likely a Windows nvidia driver problem... Some people thing that the Windows guest needs the complete Optimus infrastructure (iGPU + dGPU) to work properly. But no one knows what this nvidia driver is really checking... I'm close to give up...

This is also interesting: https://github.com/jscinoz/optimus-vfio-docs/blob/master/README.md

He also describes a working Linux guest Passthrough. But that Windows passthrough needs extra stuff to be done.

"What doesn't work (yet)
Windows guest
Will need custom ACPI table to get VBIOS, as detailed above"

"Long term we need to build a custom ACPI table (provided to qemu with the -acpitable option) that has _ROM implemented at the correct path. The _ROM implementationm would need to seek over a hard-coded buffer stored elsewhere and return the VBIOS in 4kb chunks as expected by nvidia driver"

Another good up-to-date thread for our problem and the muxless guys: https://www.reddit.com/r/VFIO/comments/8gv60l/current_state_of_optimus_muxless_laptop_gpu/
```
