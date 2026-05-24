#!/usr/bin/env bash
#
# apply-fixes — apply known Minisforum V3 SE Linux fixes interactively.
#
# Run unprivileged. The script uses sudo internally only where needed.
# See docs/fixes/linux-*.md for the underlying fixes.

set -eu
set -o pipefail

readonly THIS=${0##*/}
readonly REPO_ROOT="$(cd -- "$(dirname -- "$0")/../.." && pwd)"

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

usage() {
	cat <<-EOF
		Usage: ${THIS} [OPTIONS] [key=value...]

		Apply known Minisforum V3 SE Linux fixes. By default the script prompts
		for every applicable fix, then prints a report and asks for one final
		confirmation before doing anything.

		Options:
		  --all              Accept every applicable fix without prompting.
		                     For conflicting choices the first (default)
		                     option is used (e.g. audio.volume.workaround=A).
		  --dry-run          Print the report but make no changes.
		  -v, --verbose      Verbose output.
		  -vv                Very verbose: include file paths + contents that
		                     would be written/edited in the final report.
		  -y, --yes          Skip the final confirmation prompt (still honours
		                     per-fix prompts unless --all is given).
		  -h, --help         Show this help.

		Key=value overrides (skip the prompt for that fix and force a value):
		  audio.volume.keys={true|false}
		  audio.volume.workaround={A|B|none}
		  audio.suspension={true|false}
		  camera.howdy={true|false}
		  input.rotation.kde={true|false}
		  input.copilot.remap={true|false}
		  power.ryzenadj={true|false}

		Examples:
		  ${THIS}                                  # fully interactive
		  ${THIS} --all                            # apply everything sensible
		  ${THIS} --all audio.volume.workaround=B  # all, but pick workaround B
		  ${THIS} --dry-run -vv                    # see what would happen
	EOF
}

ALL=0
DRY_RUN=0
VERBOSITY=0
SKIP_FINAL=0
declare -A OVERRIDES=()

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help)    usage; exit 0 ;;
		--all)        ALL=1 ;;
		--dry-run)    DRY_RUN=1 ;;
		-v|--verbose) VERBOSITY=$((VERBOSITY + 1)) ;;
		-vv)          VERBOSITY=$((VERBOSITY + 2)) ;;
		-y|--yes)     SKIP_FINAL=1 ;;
		*=*)          OVERRIDES[${1%%=*}]=${1#*=} ;;
		-*)           printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
		*)            printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

# ---------------------------------------------------------------------------
# Logging / helpers
# ---------------------------------------------------------------------------

log()  { printf '%s\n' "$*" >&2; }
vlog() { [ "${VERBOSITY}" -ge 1 ] && printf '%s\n' "$*" >&2 || true; }
warn() { printf 'warning: %s\n' "$*" >&2; }
err()  { printf 'error: %s\n' "$*" >&2; }

if [ "$(id -u)" -eq 0 ]; then
	err "run this script as a regular user — it will sudo internally where needed."
	exit 1
fi

ask_yn() {
	# $1 prompt, $2 default (y|n)
	local prompt=$1 default=$2 ans hint
	[ "$default" = y ] && hint='[Y/n]' || hint='[y/N]'
	while :; do
		printf '%s %s ' "$prompt" "$hint" >&2
		read -r ans || ans=$default
		ans=${ans:-$default}
		case "$ans" in
			[Yy]|[Yy][Ee][Ss]) return 0 ;;
			[Nn]|[Nn][Oo])     return 1 ;;
		esac
	done
}

# Run a command, or just print it under --dry-run.
run() {
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '+ %s\n' "$*" >&2
		return 0
	fi
	vlog "+ $*"
	"$@"
}

