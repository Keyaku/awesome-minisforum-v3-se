# Windows Fixes & Tweaks

## V3 Adj — power profile switching

A kludge of scripts bundling [RefreshRateSwitcher](https://github.com/sryze/RefreshRateSwitcher) and [RyzenAdj](https://github.com/FlyGoat/RyzenAdj) to control power limits and auto-set brightness/refresh on AC ↔ Battery transitions.

1. Extract [V3Adj.zip](../../scripts/windows/power/V3Adj.zip) to `C:\`.
2. Run `V3 Adj task install.bat` **as Administrator**.

> [!NOTE]
> - Defaults: 37 W on AC, 9.5 W on Battery.
> - Edit `V3_PowerSwap.bat` to change limits.

> [!WARNING]
> Set the BIOS profile to 54 W before raising the current limits.

## CRU profile — extend VRR range down to 36 Hz

[Custom Resolution Utility](https://www.monitortests.com/forum/Thread-Custom-Resolution-Utility-CRU) by ToastyX, with a V3-specific profile.

1. Extract [Cru V3 Profile.zip](../../scripts/windows/display/Cru%20V3%20Profile.zip).
2. Run `CRU.exe`.
3. Import `v3 36 to 165.bin`.
4. Restart the display driver with `restart64.exe`, or reboot.

## Enable integer scaling

Run [Embeded_Integer_Scaling_On.reg](../../scripts/windows/display/Embeded_Integer_Scaling_On.reg) and reboot. Then enable integer scaling under *Display* in *AMD Software: Adrenalin Edition*.

To revert: run [Embeded_Integer_Scaling_Off.reg](../../scripts/windows/display/Embeded_Integer_Scaling_Off.reg).

_Credits to Wobble._
