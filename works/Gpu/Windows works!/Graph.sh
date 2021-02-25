# My test
Windows will only work with *Nvidia Desktop Driver*! as VFIO hides the optimus Intel iGPU interface.

# Discuss
https://gist.github.com/Misairu-G/616f7b2756c488148b7309addc940b28#gistcomment-2622108

I have been using gpu passthrough for years on an msi gt70-2pe.
It is a muxless laptop as far as i know.
not sure.
basically, if you use uefi (ovmf) it will not work as the windows side sees optimus and demands that you have the intel video shared with qemu also, thus the code 43 error.
if i use seabios then windows cannot see that i have optimus and the nvdiai driver will work.
i have an gtx 880m 8gb.
i boot windows 7 with seabios.
i upgraded a copy of windows 7 to windows 10, thus maintaining seabios and thus code 43 does not happen.