# Write content to a path. Uses sudo if the parent dir isn't user-writable.
# Args: $1 dest path, content on stdin.
install_file() {
	local dest=$1 dir
	dir=$(dirname -- "$dest")
	local content
	content=$(cat)

	if [ "$DRY_RUN" -eq 1 ]; then
		printf '+ install file: %s\n' "$dest" >&2
		return 0
	fi

	if [ -w "$dir" ] || { [ ! -e "$dir" ] && [ -w "$(dirname -- "$dir")" 2>/dev/null || true ]; }; then
		mkdir -p -- "$dir"
		printf '%s' "$content" > "$dest"
	else
		sudo mkdir -p -- "$dir"
		printf '%s' "$content" | sudo tee -- "$dest" >/dev/null
	fi
	vlog "wrote ${dest}"
}

# ---------------------------------------------------------------------------
# Distro / DE detection
# ---------------------------------------------------------------------------

DISTRO_ID=""
DISTRO_FAMILY="generic"
if [ -r /etc/os-release ]; then
	# shellcheck disable=SC1091
	. /etc/os-release
	DISTRO_ID=${ID:-}
	case " ${ID:-} ${ID_LIKE:-} " in
		*\ arch\ *|*\ archlinux\ *|*\ cachyos\ *|*\ endeavouros\ *|*\ manjaro\ *)
			DISTRO_FAMILY=arch ;;
		*\ fedora\ *|*\ rhel\ *|*\ centos\ *)
			DISTRO_FAMILY=fedora ;;
		*\ debian\ *|*\ ubuntu\ *)
			DISTRO_FAMILY=debian ;;
		*\ opensuse\ *|*\ suse\ *)
			DISTRO_FAMILY=suse ;;
	esac
fi

IS_KDE=0
case "${XDG_CURRENT_DESKTOP:-}${KDE_FULL_SESSION:-}" in
	*KDE*|*kde*|*true*) IS_KDE=1 ;;
esac

# Returns 0 if libinput >= 1.26.2 (ships V3 quirks built-in).
libinput_has_v3_quirks() {
	command -v libinput >/dev/null 2>&1 || return 1
	local v major minor patch
	v=$(libinput --version 2>/dev/null) || return 1
	IFS=. read -r major minor patch <<<"$v"
	[ "${major:-0}" -gt 1 ] && return 0
	[ "${major:-0}" -eq 1 ] && [ "${minor:-0}" -gt 26 ] && return 0
	[ "${major:-0}" -eq 1 ] && [ "${minor:-0}" -eq 26 ] && [ "${patch:-0}" -ge 2 ] && return 0
	return 1
}

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------

# pkg_install <distro-family-pkg-arch> <distro-family-pkg-fedora> ...
# Returns 0 on success, 1 if no package known or install failed.
pkg_present() {
	# $1 binary name (preferred) or 'pacman:pkgname' / 'dnf:pkgname'
	case "$1" in
		pacman:*) command -v pacman >/dev/null && pacman -Qi "${1#pacman:}" >/dev/null 2>&1 ;;
		dnf:*)    command -v rpm    >/dev/null && rpm -q "${1#dnf:}" >/dev/null 2>&1 ;;
		*)        command -v "$1" >/dev/null 2>&1 ;;
	esac
}

# Try to install a package. Args: arch_pkg, fedora_pkg. Use "-" to mark "n/a".
pkg_try_install() {
	local arch_pkg=$1 fedora_pkg=$2
	case "$DISTRO_FAMILY" in
		arch)
			[ "$arch_pkg" = - ] && return 1
			run sudo pacman -S --needed --noconfirm -- "$arch_pkg" ;;
		fedora)
			[ "$fedora_pkg" = - ] && return 1
			run sudo dnf install -y -- "$fedora_pkg" ;;
		*) return 1 ;;
	esac
}

# ---------------------------------------------------------------------------
# Fix registry
# ---------------------------------------------------------------------------
#
# For each fix:
#   FIX_DESC[key]       — human description
#   FIX_DEFAULT[key]    — default value when prompted (true/false/A/B/none)
#   FIX_APPLICABLE[key] — function returning 0 if the fix applies on this host
#   FIX_PREVIEW[key]    — function printing the paths+contents touched (-vv)
#   FIX_APPLY[key]      — function applying the fix; receives the chosen value
#
# Decisions are stored in CHOICES[key].

