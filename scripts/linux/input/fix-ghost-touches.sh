#!/usr/bin/env bash
# Unbind + rebind the Goodix i2c-HID digitizer on the V3 SE to clear a
# stuck phantom-proximity state (ghost touches / hover pop-ups, often
# pinned near a panel edge). No reboot needed; touch + stylus drop for
# ~2 s while the driver re-attaches.

set -euo pipefail
. "$(dirname -- "$0")/../lib/common.sh"
require_root "$@"

drv=/sys/bus/i2c/drivers/i2c_hid_acpi
dev=i2c-PNP0C50:00

[ -e "$drv/$dev" ] || { echo "device $dev not bound under $drv" >&2; exit 1; }

echo "$dev" > "$drv/unbind"
sleep 1
echo "$dev" > "$drv/bind"
echo "rebound $dev"
