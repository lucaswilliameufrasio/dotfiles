#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

shell_name="${1:-}"
source_directory=$(cd "$(dirname "$0")" && pwd -P)
destination_directory="$HOME/.config/development-helpers"

case "$shell_name" in
  zsh)
    startup_file="${ZDOTDIR:-$HOME}/.zshrc"
    loader_line='[ ! -r "$HOME/.config/development-helpers/development.sh" ] || source "$HOME/.config/development-helpers/development.sh"'
    ;;
  bash)
    startup_file="$HOME/.bashrc"
    loader_line='[ ! -r "$HOME/.config/development-helpers/development.sh" ] || source "$HOME/.config/development-helpers/development.sh"'
    ;;
  fish)
    startup_file="$HOME/.config/fish/config.fish"
    loader_line='test ! -r "$HOME/.config/development-helpers/development.fish"; or source "$HOME/.config/development-helpers/development.fish"'
    ;;
  *)
    printf 'Usage: bash shell/install.sh <zsh|bash|fish>\n' >&2
    exit 1
    ;;
esac

backup_directory="$destination_directory/backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup_directory" "$(dirname "$startup_file")"

for helper_file in development.sh development.fish; do
  if [ -f "$destination_directory/$helper_file" ]; then
    cp -p "$destination_directory/$helper_file" "$backup_directory/$helper_file"
  fi
  cp "$source_directory/$helper_file" "$destination_directory/$helper_file"
done

if ! grep -Fqx "$loader_line" "$startup_file" 2>/dev/null; then
  if [ -f "$startup_file" ]; then
    cp -p "$startup_file" "$backup_directory/startup"
  fi
  printf '\n# Portable development helpers (managed by dotfiles shell/install.sh).\n%s\n' "$loader_line" >> "$startup_file"
fi

printf 'Installed development helpers for %s. Open a new shell to load them.\n' "$shell_name"
printf 'Previous files, if any, are preserved under ~/.config/development-helpers/backups/.\n'
