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
. "$(dirname -- "$0")/../lib/common.sh"
require_root "$@"
need_cmd evtest udevadm journalctl

outdir="${1:-/tmp/v3se-ghost-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$outdir"
echo "logging to $outdir"

# Identify digitizer event nodes by walking sysfs from the bound i2c-HID
# device — catches all sub-interfaces (touch, stylus, hover/"UNKNOWN")
# regardless of how the kernel chose to name them.
mapfile -t devs < <(
	hid_root=/sys/bus/i2c/drivers/i2c_hid_acpi/i2c-PNP0C50:00
	if [ -d "$hid_root" ]; then
		for ev_sys in "$hid_root"/*/input/input*/event*; do
			[ -d "$ev_sys" ] || continue
			ev=/dev/input/${ev_sys##*/}
			name=$(cat "${ev_sys%/event*}/name" 2>/dev/null) || name=
			printf '%s\t%s\n' "$ev" "$name"
		done
	else
		# Fallback: name-based scan (other hardware / unbound digitizer).
		for ev in /dev/input/event*; do
			name=$(udevadm info --query=property --name="$ev" 2>/dev/null \
				| sed -n 's/^NAME=//p' | tr -d '"')
			case "$name" in
				*[Gg]oodix*|*GXTP*|*27C6:0121*|*[Tt]ouchscreen*|*[Pp]en*|*[Ss]tylus*)
					printf '%s\t%s\n' "$ev" "$name"
					;;
			esac
		done
	fi
)

if [ "${#devs[@]}" -eq 0 ]; then
	echo "no touchscreen/pen devices matched — listing all input devices:" >&2
	for ev in /dev/input/event*; do
		n=$(udevadm info --query=property --name="$ev" | sed -n 's/^NAME=//p' | tr -d '"')
		printf '  %s\t%s\n' "$ev" "$n"
	done >&2
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
	echo "=== udev properties (touchscreen/pen) ==="
	while IFS=$'\t' read -r ev name; do
		echo "--- $ev ($name) ---"
		udevadm info --query=property --name="$ev"
	done < <(printf '%s\n' "${devs[@]}")
	echo "=== all input devices ==="
	for ev in /dev/input/event*; do
		n=$(udevadm info --query=property --name="$ev" | sed -n 's/^NAME=//p' | tr -d '"')
		printf '  %s\t%s\n' "$ev" "$n"
	done
} >"$outdir/state.txt" 2>&1

echo "Reproduce the ghost touches now. Ctrl+C when done."
wait
