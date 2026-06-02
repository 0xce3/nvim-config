#!/usr/bin/env bash
set -euo pipefail

repo_url="${NVIM_CONFIG_REPO:-https://github.com/0xce3/nvim-config.git}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
dry_run=0
skip_packages=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--dry-run] [--skip-packages]

Installs Neovim, required helper tools, this Neovim config, and plugins.

Options:
  --dry-run        Print the planned actions without changing the system.
  --skip-packages  Do not install system packages.
  -h, --help       Show this help.
USAGE
}

log() {
  printf '%s\n' "$*"
}

run() {
  if [[ "$dry_run" -eq 1 ]]; then
    printf '  $'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

need_sudo() {
  [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1
}

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    run "$@"
  elif command -v sudo >/dev/null 2>&1; then
    run sudo "$@"
  else
    log "sudo is required to install packages on this host."
    exit 1
  fi
}

detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    printf 'apt\n'
  elif command -v dnf >/dev/null 2>&1; then
    printf 'dnf\n'
  elif command -v pacman >/dev/null 2>&1; then
    printf 'pacman\n'
  elif command -v apk >/dev/null 2>&1; then
    printf 'apk\n'
  elif command -v brew >/dev/null 2>&1; then
    printf 'brew\n'
  else
    printf 'unknown\n'
  fi
}

install_packages() {
  local manager="$1"

  case "$manager" in
    apt)
      as_root apt-get update
      as_root apt-get install -y \
        neovim git curl ripgrep fd-find build-essential cmake ninja-build \
        clangd python3 python3-pip nodejs npm gh
      ;;
    dnf)
      as_root dnf install -y \
        neovim git curl ripgrep fd-find gcc gcc-c++ make cmake ninja-build \
        clang-tools-extra python3 python3-pip nodejs npm gh
      ;;
    pacman)
      as_root pacman -Sy --needed --noconfirm \
        neovim git curl ripgrep fd base-devel cmake ninja clang python python-pip nodejs npm github-cli
      ;;
    apk)
      as_root apk add --no-cache \
        neovim git curl ripgrep fd build-base cmake ninja clang-extra-tools \
        python3 py3-pip nodejs npm github-cli
      ;;
    brew)
      run brew install neovim git curl ripgrep fd cmake ninja llvm python node gh
      ;;
    *)
      log "No supported package manager found. Install Neovim, git, ripgrep, fd, clangd, Python, Node.js, npm, cmake, and ninja manually."
      exit 1
      ;;
  esac
}

backup_existing_config() {
  [[ -e "$config_dir" ]] || return 0

  if [[ -d "$config_dir/.git" ]]; then
    log "Existing Neovim config is a git repository; updating it in place."
    run git -C "$config_dir" remote set-url origin "$repo_url"
    run git -C "$config_dir" pull --ff-only
    return 0
  fi

  local backup_dir="${config_dir}.backup.$(date +%Y%m%d%H%M%S)"
  log "Backing up existing Neovim config to $backup_dir"
  run mv "$config_dir" "$backup_dir"
}

install_config() {
  if [[ -d "$config_dir/.git" ]]; then
    return 0
  fi

  run mkdir -p "$(dirname "$config_dir")"
  run git clone "$repo_url" "$config_dir"
}

install_python_tool() {
  local package="$1"

  if [[ "$dry_run" -eq 1 ]]; then
    run python3 -m pip install --user "$package"
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    log "python3 not found; skipping $package installation."
    return 0
  fi

  if python3 -m pip install --user "$package"; then
    return 0
  fi

  python3 -m pip install --user --break-system-packages "$package"
}

install_language_tools() {
  if command -v npm >/dev/null 2>&1; then
    run npm install -g pyright
  else
    log "npm not found; skipping pyright installation."
  fi

  install_python_tool ruff
}

sync_plugins() {
  run nvim --headless '+Lazy! sync' '+qa'
}

check_neovim_version() {
  if [[ "$dry_run" -eq 1 ]]; then
    log "Neovim version check: requires 0.11 or newer."
    return 0
  fi

  if ! command -v nvim >/dev/null 2>&1; then
    log "nvim was not found after package installation."
    exit 1
  fi

  local version
  version="$(nvim --version | awk 'NR == 1 { print $2 }' | sed 's/^v//')"
  if ! printf '0.11.0\n%s\n' "$version" | sort -V -C; then
    log "Neovim $version is too old. Install Neovim 0.11 or newer, then rerun this script with --skip-packages."
    exit 1
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=1
        ;;
      --skip-packages)
        skip_packages=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        exit 2
        ;;
    esac
    shift
  done

  local manager
  manager="$(detect_package_manager)"

  [[ "$dry_run" -eq 1 ]] && log "Dry run: no changes will be made."
  log "Neovim config repository: $repo_url"
  log "Config directory: $config_dir"
  log "Package manager: $manager"

  if [[ "$skip_packages" -eq 0 ]]; then
    install_packages "$manager"
  else
    log "Skipping system package installation."
  fi

  check_neovim_version
  backup_existing_config
  install_config
  install_language_tools

  log "Lazy sync: installing or updating Neovim plugins."
  sync_plugins

  log "Neovim setup complete."
}

main "$@"