declare -A FIX_DESC FIX_DEFAULT FIX_NOTE
declare -a FIX_ORDER
declare -A CHOICES

reg() {
	# reg key "desc" default
	FIX_ORDER+=("$1")
	FIX_DESC[$1]=$2
	FIX_DEFAULT[$1]=$3
}

# --- audio.volume.keys -----------------------------------------------------

reg audio.volume.keys \
	"Install libinput quirk so volume keys work with the keyboard detached" \
	true

applies_audio_volume_keys() {
	if libinput_has_v3_quirks; then
		FIX_NOTE[audio.volume.keys]="libinput >= 1.26.2 already ships V3 quirks; skipping."
		return 1
	fi
	return 0
}

preview_audio_volume_keys() {
	cat <<-'EOF'
		--- /etc/libinput/local-overrides.quirks ---
		[Minisforum V3 volume keys]
		MatchName=AT Translated Set 2 keyboard
		MatchDMIModalias=dmi:*svnMicroComputer(HK)TechLimited:pnV3:*
		ModelTabletModeNoSuspend=1
	EOF
}

apply_audio_volume_keys() {
	preview_audio_volume_keys | sed -n '/^\[Minisforum/,$p' \
		| install_file /etc/libinput/local-overrides.quirks
}

# --- audio.volume.workaround (A | B | none) --------------------------------

reg audio.volume.workaround \
	"Global volume control workaround (A=wireplumber soft-mixer, B=alsa-card-profile)" \
	A

applies_audio_volume_workaround() { return 0; }

preview_audio_volume_workaround() {
	local choice=${CHOICES[audio.volume.workaround]:-A}
	case "$choice" in
		A)
			echo "--- ~/.config/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf ---"
			cat "${REPO_ROOT}/scripts/linux/audio/alsa-soft-mixer.conf"
			echo
			echo "[prereq] alsa-firmware will be installed if missing."
			;;
		B)
			cat <<-'EOF'
				--- /usr/share/alsa-card-profile/mixer/paths/analog-output.conf.common ---
				(insert before [Element PCM]:)
				[Element Master]
				switch = mute
				volume = ignore

				--- /usr/share/alsa-card-profile/mixer/paths/analog-output-headphones.conf ---
				(replace [Element Master] block with:)
				[Element Master]
				switch = mute
				volume = ignore
				override-map.1 = all
				override-map.2 = all-left,all-right
			EOF
			;;
		none) echo "(no audio volume workaround will be applied)" ;;
	esac
}

ensure_alsa_firmware() {
	pkg_present pacman:alsa-firmware && return 0
	pkg_present dnf:alsa-firmware && return 0
	command -v alsactl >/dev/null 2>&1 && [ "$DISTRO_FAMILY" = generic ] && return 0
	log "[prereq] installing alsa-firmware"
	pkg_try_install alsa-firmware alsa-firmware || {
		warn "could not auto-install alsa-firmware on ${DISTRO_FAMILY}; install it manually."
	}
}

