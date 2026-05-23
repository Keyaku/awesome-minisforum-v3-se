# Distro-Specific Notes (Arch Linux)

Arch-level procedures for the Minisforum V3 SE. Hardware-level behaviour and edge cases
live in `.claude/CLAUDE.md`; this file holds package-manager / distro-specific steps.
Most of this applies to any Arch derivative (EndeavourOS, CachyOS, etc.); CachyOS-only
specifics are called out explicitly.

## Kernels

Arch ships rolling kernels, so a regression can land at any update. Keep at least one
known-good fallback kernel installed (e.g. `linux-lts`) so you always have something to
boot when the latest kernel breaks hardware.

### Downgrading after a bad kernel update
`pacman` keeps previously installed packages in its cache:

```bash
ls /var/cache/pacman/pkg/ | grep <kernel-package-name>
# reinstall a known-good version (kernel AND matching headers must be the same version):
sudo pacman -U /var/cache/pacman/pkg/<kernel>-<ver>.pkg.tar.zst \
               /var/cache/pacman/pkg/<kernel>-headers-<ver>.pkg.tar.zst
```

Pin it so the next `-Syu` doesn't pull the broken version back in — add to `/etc/pacman.conf`:

```
IgnorePkg = <kernel-package-name> <kernel-package-name>-headers
```

Remove the `IgnorePkg` line once a fixed release is out, then update normally.

> CachyOS note: the kernel package may be a CachyOS variant (e.g. `linux-cachyos*`) rather
> than stock `linux`; substitute the actual package name above. CachyOS kernels come from
> the CachyOS repos, not Arch core.

## Bootloader (systemd-boot)

Entries live in `/boot/loader/entries/*.conf`. To add kernel parameters (e.g. an amdgpu
debug mask while working around a GPU regression), append to the `options` line of the
relevant entry, then verify:

```bash
sudo bootctl status
```

If using GRUB instead, edit `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub` and run
`sudo grub-mkconfig -o /boot/grub/grub.cfg`.

## Thunderbolt / USB4 device authorization

Arch uses `bolt` (`boltctl`) for Thunderbolt device authorization:

```bash
boltctl list                 # show known devices and auth state
boltctl authorize <uuid>     # authorize a device
boltctl enroll <uuid>        # authorize + store for automatic future connection
```

Security level is set in BIOS. See `.claude/CLAUDE.md` for the iGPU DP-tunnel deadlock
edge case that can occur on hotplug regardless of distro.

## Diagnostics

```bash
journalctl -k -b -1                 # previous boot's kernel log (after a freeze/crash)
journalctl --list-boots             # unusually short boots indicate crashes
pacman -Q | grep linux              # installed kernels
```
