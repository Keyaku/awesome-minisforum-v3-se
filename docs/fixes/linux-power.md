# Linux — Power Management

## RyzenAdj power profiles (KDE Plasma)

A systemd-user service that hooks into KDE's Power Profile daemon and applies a different TDP / refresh-rate target for Power-Saver / Balanced / Performance. Defaults: 15 W @ 60 Hz, 22 W @ 60 Hz, 28 W @ 165 Hz.

Installation and configuration steps in [scripts/linux/power/ryzenadj_power_profiles/README.md](../../scripts/linux/power/ryzenadj_power_profiles/README.md). Requires passwordless `sudo` for the `ryzenadj` binary.
