#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
DRY_RUN=false
DEVICE_QUERY="PBS45BT"

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--dry-run] [--help] [device]

Clear the BlueZ codec cache for one paired speaker and reconnect it.
The device argument is a paired alias or a Bluetooth address.
The default alias is PBS45BT.

This is the workaround for BlueZ 5.87, which fails to reload cached A2DP
endpoints and then retries the connection about every 14 seconds.
The password prompt comes from sudo in this terminal. Do not paste it
into a chat.

Options:
  --dry-run  Show the commands without disconnecting or deleting anything.
  --help     Show this help.
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
  local matches

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

find_adapter_mac() {
  local mac

  mac="$(bluetoothctl list | awk '$1 == "Controller" { print $2; exit }')"
  if ! is_mac "${mac}"; then
    error "Could not read the Bluetooth adapter address from 'bluetoothctl list'."
  fi

  printf '%s\n' "${mac}"
}

wait_until_powered() {
  local attempt

  if [[ "${DRY_RUN}" == true ]]; then
    log "+ wait until bluetoothctl show reports Powered: yes"
    return 0
  fi

  for attempt in $(seq 1 30); do
    if bluetoothctl show | grep -q 'Powered: yes'; then
      return 0
    fi
    sleep 0.5
  done

  error "Bluetooth adapter did not return after restart."
}

main() {
  local device adapter cache

  parse_arguments "$@"
  require_command bluetoothctl
  require_command sudo
  require_command systemctl
  require_command awk

  device="$(find_device_mac "${DEVICE_QUERY}")"
  adapter="$(find_adapter_mac)"

  if ! is_mac "${device}"; then
    error "Resolved device address '${device}' is not a Bluetooth address."
  fi

  cache="/var/lib/bluetooth/${adapter}/cache/${device}"
  case "${cache}" in
    /var/lib/bluetooth/"${adapter}"/cache/"${device}")
      ;;
    *)
      error "Refusing to touch unexpected cache path '${cache}'."
      ;;
  esac

  log "Adapter ${adapter}"
  log "Device  ${device}"
  log "Cache   ${cache}"
  log "sudo will ask for your password in this terminal."

  run bluetoothctl disconnect "${device}"
  run sudo rm -f -- "${cache}"
  run sudo systemctl restart bluetooth
  wait_until_powered
  run bluetoothctl connect "${device}"

  if [[ "${DRY_RUN}" == true ]]; then
    log "Dry run complete. The speaker stayed connected and the cache was not removed."
    return 0
  fi

  log "Reconnected ${device}. Check: journalctl -u bluetooth --since '1 min ago' | grep -E 'LastUsed|reconnect_timeout'"
}

main "$@"
