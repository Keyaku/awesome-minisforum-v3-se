Awesome Minisforum V3 SE
========================

Useful (unofficial) information for [Minisforum V3 AMD Tablet](https://www.minisforum.com/page/v3/index.html?lang=en) users, with extra notes for the **V3 SE** revision (Ryzen 7 7735U, Radeon 680M).

Forked from [mudkipme/awesome-minisforum-v3](https://github.com/mudkipme/awesome-minisforum-v3) and extended with the SE model primarily in mind.

## Documentation

- [docs/fixes/windows.md](docs/fixes/windows.md) — Windows tweaks (power profiles, CRU VRR profile, integer scaling)
- [docs/fixes/linux-audio.md](docs/fixes/linux-audio.md) — volume keys, global volume control, audio-session suspension
- [docs/fixes/linux-input.md](docs/fixes/linux-input.md) — screen rotation, Copilot button
- [docs/fixes/linux-power.md](docs/fixes/linux-power.md) — RyzenAdj power profiles (KDE)
- [docs/fixes/linux-camera.md](docs/fixes/linux-camera.md) — IR camera / Howdy facial recognition
- [docs/distros.md](docs/distros.md) — distro-specific procedures (currently Arch / CachyOS)
- [docs/known-bugs.md](docs/known-bugs.md) — current buggy kernels / firmware, workarounds, upstream status
- [docs/scripts.md](docs/scripts.md) — reference for every file under `scripts/`

## Reviews

- [Minisforum V3 3-in-1 review: the first ever Windows tablet with AMD's Hawk Point APU aka the AMD Ryzen 7 8840U](https://www.notebookcheck.net/Minisforum-V3-3-in-1-review-the-first-ever-Windows-tablet-with-AMD-s-Hawk-Point-APU-aka-the-AMD-Ryzen-7-8840U.829081.0.html) by Notebookcheck
- [A Brief Review of the Minisforum V3 AMD Tablet](https://mudkip.me/2024/04/14/A-Brief-Review-of-the-Minisforum-V3-AMD-Tablet/) by Mudkip
- [Minisforum V3 Tablet - hardware compatibility report](https://www.reddit.com/r/linuxhardware/s/rQ7BrCkx4w) by Tsuki4735

## Videos

- [MinisForum V3 vs. Surface Pro 10 - Which Tablet is Better? Comprehensive.](https://www.youtube.com/watch?v=reh_iWrlJV8) by cbutters Tech
- [Minisforum V3 Tablet (AMD R7 8840U) Review: Tweaking Guide, Benchmarks, Hawk Point Testing](https://www.youtube.com/watch?v=ivm78Qyls3A) by Moore's Law Is Dead
- [Android + SteamOS on a Tablet! Minisforum V3 Quick Impressions (feat. Bazzite OS)](https://www.youtube.com/watch?v=MrlnZXNTvtM) by Aru
- [Tablet PCs are Kind of Amazing [MinisForum V3 Review]](https://www.youtube.com/watch?v=8P0G-JLeZD4) by Retro Game Corps
- [Minisforum V3 FULL Walkthrough. Ryzen 7 8840U Windows 11 Pro Tablet](https://www.youtube.com/watch?v=c_zbxrHhtQA) by TechTablets
- [It's a THICK tablet and I'm kinda into that - Minisforum V3](https://www.youtube.com/watch?v=kI_Y231zwoU) by ShortCircuit (Linus Tech Tips)
- [Minisforum V3 AMD Tablet Review! The Best 3 in 1 We've Ever Gotten Our Hands On](https://www.youtube.com/watch?v=Sy4PjHci6qs) by ETA PRIME
- [Minisforum V3 Tablet FULL Test and Review: This is Stupid Fast - Ryzen 8840U, 32GB RAM, 2560x1600](https://youtu.be/hIwAlQLy8Go?si=vSMEaYY7aPcamGkk) by Tek Syndicate

## Resources

- [Drivers and Firmware Update](https://www.minisforum.com/new/support?lang=en#/support/page/download/120)
- [Minisforum Discord Server](https://discord.com/invite/Pxrg8WpFCa)
- [RyzenAdj](https://github.com/FlyGoat/RyzenAdj) — adjust power management settings

## Hardware Guide

### Micro SD Card Adapter

If you want to expand the storage of the tablet with the SD Card slot, the BaseQi iSDA 750A adapter is a good fit. _Credits to killshot007\_._

![](images/sd-card-adapter.jpg)

## Known Issues

- ~~Enabling AMD Fluid Motion Frames in *AMD Software: Adrenalin Edition* may cause Windows to reboot.~~ Fixed in recent Adrenalin releases.
- See [docs/known-bugs.md](docs/known-bugs.md) for current Linux kernel/firmware regressions affecting this hardware.
