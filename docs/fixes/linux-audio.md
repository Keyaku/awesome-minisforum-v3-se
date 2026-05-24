# Linux — Audio Fixes

## Volume buttons not working when the keyboard is detached

> [!NOTE]
> [libinput](https://gitlab.freedesktop.org/libinput/libinput/-/releases/1.26.2) 1.26.2 ships quirks for the Minisforum V3. On Arch-based distros or Fedora 40+ you don't need this manual step.

Quick install:

```bash
curl -L https://raw.githubusercontent.com/Keyaku/awesome-minisforum-v3-se/main/scripts/linux/audio/linux_fix_sound.sh | sudo sh
```

Manual install — create `/etc/libinput/local-overrides.quirks`:

```ini
[Minisforum V3 volume keys]
MatchName=AT Translated Set 2 keyboard
MatchDMIModalias=dmi:*svnMicroComputer(HK)TechLimited:pnV3:*
ModelTabletModeNoSuspend=1
```

## Global volume control with the speaker — workaround A (wireplumber)

> [!WARNING]
> `alsa-firmware` is required for this to work.

1. Copy [alsa-soft-mixer.conf](../../scripts/linux/audio/alsa-soft-mixer.conf) to `/etc/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf` (system-wide) or `~/.config/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf` (per-user).
2. Reboot.

> [!NOTE]
> Run `wpctl status` and `pactl list short cards` to identify the correct card. The one matching `Family 17h/19h HD Audio Controller` is the target.
>
> ```
> ❯ wpctl status
> Audio
>   └─  Devices:
>       48. Rembrandt Radeon High Definition Audio Controller [alsa]
>       49. Family 17h/19h HD Audio Controller  [alsa]
>
> ❯ pactl list short cards
> 48      alsa_card.pci-0000_c4_00.1      alsa
> 49      alsa_card.pci-0000_c4_00.6      alsa
> ```

_Credits to Aru._

## Global volume control — workaround B (alsa-card-profile)

> [!NOTE]
> This is an alternative to workaround A — do not combine them; results may differ.

1. In `/usr/share/alsa-card-profile/mixer/paths/analog-output.conf.common`, add the following block **before** `[Element PCM]`:

   ```
   [Element Master]
   switch = mute
   volume = ignore
   ```

2. In `/usr/share/alsa-card-profile/mixer/paths/analog-output-headphones.conf`, change the `[Element Master]` block to:

   ```
   [Element Master]
   switch = mute
   volume = ignore
   override-map.1 = all
   override-map.2 = all-left,all-right
   ```

3. Restart wireplumber: `systemctl --user restart wireplumber.service`.
4. Test headphones and speakers.

_Credits to ChaosSpectre & makito89._

## Disable audio session suspension

Fixes the headphone port dropping every few seconds when used.

Copy [alsa-disable-suspension.conf](../../scripts/linux/audio/alsa-disable-suspension.conf) to `~/.config/wireplumber/wireplumber.conf.d/alsa-disable-suspension.conf`.