apply_audio_volume_workaround() {
	local choice=$1
	case "$choice" in
		A)
			ensure_alsa_firmware
			local dest="${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf"
			install_file "$dest" < "${REPO_ROOT}/scripts/linux/audio/alsa-soft-mixer.conf"
			[ "$DRY_RUN" -eq 0 ] && run systemctl --user restart wireplumber || true
			;;
		B)
			local f1=/usr/share/alsa-card-profile/mixer/paths/analog-output.conf.common
			local f2=/usr/share/alsa-card-profile/mixer/paths/analog-output-headphones.conf
			if [ ! -f "$f1" ] || [ ! -f "$f2" ]; then
				err "alsa-card-profile files not present; install alsa-card-profile first."
				return 1
			fi
			# f1: insert block before [Element PCM] if not already there.
			if ! grep -q '^\[Element Master\]' "$f1"; then
				local tmp; tmp=$(mktemp)
				awk 'BEGIN{ins=0}
					/^\[Element PCM\]/ && !ins {
						print "[Element Master]"
						print "switch = mute"
						print "volume = ignore"
						print ""
						ins=1
					}
					{print}' "$f1" > "$tmp"
				if [ "$DRY_RUN" -eq 1 ]; then
					printf '+ patch %s (insert [Element Master] before [Element PCM])\n' "$f1" >&2
				else
					sudo cp -- "$tmp" "$f1"
				fi
				rm -f -- "$tmp"
			else
				vlog "$f1 already contains [Element Master]; skipping"
			fi
			# f2: rewrite [Element Master] block.
			local tmp2; tmp2=$(mktemp)
			awk '
				BEGIN{inblk=0}
				/^\[Element Master\]/ {
					print "[Element Master]"
					print "switch = mute"
					print "volume = ignore"
					print "override-map.1 = all"
					print "override-map.2 = all-left,all-right"
					inblk=1; next
				}
				/^\[/ && inblk { inblk=0 }
				!inblk {print}
			' "$f2" > "$tmp2"
			if [ "$DRY_RUN" -eq 1 ]; then
				printf '+ patch %s (rewrite [Element Master])\n' "$f2" >&2
			else
				sudo cp -- "$tmp2" "$f2"
			fi
			rm -f -- "$tmp2"
			[ "$DRY_RUN" -eq 0 ] && run systemctl --user restart wireplumber || true
			;;
		none) ;;
	esac
}

# --- audio.suspension ------------------------------------------------------

reg audio.suspension \
	"Disable audio session suspension (fixes headphone port dropping)" \
	true

applies_audio_suspension() { return 0; }

preview_audio_suspension() {
	echo "--- ~/.config/wireplumber/wireplumber.conf.d/alsa-disable-suspension.conf ---"
	cat "${REPO_ROOT}/scripts/linux/audio/alsa-disable-suspension.conf"
}

apply_audio_suspension() {
	local dest="${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d/alsa-disable-suspension.conf"
	install_file "$dest" < "${REPO_ROOT}/scripts/linux/audio/alsa-disable-suspension.conf"
}

# --- camera.howdy ----------------------------------------------------------

reg camera.howdy \
	"Configure howdy (IR face unlock) device_path" \
	true

applies_camera_howdy() {
	# Howdy is non-trivial on non-Fedora; we still offer config if howdy is
	# present anywhere.
	return 0
}

# Detect IR camera by finding a /dev/video* whose v4l2 formats are monochrome
# (GREY / Y8 / Y16) only. Echoes the device path on success.
detect_ir_camera() {
	command -v v4l2-ctl >/dev/null 2>&1 || { err "v4l2-ctl not found (install v4l-utils)"; return 1; }
	local dev candidates=()
	for dev in /dev/video*; do
		[ -c "$dev" ] || continue
		local fmts
		fmts=$(v4l2-ctl --device "$dev" --list-formats 2>/dev/null) || continue
		if printf '%s' "$fmts" | grep -qE "'(GREY|Y8 |Y16 )'" \
			&& ! printf '%s' "$fmts" | grep -qE "'(YUYV|MJPG|NV12|NV21|RGB)"; then
			candidates+=("$dev")
		fi
	done
	if [ "${#candidates[@]}" -eq 1 ]; then
		printf '%s\n' "${candidates[0]}"
		return 0
	elif [ "${#candidates[@]}" -gt 1 ]; then
		err "multiple IR-like cameras detected: ${candidates[*]} — disambiguate manually."
		return 1
	else
		err "no IR camera detected via v4l2-ctl."
		return 1
	fi
}

preview_camera_howdy() {
	local ir
	if ir=$(detect_ir_camera 2>/dev/null); then
		echo "--- /etc/howdy/config.ini ---"
		echo "(edit: device_path = ${ir})"
	else
		echo "(IR camera auto-detection will be attempted at apply time; this fix"
		echo " will error out if detection fails.)"
	fi
}

