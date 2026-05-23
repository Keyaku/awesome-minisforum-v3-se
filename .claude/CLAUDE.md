# Minisforum V3 SE — Machine Notes & Fixes

Hardware notes and known edge cases for the Minisforum V3 SE tablet under Linux.
Keep this distro-agnostic; document hardware behaviour and kernel-level edge cases only.

## Hardware quick reference

- CPU/iGPU: AMD Ryzen 7 7735U ("Rembrandt"), Radeon 680M, display core **DCN 3.1.2** (`dcn31`), codename **Yellow Carp**
- USB4/Thunderbolt: AMD Rembrandt NHI (`1022:162e/162f`) + Intel Goshen Ridge TB4 bridges
- BIOS: vendor string `Micro Computer (HK) Tech Limited V3 SE/RBPAC`

---

## EDGE CASE: USB4/Thunderbolt DisplayPort hotplug can deadlock the iGPU

**Symptom:** Connecting a USB4/Thunderbolt dock/hub that carries a DisplayPort tunnel freezes the desktop — the compositor stops responding and only a text VT remains usable. The hub also blocks a clean boot if attached at power-on.

**Root cause — broken GPU firmware blob in `linux-firmware-amdgpu` 20260519.** The regression lives in `/usr/lib/firmware/amdgpu/yellow_carp_dmcub.bin.zst` (the DMUB microcode for DCN 3.1.2 / Yellow Carp / Radeon 680M). It is **not** a kernel regression — the same crash reproduces on kernels 7.0.5, 7.0.8, and 7.0.9; downgrading the kernel does not help. The broken DMUB ships as version string `0x0400004B`.

On DP-tunnel hotplug, amdgpu reprograms display clocks via the DCN3.1 clock manager. The SMU message times out:

```
WARNING: .../display/dc/clk_mgr/dcn31/dcn31_smu.c:140 at dcn31_smu_send_msg_with_param+0x11b/0x1a0 [amdgpu]
  dcn31_update_clocks -> dcn20_prepare_bandwidth -> dc_commit_streams
  -> amdgpu_dm_atomic_commit_tail -> drm_atomic_commit
```

The display pipeline then wedges mid atomic-commit and the GPU spins forever on:

```
amdgpu …: failed to write reg 2890 wait reg 28a2
amdgpu …: failed to write reg 1aa89 wait reg 1aa8a
```

**Why the whole kernel goes sluggish (not just the display):** the wedged DRM atomic-commit thread holds an **SRCU read-side critical section** while blocked on the dead SMU. Until it releases, no `synchronize_rcu()` anywhere in the kernel can complete, so the next D-state task downstream of that is a `kworker` stuck in `synchronize_rcu` → `wait_for_completion`. This is why `systemctl poweroff` stalls forever near the end — systemd's final shutdown steps need RCU grace periods that will never come. The filesystem layer itself is fine; only the kernel's orderly-shutdown path is blocked.

(A `scx_cgroup_move_task` / `kernel/sched/ext.c` WARN may appear at boot if a sched_ext scheduler like `scx_lavd` is active — that is unrelated noise.)

### Fix: pin `linux-firmware-amdgpu` to 20260410

The 20260410 release of the GPU firmware ships an earlier DMUB blob (sha256 prefix `e758135…` vs the broken `b268198…` in 20260519) and resolves the hotplug freeze entirely.

```bash
sudo pacman -U /var/cache/pacman/pkg/linux-firmware-amdgpu-1:20260410-1-any.pkg.tar.zst
```

Then pin it in `/etc/pacman.conf` so `-Syu` won't silently re-break the system:

```
IgnorePkg = linux-firmware-amdgpu
```

CPU microcode (`amd-ucode`) is unrelated to this bug — leave it on the current release. Periodically remove the pin and retest once newer `linux-firmware` versions ship; the DMUB blob version string at boot (`amdgpu …: [drm] DMUB hardware initialized: version=0x…`) tells you whether a release actually changed the blob.

### SysRq must be fully enabled BEFORE you need it

CachyOS default `kernel.sysrq = 16` enables **only sync** — `U` (remount read-only), `B`/`O` (reboot/poweroff), and `t`/`w` (task dumps) are all silently ignored. If you only discover this while wedged, you cannot recover gracefully and cannot capture diagnostics. Set it persistently up-front:

```bash
echo 'kernel.sysrq = 1' | sudo tee /etc/sysctl.d/99-sysrq.conf
sudo sysctl -w kernel.sysrq=1
cat /proc/sys/kernel/sysrq   # confirm == 1
```

### Recovery when already frozen

Goal isn't a pretty shutdown — it's **flushing the filesystem before cutting power**. systemd's poweroff cannot complete (see SRCU note above), so don't bother fighting it.

1. **Unplug the dock/hub.** Won't un-wedge the GPU but stops new atomic-commits piling up.
2. Optional but valuable for upstream bug reports: `echo w > /proc/sysrq-trigger` then `dmesg | tail -100` to capture which task is stuck in D-state and on which lock. Requires `kernel.sysrq = 1`.
3. Magic SysRq sequence — hold `Alt`, tap `SysRq` (= PrintScreen), then one key per second:
	- **`S`** — sync. Wait for `Emergency Sync complete`.
	- **`U`** — remount everything read-only. Wait for confirmation.
	- **`B`** — immediate reboot (bypasses the hung GPU-reset path that traps `systemctl poweroff`).
4. After `S`+`U` the volumes are flushed and read-only, so `B` is clean for the filesystem. btrfs has survived this every time.
5. Cold power-button hold only if SysRq is not enabled (mask < 49).

Do **not** rely on `sudo systemctl poweroff` once the GPU is wedged — it will hang at the final step and the screen won't update, so you can't tell it stalled. `S`/`U`/`B` is faster and gives you visible confirmation each step.

### Mitigations besides the firmware pin

- **`amdgpu.dcdebugmask=0x10`** kernel parameter — verified ineffective against this bug.
- **Disable USB4 DisplayPort tunneling** in the desktop — keeps dock USB/Ethernet but loses display-over-dock. Last-resort workaround if a firmware pin isn't viable.

### Diagnostics

```bash
pacman -Q linux-firmware-amdgpu                                  # confirm pinned version
journalctl -k -b -1 | grep -iE 'dcn31_smu|failed to write reg'   # previous boot
journalctl --list-boots                                          # short boots == crashes
journalctl -k -b | grep -i 'DMUB hardware initialized'           # DMUB blob version loaded
boltctl list                                                     # TB device auth state
```
