# Shared helpers for V3 SE Linux fix scripts.
# Source this file; do not execute it directly.
#
# Usage:
#   . "$(dirname -- "$0")/../lib/common.sh"   # adjust path per script location

# Guard against direct execution.
case "${0##*/}" in
	common.sh|common) echo "common.sh is a library; source it, do not run it." >&2; exit 2 ;;
esac

# --- privilege ---------------------------------------------------------------

# Re-exec the calling script under sudo if it isn't running as root.
require_root() {
	if [ "$(id -u)" -ne 0 ]; then
		exec sudo -E "$0" "$@"
	fi
}

# Refuse to run as root (for scripts that touch the user's session / config).
require_user() {
	if [ "$(id -u)" -eq 0 ]; then
		echo "run as a regular user, not root" >&2
		exit 1
	fi
}

# --- command checks ---------------------------------------------------------

# need_cmd cmd [cmd...] — bail out if any are missing.
need_cmd() {
	local c missing=0
	for c in "$@"; do
		command -v "$c" >/dev/null 2>&1 || { echo "missing: $c" >&2; missing=1; }
	done
	[ "$missing" -eq 0 ] || exit 1
}

# pick_cmd VAR cmd [cmd...] — set VAR to the first command on PATH; bail
# if none found. e.g. `pick_cmd QDBUS qdbus6 qdbus-qt6 qdbus`.
pick_cmd() {
	local var=$1; shift
	local c
	for c in "$@"; do
		if command -v "$c" >/dev/null 2>&1; then
			printf -v "$var" '%s' "$c"
			return 0
		fi
	done
	echo "missing: none of $* found on PATH" >&2
	exit 1
}
