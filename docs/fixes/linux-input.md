# Linux — Input & Rotation

## Automatic rotation and accelerometers

See [upstream discussion](https://github.com/mudkipme/awesome-minisforum-v3/issues/2#issuecomment-2279282784) (original repo).

## Manual rotation script (KDE)

[rotateButton.sh](../../scripts/linux/input/rotateButton.sh) toggles the primary output between normal and left rotation using `kscreen-doctor`. Bind it to a button or shortcut.

_Credits to Briar._

## Ghost touches / phantom stylus hover

Symptom: pointer jumps to a fixed area of the screen (typically near the bottom edge) and triggers hover previews / pop-ups even with no finger or stylus on the panel. Reproduces on external monitors too, because the desktop is acting on real (but bogus) input events from the digitizer.

**Root cause:** the Goodix `27C6:0121` i2c-HID digitizer latches into a stuck "tool in proximity" state and keeps reporting a phantom pen at a near-edge coordinate. `evtest /dev/input/event11` shows `ABS_MISC = 1` (tool in range) with `ABS_X` / `ABS_Y` pinned, while no stylus is present.

**Fix:** unbind and rebind the `i2c_hid_acpi` driver for the digitizer — resets the controller and clears the latched state without rebooting. Run [fix-ghost-touches.sh](../../scripts/linux/input/fix-ghost-touches.sh). Touch + stylus drop for ~2 seconds and come back clean.

**Trigger:** not yet pinned down. Does not appear strictly tied to resume from suspend.

**Suspect — screen protector:** the official Minisforum screen protector is fiddly to apply and prone to micro-detachment at the corners. Capacitive digitizers sense field changes through the glass, and an air gap from a lifted protector edge distorts the local field; the geometry of the phantom coordinate often matches the location of the lifted area. Worth re-seating or removing the protector if the ghost coordinate consistently lines up with a visible bubble or lifted corner.

**Diagnostics:** [capture-ghost-touches.sh](../../scripts/linux/input/capture-ghost-touches.sh) logs `evtest` per device + kernel ring buffer + udev properties into a timestamped directory. Useful for confirming the digitizer is the source (vs. a wireless receiver or trackpad) and capturing the stuck coordinates for a potential upstream report.

## Stylus / touch input lands on the external monitor

On Wayland/KDE, absolute pointer devices (touchscreen, stylus) must be pinned to a specific output. If unmapped, KWin spreads their coordinate space across the whole desktop layout — a tap at the centre of the tablet then ends up on the centre of the bounding box of all monitors, i.e. on the external one.

Fix: [map-stylus-to-internal.sh](../../scripts/linux/input/map-stylus-to-internal.sh) detects the internal `eDP` output via `kscreen-doctor` and writes the `kwinrc [Tablet]` `OutputName` entry for the three digitizer sub-devices (touch, stylus, hover), then reconfigures KWin. Also wired into `apply-fixes.sh` as `input.stylus.map`.

## Remap the Copilot button

By default, the Copilot button emits `Super L + Shift L + XF86TouchpadOff`. Use [Input Remapper](https://github.com/sezanzeb/input-remapper) (tested on Nobara) to bind it to something useful — e.g. `KEY_COMPOSE` to open the context menu.
