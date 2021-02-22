https://www.reddit.com/r/VFIO/comments/7d27sz/you_can_now_passthrough_your_dgpu_as_you_wish/dpvubpd/?utm_source=reddit&utm_medium=web2x&context=3

quote: '''
Verequies
edited 3 years ago
Great post, I've been doing this for over a year now with my Dell Precision M4800. I don't use bumblebee however. Talked about this in a few posts previously (as comments), and said much what you have said :). Great job!

MXM is more likely to be able to have a dedicated video output than those that have the GPU soldered. I can tell the difference by stating its thickness, if its a thick laptop (like my Precision M4800) it'll probably have MXM, if its thin (like the XPS 9560) then soldered. As for turning off/on the dGPU, I use ACPI calls. So our setups are a bit different but achieve the same result.

Heres my QEMU config: https://pastebin.com/uPPsmpz1

And my GPU script: https://pastebin.com/zLQPHPQk

I also compile my own version of QEMU with VCPU Pinning, PulseAudio & Clover EFI Bootloader patches :)

Generally, if I were to recommend someone to try this out, I would first tell them to test it without using bumblebee, faster to setup and less things to go wrong. If it works, then sweet, add bumblebee :)
'''
