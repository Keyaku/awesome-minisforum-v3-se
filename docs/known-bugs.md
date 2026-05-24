# Known Buggy Kernels & Firmware

Running log of upstream regressions that affect the Minisforum V3 / V3 SE. Each entry records:
* Which package broke things.
* Which distro(s) affected, if possible to register.
* What the symptom looks like and the recommended workaround or fix.
* Links to upstream discussion (if any).
* Current status (fixed, unresolved, pending...).

When adding a new entry, follow the same template.

---

## `linux-firmware-amdgpu` 1:20260519-1 — DP-tunnel hotplug freezes the iGPU

**Affects:** Minisforum V3 SE (Ryzen 7 7735U, Radeon 680M = DCN 3.1.2 / Yellow Carp). Reproduced on CachyOS; likely affects any rolling distro shipping the same firmware blob (Arch, Fedora Rawhide, openSUSE Tumbleweed).

**Package:** `linux-firmware-amdgpu` 1:20260519-1 (Arch / CachyOS naming). The regression is in the firmware blob `yellow_carp_dmcub.bin.zst` (DMUB microcode), not in any kernel. The broken DMUB identifies itself at boot as `version=0x0400004B`.

**Symptom:** Connecting a USB4 / Thunderbolt dock or hub that carries a DisplayPort tunnel freezes the desktop. The compositor stops responding, only a text VT stays usable, and `systemctl poweroff` hangs at the final step. If the hub is attached at power-on, the system fails to reach a usable desktop. Kernel log shows:

```
WARNING: .../display/dc/clk_mgr/dcn31/dcn31_smu.c:140 at dcn31_smu_send_msg_with_param+0x11b/0x1a0 [amdgpu]
amdgpu …: failed to write reg 2890 wait reg 28a2
```

The wedged DRM atomic-commit thread holds an SRCU read-side critical section while spinning on the dead SMU, so any later `synchronize_rcu()` (including systemd's shutdown path) blocks forever. Filesystems are unaffected.

**Workaround:** Downgrade to `linux-firmware-amdgpu` 1:20260410-1 (DMUB blob `sha256:e758135…` vs broken `b268198…`) and pin it:

```bash
sudo pacman -U /var/cache/pacman/pkg/linux-firmware-amdgpu-1:20260410-1-any.pkg.tar.zst
```

```ini
# /etc/pacman.conf
IgnorePkg = linux-firmware-amdgpu
```

Verify on next boot via `journalctl -k -b | grep 'DMUB hardware initialized'` — the DMUB version string tells you which blob is actually loaded. Periodically remove the pin and retest when newer `linux-firmware` versions ship.

Tested *ineffective* workarounds: kernel downgrade (7.0.9 → 7.0.5), `amdgpu.dcdebugmask=0x10` kernel parameter. CPU microcode (`amd-ucode`) is unrelated — leave it on current.

**Last-resort mitigation (if the firmware pin isn't viable):** disable USB4 DisplayPort tunneling in the desktop environment. Keeps dock USB / Ethernet but loses display-over-dock.

**Upstream references:** No public bug report, mailing-list thread, or discussion has been located yet. If you find one, add it here.

**Status:** Unresolved upstream. Local fix (firmware pin) confirmed working as of 2026-05-23.

**Recovery from a frozen session:** full forensics, the magic-SysRq sequence, and the `kernel.sysrq = 1` setup required to use it are documented in [.claude/CLAUDE.md](../.claude/CLAUDE.md).
