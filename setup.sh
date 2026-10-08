#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
DRY_RUN=false

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [--dry-run] [--help]

Install the command-line tools used by these dotfiles with the system's
native package manager. Supported systems: macOS (Homebrew), Arch Linux,
Debian, and Ubuntu.

Options:
  --dry-run  Print the commands without installing anything.
  --help     Show this help.

The script does not change your default shell or overwrite configuration files.
EOF
}

log() {
  printf '%s\n' "$*"
}

error() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
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
  if ! command_exists "$1"; then
    error "Required command '$1' was not found."
  fi
}

detect_linux_distribution() {
  if [[ ! -r /etc/os-release ]]; then
    error "Cannot identify this Linux distribution: /etc/os-release is unavailable."
  fi

  # shellcheck disable=SC1091
  . /etc/os-release

  case "${ID:-}" in
    arch)
      printf 'arch\n'
      ;;
    debian)
      printf 'debian\n'
      ;;
    ubuntu)
      printf 'ubuntu\n'
      ;;
    *)
      case " ${ID_LIKE:-} " in
        *" arch "*)
          printf 'arch\n'
          ;;
        *" debian "*)
          printf 'debian\n'
          ;;
        *)
          error "Unsupported Linux distribution '${ID:-unknown}'. Supported: Arch, Debian, Ubuntu."
          ;;
      esac
      ;;
  esac
}

detect_platform() {
  case "$(uname -s)" in
    Darwin)
      printf 'macos\n'
      ;;
    Linux)
      detect_linux_distribution
      ;;
    *)
      error "Unsupported operating system '$(uname -s)'."
      ;;
  esac
}

install_brew_packages() {
  require_command brew

  local packages=(fish helix yazi fd ripgrep fzf jq ffmpeg poppler)
  run brew install "${packages[@]}"
}

install_arch_packages() {
  require_command pacman
  require_command sudo

  local packages=(fish helix yazi fd ripgrep fzf jq ffmpeg poppler)
  run sudo pacman -S --needed "${packages[@]}"
}

install_apt_packages() {
  require_command apt-get
  require_command apt-cache
  require_command sudo

  if [[ "${DRY_RUN}" != true ]]; then
    run sudo apt-get update
  else
    log "Note: package availability in dry-run mode depends on the local APT cache."
  fi

  local candidates=(fish helix yazi fd-find ripgrep fzf jq ffmpeg poppler-utils)
  local available=()
  local package

  for package in "${candidates[@]}"; do
    if apt-cache show "${package}" >/dev/null 2>&1; then
      available+=("${package}")
    else
      log "Skipping '${package}': it is not available in the configured APT sources."
    fi
  done

  if [[ "${#available[@]}" -eq 0 ]]; then
    error "No supported packages were found in the configured APT sources."
  fi

  run sudo apt-get install --no-install-recommends "${available[@]}"
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
      *)
        error "Unknown option '$1'. Run '${SCRIPT_NAME} --help' for usage."
        ;;
    esac

    shift
  done
}

main() {
  parse_arguments "$@"

  local platform
  platform="$(detect_platform)"
  log "Detected platform: ${platform}"

  case "${platform}" in
    macos)
      install_brew_packages
      ;;
    arch)
      install_arch_packages
      ;;
    debian|ubuntu)
      install_apt_packages
      ;;
    *)
      error "Internal error: unhandled platform '${platform}'."
      ;;
  esac

  log "Package setup complete. Existing user configuration was left untouched."
}

main "$@"
