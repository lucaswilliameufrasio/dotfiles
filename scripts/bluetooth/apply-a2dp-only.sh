#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
DRY_RUN=false
DEVICE_QUERY="PBS45BT"

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--dry-run] [--help] [device]

Stop WirePlumber from opening the Hands-Free profile that makes a speaker
such as PBS45BT drop and reconnect. The device argument is a paired alias
or a Bluetooth address. The default alias is PBS45BT.

Options:
  --dry-run  Show the config and commands without changing anything.
  --help     Show this help.

Writes ~/.config/wireplumber/wireplumber.conf.d/51-a2dp-only.conf and
removes the saved headset profile for that card. HSP/HFP stay disabled for
every Bluetooth device until that file is deleted and WirePlumber restarts.
EOF
}

log() {
  printf '%s\n' "$*"
}

error() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

run() {
  if [[ "${DRY_RUN}" == true ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "Required command '$1' was not found."
  fi
}

is_mac() {
  [[ "$1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]
}

parse_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        error "Unknown option '$1'. Run '${SCRIPT_NAME} --help' for usage."
        ;;
      *)
        break
        ;;
    esac
    shift
  done

  if [[ "$#" -gt 1 ]]; then
    error "Pass one device alias or address."
  fi

  if [[ "$#" -eq 1 ]]; then
    DEVICE_QUERY="$1"
  fi
}

find_device_mac() {
  local query="$1"
  local line mac alias matches

  if is_mac "${query}"; then
    printf '%s\n' "${query^^}"
    return 0
  fi

  matches="$(bluetoothctl devices | awk -v wanted="${query}" '
    $1 == "Device" && NF >= 3 {
      mac = $2
      alias = substr($0, index($0, $2) + length($2) + 1)
      if (alias == wanted) {
        print mac
      }
    }
  ')"

  if [[ -z "${matches}" ]]; then
    error "No paired device is named '${query}'."
  fi

  if [[ "$(printf '%s\n' "${matches}" | wc -l)" -ne 1 ]]; then
    error "More than one paired device is named '${query}'."
  fi

  printf '%s\n' "${matches}"
}

card_name_for() {
  local mac="$1"
  printf 'bluez_card.%s\n' "${mac//:/_}"
}

config_dir() {
  printf '%s/wireplumber/wireplumber.conf.d\n' "${XDG_CONFIG_HOME:-${HOME}/.config}"
}

state_file() {
  printf '%s/wireplumber/bluetooth-autoswitch\n' "${XDG_STATE_HOME:-${HOME}/.local/state}"
}

write_config() {
  local destination="$1"
  local mac="$2"
  local card="$3"
  local temporary

  temporary="$(mktemp)"
  cat > "${temporary}" <<EOF
monitor.bluez.properties = {
  ## Sem hsp/hfp o BlueZ deixa de abrir o Hands-Free Voice gateway.
  ## O microfone dos outros fones Bluetooth fica desligado até apagar este arquivo.
  bluez5.roles = [ a2dp_sink a2dp_source bap_sink bap_source ]
}

monitor.bluez.rules = [
  {
    matches = [
      {
        device.name = "${card}"
      }
    ]
    actions = {
      update-props = {
        ## ${mac} fica só no perfil de música.
        bluez5.auto-connect = [ a2dp_sink ]
        bluez5.headset-roles = [ ]
      }
    }
  }
]
EOF

  if [[ "${DRY_RUN}" == true ]]; then
    log "Would write ${destination}:"
    cat "${temporary}"
    rm -f "${temporary}"
    return 0
  fi

  mkdir -p "$(dirname "${destination}")"
  mv "${temporary}" "${destination}"
  log "Wrote ${destination}"
}

forget_saved_headset_profile() {
  local path="$1"
  local card="$2"
  local temporary

  if [[ ! -f "${path}" ]]; then
    log "No saved headset profile at ${path}"
    return 0
  fi

  if [[ "${DRY_RUN}" == true ]]; then
    log "Would remove saved headset profile lines for ${card} from ${path}"
    return 0
  fi

  temporary="$(mktemp)"
  awk -v card="${card}" 'index($0, card) == 0 { print }' "${path}" > "${temporary}"
  mv "${temporary}" "${path}"
  log "Removed saved headset profile for ${card}"
}

main() {
  local mac card config_path previous_config state

  parse_arguments "$@"
  require_command bluetoothctl
  require_command systemctl
  require_command awk

  mac="$(find_device_mac "${DEVICE_QUERY}")"
  if ! is_mac "${mac}"; then
    error "Resolved device address '${mac}' is not a Bluetooth address."
  fi

  card="$(card_name_for "${mac}")"
  config_path="$(config_dir)/51-a2dp-only.conf"
  previous_config="$(config_dir)/51-pbs45bt-a2dp.conf"
  state="$(state_file)"

  log "Device ${mac} (${card})"

  if [[ "${DRY_RUN}" != true ]]; then
    run systemctl --user stop wireplumber
  else
    log "+ systemctl --user stop wireplumber"
  fi

  write_config "${config_path}" "${mac}" "${card}"

  if [[ -e "${previous_config}" && "${previous_config}" != "${config_path}" ]]; then
    run rm -f "${previous_config}"
  fi

  forget_saved_headset_profile "${state}" "${card}"

  if [[ "${DRY_RUN}" != true ]]; then
    run systemctl --user start wireplumber
  else
    log "+ systemctl --user start wireplumber"
  fi

  if [[ "${DRY_RUN}" == true ]]; then
    log "Dry run complete. No files were changed."
    return 0
  fi

  log "A2DP-only policy applied. Other Bluetooth headset microphones stay off until ${config_path} is removed."
}

main "$@"