ensure_howdy() {
	command -v howdy >/dev/null 2>&1 && return 0
	log "[prereq] installing howdy"
	case "$DISTRO_FAMILY" in
		fedora)
			run sudo dnf copr enable -y principis/howdy-beta \
				&& run sudo dnf install -y howdy
			;;
		arch)
			warn "howdy is AUR-only on Arch; install it manually (e.g. 'paru -S howdy'), then re-run."
			return 1
			;;
		*)
			warn "no automatic howdy install available on ${DISTRO_FAMILY}; install manually."
			return 1
			;;
	esac
}

apply_camera_howdy() {
	ensure_howdy || return 1
	local ir
	ir=$(detect_ir_camera) || return 1
	local cfg=/etc/howdy/config.ini
	if [ ! -f "$cfg" ]; then
		err "$cfg not found after howdy install."
		return 1
	fi
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '+ set device_path = %s in %s\n' "$ir" "$cfg" >&2
		return 0
	fi
	sudo sed -i -E "s|^[[:space:]]*device_path[[:space:]]*=.*|device_path = ${ir}|" "$cfg"
	vlog "set device_path = ${ir} in ${cfg}"
}

# --- input.rotation.kde ----------------------------------------------------

reg input.rotation.kde \
	"Install KDE rotate-button toggle script to ~/.local/bin" \
	true

applies_input_rotation_kde() {
	[ "$IS_KDE" -eq 1 ] || { FIX_NOTE[input.rotation.kde]="not running KDE; skipping."; return 1; }
	return 0
}

preview_input_rotation_kde() {
	echo "--- ${HOME}/.local/bin/v3-rotate.sh ---"
	cat "${REPO_ROOT}/scripts/linux/input/rotateButton.sh"
	echo
	echo "(bind this command to your rotate hardware button via KDE shortcuts.)"
}

apply_input_rotation_kde() {
	install_file "${HOME}/.local/bin/v3-rotate.sh" \
		< "${REPO_ROOT}/scripts/linux/input/rotateButton.sh"
	[ "$DRY_RUN" -eq 0 ] && chmod +x "${HOME}/.local/bin/v3-rotate.sh" || true
	log "Bind ~/.local/bin/v3-rotate.sh to your rotate button via System Settings > Shortcuts."
}

# --- input.copilot.remap ---------------------------------------------------

reg input.copilot.remap \
	"Drop an input-remapper preset that turns the Copilot key into KEY_COMPOSE" \
	false

applies_input_copilot_remap() { return 0; }

ensure_input_remapper() {
	command -v input-remapper-control >/dev/null 2>&1 && return 0
	log "[prereq] installing input-remapper"
	pkg_try_install input-remapper input-remapper || {
		warn "could not auto-install input-remapper on ${DISTRO_FAMILY}; install manually."
		return 1
	}
}

copilot_preset_json() {
	cat <<-'EOF'
		{
		  "mapping": [
		    {
		      "input_combination": [
		        {"type": 1, "code": 125, "origin_hash": ""},
		        {"type": 1, "code": 42,  "origin_hash": ""},
		        {"type": 1, "code": 530, "origin_hash": ""}
		      ],
		      "target_uinput": "keyboard",
		      "output_symbol": "KEY_COMPOSE"
		    }
		  ]
		}
	EOF
}

preview_input_copilot_remap() {
	echo "--- ${HOME}/.config/input-remapper-2/presets/AT Translated Set 2 keyboard/v3se-copilot.json ---"
	copilot_preset_json
	echo
	echo "(activate the preset in input-remapper-gtk after install.)"
}

apply_input_copilot_remap() {
	ensure_input_remapper || return 1
	local dir="${HOME}/.config/input-remapper-2/presets/AT Translated Set 2 keyboard"
	local dest="${dir}/v3se-copilot.json"
	copilot_preset_json | install_file "$dest"
	log "Open input-remapper-gtk and activate preset 'v3se-copilot' to enable."
}

# --- power.ryzenadj --------------------------------------------------------

