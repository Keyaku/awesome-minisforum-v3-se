#!/usr/bin/env bash
# Map the V3 SE touchscreen + stylus to the internal panel only.
#
# On Wayland/KDE, absolute pointer devices have to be pinned to a specific
# output, otherwise KWin spreads their coordinate space across the whole
# desktop layout — tapping the tablet then moves the cursor onto an external
# monitor. This script writes the kwinrc entries that pin the Goodix
# digitizer (touch + stylus + hover) to the internal eDP panel.

set -eu
set -o pipefail
. "$(dirname -- "$0")/../lib/common.sh"
require_user
need_cmd kwriteconfig6 kscreen-doctor
pick_cmd QDBUS qdbus6 qdbus-qt6 qdbus

# Find the internal panel — kscreen-doctor lists outputs; the embedded one
# is reported with an "eDP" name on every system we've seen.
output=$(kscreen-doctor -o 2>/dev/null \
	| awk '/Output:/ { for (i=1;i<=NF;i++) if ($i ~ /^eDP/) print $i }' \
	| head -n1)

if [ -z "${output:-}" ]; then
	echo "could not detect internal eDP output from kscreen-doctor -o" >&2
	kscreen-doctor -o >&2 || true
	exit 1
fi

echo "mapping Goodix digitizer to ${output}"

# All three sub-devices the controller exposes: touch, stylus, hover.
for dev in \
	"PNP0C50:00 27C6:0121" \
	"PNP0C50:00 27C6:0121 Stylus" \
	"PNP0C50:00 27C6:0121 UNKNOWN"
do
	kwriteconfig6 --file kwinrc --group Tablet --group "$dev" --key OutputName "$output"
done

"$QDBUS" org.kde.KWin /KWin reconfigure >/dev/null
echo "done. If the mapping doesn't take effect, log out and log back in."
