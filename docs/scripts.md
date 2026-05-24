# Scripts Reference

Layout — top-level split by OS, second level by topic:

```
scripts/
├── linux/
│   ├── audio/
│   │   ├── alsa-disable-suspension.conf
│   │   ├── alsa-soft-mixer.conf
│   │   └── linux_fix_sound.sh
│   ├── input/
│   │   └── rotateButton.sh
│   ├── power/
│   │   └── ryzenadj_power_profiles/
│   └── v3se-helper.sh
└── windows/
    ├── display/
    │   ├── Cru V3 Profile.zip
    │   ├── Embeded_Integer_Scaling_Off.reg
    │   └── Embeded_Integer_Scaling_On.reg
    └── power/
        └── V3Adj.zip
```

## Linux

### Audio

#### `audio/linux_fix_sound.sh`

Installs a libinput quirks file at `/etc/libinput/local-overrides.quirks` so the volume keys keep working when the keyboard is detached. Runs as root. Only needed on distros shipping libinput < 1.26.2.

See [fixes/linux-audio.md](fixes/linux-audio.md#volume-buttons-not-working-when-the-keyboard-is-detached).

#### `audio/alsa-soft-mixer.conf`

WirePlumber drop-in that forces the `Family 17h/19h HD Audio Controller` card onto the software mixer so the global volume keys affect speakers. Install to `/etc/wireplumber/wireplumber.conf.d/` (system) or `${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d/` (per-user).

See [fixes/linux-audio.md](fixes/linux-audio.md#global-volume-control-with-the-speaker--workaround-a-wireplumber).

#### `audio/alsa-disable-suspension.conf`

WirePlumber drop-in that disables ALSA session suspension on all input/output nodes. Fixes headphone-port dropouts every few seconds. Install to `${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d/`.

See [fixes/linux-audio.md](fixes/linux-audio.md#disable-audio-session-suspension).

### Input

#### `input/rotateButton.sh`

KDE-only. Toggles the primary output between normal and left rotation using `kscreen-doctor`. Bind it to the rotation button or a shortcut.

See [fixes/linux-input.md](fixes/linux-input.md#manual-rotation-script-kde).

### Helper

#### `v3se-helper.sh`

Quick-fix dispatcher for recurring V3 SE recoveries. Subcommands:

- `volume` — restart `wireplumber` to recover global volume control. Refuses to run unless [alsa-soft-mixer.conf](../scripts/linux/audio/alsa-soft-mixer.conf) is installed at either `/etc/wireplumber/wireplumber.conf.d/` or `${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d/` (workaround A — see [fixes/linux-audio.md](fixes/linux-audio.md#global-volume-control-with-the-speaker--workaround-a-wireplumber)).
- `rotate` — manual escape hatch that toggles screen rotation via `kscreen-doctor` (KDE). For normal use, bind [rotateButton.sh](../scripts/linux/input/rotateButton.sh) to the hardware rotate button instead.

Pass `-v` for verbose output, `-h` for help.

### Power

#### `power/ryzenadj_power_profiles/`

A small systemd-user service plus shell script that hooks into KDE's Power Profile daemon and applies a different TDP / refresh-rate target for Power-Saver / Balanced / Performance. Defaults: 15 W @ 60 Hz, 22 W @ 60 Hz, 28 W @ 165 Hz. See its own [README.md](../scripts/linux/power/ryzenadj_power_profiles/README.md) for installation steps (requires passwordless sudo for `ryzenadj`).

See [fixes/linux-power.md](fixes/linux-power.md).

## Windows

### Display

#### `display/Cru V3 Profile.zip`

Custom Resolution Utility (ToastyX) with a V3-specific profile that widens the VRR range down to 36 Hz.

See [fixes/windows.md](fixes/windows.md#cru-profile--extend-vrr-range-down-to-36-hz).

#### `display/Embeded_Integer_Scaling_On.reg` / `display/Embeded_Integer_Scaling_Off.reg`

Toggle the embedded-display integer-scaling registry key so the option becomes selectable in *AMD Software: Adrenalin Edition*.

See [fixes/windows.md](fixes/windows.md#enable-integer-scaling).

### Power

#### `power/V3Adj.zip`

RyzenAdj + RefreshRateSwitcher bundle that swaps TDP / brightness / refresh between AC and Battery profiles. Extracted to `C:\`, installed via `V3 Adj task install.bat` (Administrator).

See [fixes/windows.md](fixes/windows.md#v3-adj--power-profile-switching).