reg power.ryzenadj \
	"Install ryzenadj-driven TDP/refresh-rate profile switcher (KDE)" \
	false

applies_power_ryzenadj() {
	[ "$IS_KDE" -eq 1 ] || { FIX_NOTE[power.ryzenadj]="not running KDE; skipping."; return 1; }
	return 0
}

ensure_ryzenadj() {
	command -v ryzenadj >/dev/null 2>&1 && return 0
	log "[prereq] installing ryzenadj"
	pkg_try_install ryzenadj ryzenadj || {
		warn "could not auto-install ryzenadj on ${DISTRO_FAMILY}; install manually (AUR on Arch)."
		return 1
	}
}

preview_power_ryzenadj() {
	echo "--- ${HOME}/.local/bin/v3se-power-adjust ---"
	echo "(copy of scripts/linux/power/ryzenadj_power_profiles/power_adjust.sh, RYZENADJ patched)"
	echo
	echo "--- ${HOME}/.config/systemd/user/v3_power_profiles.service ---"
	echo "(ExecStart=${HOME}/.local/bin/v3se-power-adjust)"
	echo
	echo "--- /etc/sudoers.d/v3se-ryzenadj ---"
	echo "ALL ALL=NOPASSWD: \$(command -v ryzenadj)"
	echo
	echo "Then: systemctl --user enable --now v3_power_profiles.service"
}

apply_power_ryzenadj() {
	ensure_ryzenadj || return 1
	local ryzenadj_bin
	ryzenadj_bin=$(command -v ryzenadj)

	# 1. sudoers drop-in (passwordless ryzenadj)
	if [ "$DRY_RUN" -eq 1 ]; then
		printf '+ write sudoers drop-in /etc/sudoers.d/v3se-ryzenadj\n' >&2
	else
		printf 'ALL ALL=NOPASSWD: %s\n' "$ryzenadj_bin" \
			| sudo tee /etc/sudoers.d/v3se-ryzenadj >/dev/null
		sudo chmod 0440 /etc/sudoers.d/v3se-ryzenadj
	fi

	# 2. power_adjust.sh with the binary path baked in.
	local script_src="${REPO_ROOT}/scripts/linux/power/ryzenadj_power_profiles/power_adjust.sh"
	local script_dest="${HOME}/.local/bin/v3se-power-adjust"
	sed -E "s|^RYZENADJ=.*|RYZENADJ=\"${ryzenadj_bin}\"|" "$script_src" \
		| install_file "$script_dest"
	[ "$DRY_RUN" -eq 0 ] && chmod +x "$script_dest" || true

	# 3. user systemd unit
	local unit_dest="${HOME}/.config/systemd/user/v3_power_profiles.service"
	sed -E "s|^ExecStart=.*|ExecStart=${script_dest}|" \
		"${REPO_ROOT}/scripts/linux/power/ryzenadj_power_profiles/v3_power_profiles.service" \
		| install_file "$unit_dest"

	if [ "$DRY_RUN" -eq 0 ]; then
		systemctl --user daemon-reload
		systemctl --user enable --now v3_power_profiles.service
	fi
}

# ---------------------------------------------------------------------------
# Decision phase
# ---------------------------------------------------------------------------

is_bool_fix() {
	case "$1" in
		audio.volume.workaround) return 1 ;;
		*) return 0 ;;
	esac
}

normalise_bool() {
	case "${1,,}" in
		1|true|t|yes|y|on)  echo true ;;
		0|false|f|no|n|off) echo false ;;
		*) return 1 ;;
	esac
}

normalise_workaround() {
	case "${1,,}" in
		a) echo A ;;
		b) echo B ;;
		none|off|false|0|no) echo none ;;
		*) return 1 ;;
	esac
}

