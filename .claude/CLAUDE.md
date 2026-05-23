# Minisforum V3 SE — Machine Notes & Fixes

Hardware notes and known edge cases for the Minisforum V3 SE tablet under Linux.
Keep this distro-agnostic; document hardware behaviour and kernel-level edge cases only.

## Hardware quick reference
- CPU/iGPU: AMD Ryzen 7 7735U ("Rembrandt"), Radeon 680M, display core **DCN 3.1.2** (`dcn31`)
- USB4/Thunderbolt: AMD Rembrandt NHI (`1022:162e/162f`) + Intel Goshen Ridge TB4 bridges
- BIOS: vendor string `Micro Computer (HK) Tech Limited V3 SE/RBPAC`

---

## EDGE CASE: USB4/Thunderbolt DisplayPort hotplug can deadlock the iGPU

**Symptom:** Connecting a USB4/Thunderbolt dock or hub that carries a DisplayPort tunnel
can freeze the desktop — the compositor stops responding and only a text VT remains usable.

**Root cause — amdgpu DCN3.1 SMU regression, NOT a Thunderbolt driver bug.**
On DP-tunnel hotplug, amdgpu reprograms display clocks via the DCN3.1 clock manager.
The SMU message times out:

```
WARNING: .../display/dc/clk_mgr/dcn31/dcn31_smu.c:140 at dcn31_smu_send_msg_with_param+0x11b/0x1a0 [amdgpu]
  dcn31_update_clocks -> dcn20_prepare_bandwidth -> dc_commit_streams
  -> amdgpu_dm_atomic_commit_tail -> drm_atomic_commit (in the compositor process)
```

The display pipeline then wedges mid atomic-commit and the GPU spins forever on:

```
amdgpu …: failed to write reg 2890 wait reg 28a2
amdgpu …: failed to write reg 1aa89 wait reg 1aa8a
```

The iGPU SMU/clock manager is hung and blocks the DRM/compositor kernel threads.
(A `scx_cgroup_move_task` / `kernel/sched/ext.c` WARN may appear at boot if a sched_ext
scheduler is active — that is unrelated noise.)

**Regression window:** introduced around kernel **7.0.9**; **7.0.5** was the last version
observed working with the same hardware. Booting an earlier known-good kernel avoids it.

### Recovery when already frozen
1. Switch to a text VT (`Ctrl+Alt+F2`) and log in.
2. **Physically unplug the dock/hub.** Once the GPU is in the `failed to write reg` loop it
   usually will NOT recover — the iGPU SMU is wedged.
3. Reboot. The GPU only resets cleanly on a full reboot.

### Graceful shutdown while the iGPU is wedged
The wedge is confined to the DRM/display kernel threads and the compositor — systemd,
storage and the rest of userspace stay alive. A clean shutdown does NOT need the GPU,
so avoid a cold power-off if you can still reach a VT:

1. From the VT: `sudo sync && sudo systemctl poweroff` (or `reboot`). The screen won't
   update, but services stop and filesystems unmount underneath. It may stall at the very
   end when systemd tries to reset the hung GPU — by then volumes are already synced and
   unmounted, so a power-button finish there is harmless.
2. If systemd itself is unresponsive, use Magic SysRq to flush before powering off — tap
   **Alt+SysRq** + `S` `U` `O` one per second (sync, remount read-only, power off). The
   `S`/`U` steps are what protect the filesystems. Enable it ahead of time if needed:
   `echo 1 | sudo tee /proc/sys/kernel/sysrq`.
3. Cold power-button hold only as a last resort.

### Mitigations
- **Boot an earlier known-good kernel** (last good ≈ 7.0.5) until a release ships the
  DCN31 SMU-timeout fix. Re-test by hotplugging and watching:
  `journalctl -k -f | grep -iE 'dcn31_smu|failed to write reg'`.
- **amdgpu debug mask:** add `amdgpu.dcdebugmask=0x10` to the kernel command line to disable
  parts of the DCN feature path. Less reliable than running a good kernel; verify it
  actually suppresses the SMU timeout before relying on it.
- **Disable USB4 DisplayPort tunneling** as a last resort — keeps dock USB/Ethernet but
  loses display-over-dock.

### Diagnostics
```bash
journalctl -k -b -1 | grep -iE 'dcn31_smu|failed to write reg'   # previous boot
journalctl --list-boots                                          # short boots == crashes
boltctl list                                                     # TB device auth state
```
