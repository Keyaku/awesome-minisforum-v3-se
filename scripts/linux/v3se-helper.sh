#!/usr/bin/env bash
#
# v3se-helper — quick-fix dispatcher for the Minisforum V3 SE.
#
# Commands:
#   volume   Restart wireplumber to recover global volume control.
#            Requires the wireplumber soft-mixer drop-in from
#            docs/fixes/linux-audio.md (workaround A).
#   rotate   Manual escape hatch that toggles the primary output
#            between normal and left rotation via kscreen-doctor.
#            Mirrors scripts/linux/input/rotateButton.sh — prefer
#            binding that script to the hardware rotate button for
#            normal use.

set -eu

readonly THIS=${0##*/}

usage() {
	cat <<-EOF >&2
		Usage: ${THIS} [-h] [-v|-q] COMMAND [COMMAND...]

		Commands:
		  volume    Restart wireplumber (requires workaround A drop-in).
		  rotate    Toggle screen rotation via kscreen-doctor (KDE).

		Options:
		  -h, --help    Show this help.
		  -v/q          Increase/Decrease verbosity.
	EOF
}

verbosity=0
log_info()  {
	[ "${verbosity}" -lt 1 ] && return 0
	printf '%s\n' "$*" >&2
}
log_warn()  {
	[ "${verbosity}" -lt 0 ] && return 0
	printf 'warning: %s\n' "$*" >&2
}
log_error() {
	[ "${verbosity}" -lt 0 ] && return 0
	printf 'error: %s\n' "$*" >&2
}

# Option parsing
args=()
while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) usage; exit 0 ;;
		-v) verbosity=$((verbosity + 1)) ;;
		-q) verbosity=$((verbosity - 1)) ;;
		--) shift; args+=("$@"); break ;;
		-*) log_error "unknown option: $1"; usage; exit 2 ;;
		*) args+=("$1") ;;
	esac
	shift
done

if [ "${#args[@]}" -eq 0 ]; then
	usage
	exit 2
fi

# Commands

cmd_volume() {
	local sys_conf="/etc/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf"
	local user_conf="${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf"

	if [ ! -f "$sys_conf" ] && [ ! -f "$user_conf" ]; then
		log_error "alsa-soft-mixer.conf not found at either:"
		log_error "  $sys_conf"
		log_error "  $user_conf"
		log_error "Install it first — see docs/fixes/linux-audio.md (workaround A)."
		return 1
	fi

	log_info "Restarting wireplumber..."
	systemctl --user restart wireplumber
}

cmd_rotate() {
	if ! command -v kscreen-doctor >/dev/null 2>&1; then
		log_error "kscreen-doctor not found (KDE-only command)."
		return 1
	fi

	local rotation
	rotation="$(kscreen-doctor -o | grep Rotation | cut -d' ' -f2)"

	if [[ "$rotation" == *"1"* ]]; then
		log_info "Rotating to left."
		kscreen-doctor output.1.rotation.left
	else
		log_info "Rotating to normal."
		kscreen-doctor output.1.rotation.normal
	fi
}

rc=0
for arg in "${args[@]}"; do
	case "$arg" in
		volume) cmd_volume || rc=$? ;;
		rotate) cmd_rotate || rc=$? ;;
		*) log_error "unknown command: $arg"; rc=2 ;;
	esac
done
exit "$rc"