decide_fix() {
	local key=$1 default=${FIX_DEFAULT[$key]} chosen ovr

	# Override from CLI?
	if [ "${OVERRIDES[$key]+x}" = x ]; then
		ovr=${OVERRIDES[$key]}
		if is_bool_fix "$key"; then
			chosen=$(normalise_bool "$ovr") || { err "invalid value for $key: $ovr"; exit 2; }
		else
			chosen=$(normalise_workaround "$ovr") || { err "invalid value for $key: $ovr"; exit 2; }
		fi
		CHOICES[$key]=$chosen
		return
	fi

	# --all: take the default.
	if [ "$ALL" -eq 1 ]; then
		CHOICES[$key]=$default
		return
	fi

	# Interactive prompt.
	if is_bool_fix "$key"; then
		if ask_yn "Apply [${key}] ${FIX_DESC[$key]}?" "$([ "$default" = true ] && echo y || echo n)"; then
			CHOICES[$key]=true
		else
			CHOICES[$key]=false
		fi
	else
		# audio.volume.workaround
		log ""
		log "[${key}] ${FIX_DESC[$key]}"
		log "  A) wireplumber soft-mixer drop-in (default)"
		log "  B) edit /usr/share/alsa-card-profile/mixer/paths/*"
		log "  N) none"
		local ans
		while :; do
			printf 'Choose [A/b/n]: ' >&2
			read -r ans || ans=A
			ans=${ans:-A}
			chosen=$(normalise_workaround "$ans") && break
		done
		CHOICES[$key]=$chosen
	fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

log "Distro family: ${DISTRO_FAMILY} (${DISTRO_ID:-unknown}). KDE: $([ "$IS_KDE" -eq 1 ] && echo yes || echo no). Dry-run: $([ "$DRY_RUN" -eq 1 ] && echo yes || echo no)."
log ""

# Filter applicable fixes.
applicable=()
for key in "${FIX_ORDER[@]}"; do
	fn="applies_${key//./_}"
	if "$fn"; then
		applicable+=("$key")
	else
		vlog "skip [${key}]: ${FIX_NOTE[$key]:-not applicable}"
	fi
done

if [ "${#applicable[@]}" -eq 0 ]; then
	log "No applicable fixes for this host."
	exit 0
fi

# Decide each one.
for key in "${applicable[@]}"; do
	decide_fix "$key"
done

# Compute the set actually to be applied.
to_apply=()
for key in "${applicable[@]}"; do
	v=${CHOICES[$key]}
	case "$v" in
		false|none) continue ;;
	esac
	to_apply+=("$key")
done

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

log ""
log "========================================"
log " Fix application report"
log "========================================"
log "Distro family : ${DISTRO_FAMILY}"
log "KDE session   : $([ "$IS_KDE" -eq 1 ] && echo yes || echo no)"
log "Mode          : $([ "$DRY_RUN" -eq 1 ] && echo DRY-RUN || echo APPLY)"
log ""

if [ "${#to_apply[@]}" -eq 0 ]; then
	log "Nothing selected. Exiting."
	exit 0
fi

log "Fixes to apply:"
for key in "${to_apply[@]}"; do
	v=${CHOICES[$key]}
	log "  - ${key} = ${v}"
	log "      ${FIX_DESC[$key]}"
done

if [ "${VERBOSITY}" -ge 2 ]; then
	log ""
	log "Files / contents that will be written or edited:"
	for key in "${to_apply[@]}"; do
		log ""
		log "### ${key}"
		fn="preview_${key//./_}"
		"$fn" 2>&1 | sed 's/^/    /' >&2
	done
fi

log ""

if [ "$SKIP_FINAL" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
	if ! ask_yn "Proceed with applying the above?" n; then
		log "Aborted."
		exit 0
	fi
fi

# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------

rc=0
for key in "${to_apply[@]}"; do
	v=${CHOICES[$key]}
	fn="apply_${key//./_}"
	log ""
	log ">>> ${key} = ${v}"
	if "$fn" "$v"; then
		log "    ok."
	else
		err "    failed."
		rc=1
	fi
done

log ""
if [ "$DRY_RUN" -eq 1 ]; then
	log "Dry-run complete; no changes made."
else
	log "Done (rc=${rc}). Some fixes may require a reboot or re-login to take effect."
fi
exit "$rc"
