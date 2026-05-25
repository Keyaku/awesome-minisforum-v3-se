# Linux — Input & Rotation

## Automatic rotation and accelerometers

See [upstream discussion](https://github.com/mudkipme/awesome-minisforum-v3/issues/2#issuecomment-2279282784) (original repo).

## Manual rotation script (KDE)

[rotateButton.sh](../../scripts/linux/input/rotateButton.sh) toggles the primary output between normal and left rotation using `kscreen-doctor`. Bind it to a button or shortcut.

_Credits to Briar._

## Diagnosing ghost touches / spurious stylus events

Occasional reports of spurious pointer activity (often hover-previews near the bottom corners), sometimes with the stylus powered off. No confirmed root cause or fix yet — the Goodix i2c-HID touchscreen is driven by `hid-multitouch` and has no V3-SE-specific quirk upstream.

In case someone stumbles upon this occurrence, run [capture-ghost-touches.sh](../../scripts/linux/input/capture-ghost-touches.sh) to log `evtest`, `libinput debug-events`, and `journalctl -kf` from the touchscreen + pen nodes into a timestamped directory. Inspect the logs for:
- Events at fixed coordinates (e.g. `(0, max_y)`, `(max_x, max_y)`) — points to a digitizer/firmware issue; candidate for a libinput quirk.
- Wandering coordinates that correlate with the charger or a TB dock being plugged — points to EMI; test on battery with the dock disconnected.
- Bursts that line up with `i2c_hid` / `hid-multitouch` lines — controller reset, often post-resume. See [linux-surface#417](https://github.com/linux-surface/linux-surface/issues/417) for the canonical resume-ghost-touch pattern on similar hardware.

If you collect a reproducer, please open an issue with the captured directory attached.

## Remap the Copilot button

By default, the Copilot button emits `Super L + Shift L + XF86TouchpadOff`. Use [Input Remapper](https://github.com/sezanzeb/input-remapper) (tested on Nobara) to bind it to something useful — e.g. `KEY_COMPOSE` to open the context menu.
