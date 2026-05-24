# Distro-Specific Notes

Distro-level procedures for the Minisforum V3 SE. This file holds package-manager and distro-specific steps. See [known-bugs.md](known-bugs.md) for current package regressions affecting this hardware.

The first section [General](#general) is distro-agnostic. Add a new H2 per distro family as needed.

## General

### Keep a fallback kernel installed

Rolling distros can land a hardware-breaking kernel regression at any update. Keep at least one known-good fallback (e.g. `linux-lts` on Arch, `kernel-longterm` on openSUSE) installed and selectable from the boot menu, so you always have something to boot when the latest kernel breaks something on this tablet.

### Bootloader — systemd-boot

Entries live in `/boot/loader/entries/*.conf`. To add kernel parameters (e.g. an amdgpu debug mask while working around a GPU regression), append to the `options` line of the relevant entry, then verify:

```bash
sudo bootctl status
```

### Bootloader — GRUB

Edit `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub` and regenerate:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

## Arch Linux

Applies to Arch and most derivatives (EndeavourOS, CachyOS, etc.).

### Downgrading after a bad kernel/firmware update

`pacman` keeps previously installed packages in its cache:

```bash
ls /var/cache/pacman/pkg/ | grep <package-name>
# reinstall a known-good version (kernel AND matching headers must be the same version):
sudo pacman -U /var/cache/pacman/pkg/<kernel>-<ver>.pkg.tar.zst \
               /var/cache/pacman/pkg/<kernel>-headers-<ver>.pkg.tar.zst
```

Pin it so the next `-Syu` doesn't pull the broken version back in — add to `/etc/pacman.conf`:

```
IgnorePkg = <package-name> <package-name>-headers
```

Remove the `IgnorePkg` line once a fixed release is out, then update normally.

> CachyOS note: the kernel package may be a CachyOS variant (e.g. `linux-cachyos*`) rather than stock `linux`; substitute the actual package name above. CachyOS kernels come from the CachyOS repos, not Arch core.
