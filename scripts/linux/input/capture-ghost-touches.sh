#!/usr/bin/env bash
# Capture spurious touchscreen / stylus events for later analysis.
#
# Logs every input event from the touchscreen + pen devices, plus the
# kernel ring buffer for the same window, into a timestamped directory.
# When the ghost touches occur, hit Ctrl+C and inspect the logs.
#
# Look for:
#   * events at fixed coordinates (e.g. (0, max_y), (max_x, max_y))
#     -> firmware / digitizer issue, likely a quirk candidate
#   * coordinates that wander
#     -> EMI (charger, dock, cable) — try a different PSU / battery
#   * bursts that coincide with `i2c_hid` / `hid-multitouch` lines in
#     dmesg.log -> controller reset, often post-resume

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	exec sudo -E "$0" "$@"
fi

need() {
	command -v "$1" >/dev/null 2>&1 || { echo "missing: $1" >&2; exit 1; }
}
need evtest
need libinput

outdir="${1:-/tmp/v3se-ghost-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$outdir"
echo "logging to $outdir"

# Identify Goodix / touchscreen / pen event nodes by name.
mapfile -t devs < <(
	for ev in /dev/input/event*; do
		name=$(udevadm info --query=property --name="$ev" 2>/dev/null \
			| sed -n 's/^NAME=//p' | tr -d '"')
		case "$name" in
			*[Gg]oodix*|*GXTP*|*[Tt]ouchscreen*|*[Pp]en*|*[Ss]tylus*)
				printf '%s\t%s\n' "$ev" "$name"
				;;
		esac
	done
)

if [ "${#devs[@]}" -eq 0 ]; then
	echo "no touchscreen/pen devices matched — list all and pick manually:" >&2
	libinput list-devices | grep -E '^(Device|Kernel):'
	exit 1
fi

printf '%s\n' "${devs[@]}" | tee "$outdir/devices.txt"

pids=()
trap 'kill "${pids[@]}" 2>/dev/null || true; wait 2>/dev/null || true; echo; echo "logs in $outdir"' EXIT INT TERM

# evtest per device — raw ABS_X/Y/MT_* with kernel timestamps.
while IFS=$'\t' read -r ev name; do
	safe=$(echo "$name" | tr -c '[:alnum:]' _)
	evtest --grab=0 "$ev" >"$outdir/evtest-${safe}.log" 2>&1 &
	pids+=($!)
done < <(printf '%s\n' "${devs[@]}")

# libinput aggregate view — easier to spot the corner coords.
libinput debug-events --show-keycodes >"$outdir/libinput.log" 2>&1 &
pids+=($!)

# Kernel log follower — catch i2c-hid resets, controller wakeups.
journalctl -kf --since=now >"$outdir/dmesg.log" 2>&1 &
pids+=($!)

# Snapshot state once at start: charger, USB, mode, etc.
{
	echo "=== date ==="; date -Iseconds
	echo "=== uname ==="; uname -a
	echo "=== charger ==="; grep . /sys/class/power_supply/*/{online,status,model_name} 2>/dev/null || true
	echo "=== usb ==="; lsusb
	echo "=== i2c-hid ==="; ls /sys/bus/i2c/drivers/i2c_hid_acpi/ 2>/dev/null || true
	echo "=== libinput-quirks ==="
	for ev in /dev/input/event*; do
		libinput quirks list "$ev" 2>/dev/null | sed "s|^|$ev: |"
	done
} >"$outdir/state.txt" 2>&1

echo "Reproduce the ghost touches now. Ctrl+C when done."
wait
