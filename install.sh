#!/usr/bin/env bash
set -euo pipefail

repo_url="${NVIM_CONFIG_REPO:-https://github.com/0xce3/nvim-config.git}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
dry_run=0
skip_packages=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--dry-run] [--skip-packages]

Installs Neovim (host), helper tools, this Neovim config, and plugins.

This script installs only what is needed on the **host** (WSL/Linux/macOS):
  nvim, git, ripgrep, fd, python, node, gh, lazygit

The **dev toolchain** (clangd, cmake, gcc, ninja, …) lives inside your
devcontainers – use :DevcontainerReopen or :DevcontainerUp in nvim.

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
      as_root apt-get update || true

      # Neovim 0.11+ needed – Ubuntu repositories ship ancient versions.
      # Always add the PPA (it is idempotent) so that apt-get picks up the
      # latest Neovim build regardless of what is already installed.
      as_root apt-get install -y software-properties-common || true
      as_root add-apt-repository -y ppa:neovim-ppa/unstable 2>/dev/null || true
      as_root apt-get update || true

      # Host packages: only what nvim needs on WSL.
      # Toolchain (clangd, cmake, gcc, ninja, …) lives in the devcontainer.
      as_root apt-get install -y \
        neovim git curl ripgrep fd-find \
        python3 python3-pip nodejs gh || true
      if ! command -v npm >/dev/null 2>&1; then
        as_root apt-get install -y npm || true
      fi
      install_lazygit_github
      install_fzf_github
      ;;
    dnf)
      as_root dnf install -y \
        neovim git curl ripgrep fd-find python3 python3-pip nodejs npm gh
      install_lazygit_github
      install_fzf_github
      ;;
    pacman)
      as_root pacman -Sy --needed --noconfirm \
        neovim git curl ripgrep fd python python-pip nodejs npm github-cli lazygit
      ;;
    apk)
      as_root apk add --no-cache \
        neovim git curl ripgrep fd python3 py3-pip nodejs npm github-cli lazygit
      ;;
    brew)
      run brew install neovim git curl ripgrep fd python node gh lazygit fzf
      ;;
    *)
      log "No supported package manager found. Install Neovim, git, ripgrep, fd, clangd, clang-format, Python, Node.js, npm, cmake, and ninja manually."
      exit 1
      ;;
  esac
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
    run npm install -g pyright || true
  else
    log "npm not found; skipping pyright installation."
  fi

  install_python_tool ruff || true
}

sync_plugins() {
  run nvim --headless '+Lazy! sync' '+qa' || {
    log "Lazy sync failed. Run ':Lazy sync' manually after opening nvim."
    return 0
  }
}

install_nvim_dev_launcher() {
  local target_dir="$HOME/.local/bin"
  run mkdir -p "$target_dir"
  run install -m 0755 "$config_dir/bin/nvim-dev" "$target_dir/nvim-dev"
  log "nvim-dev installed to $target_dir/nvim-dev"
}

install_lazygit_github() {
  if [[ "$dry_run" -eq 1 ]]; then
    log "lazygit: would download latest release from GitHub and install to /usr/local/bin"
    return 0
  fi

  if command -v lazygit >/dev/null 2>&1; then
    return 0
  fi

  local tmp arch url
  tmp="$(mktemp -d)"
  arch="$(uname -m)"
  case "$arch" in
    x86_64)  arch="x86_64" ;;
    aarch64) arch="arm64"  ;;
    *)       log "Unsupported architecture: $arch"; return 1 ;;
  esac

  url="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
    | grep "browser_download_url.*Linux_${arch}.tar.gz" \
    | cut -d '"' -f 4)"

  [[ -n "$url" ]] || { log "Could not determine lazygit download URL"; return 1; }

  log "Downloading lazygit from $url"
  curl -fsSL "$url" -o "$tmp/lazygit.tar.gz"
  tar -xzf "$tmp/lazygit.tar.gz" -C "$tmp"
  as_root install "$tmp/lazygit" /usr/local/bin/lazygit
  rm -rf "$tmp"
  log "lazygit installed to /usr/local/bin"
}

install_fzf_github() {
  if [[ "$dry_run" -eq 1 ]]; then
    log "fzf: would download latest release from GitHub and install to /usr/local/bin"
    return 0
  fi

  # Only install if system version is too old (< 0.36).
  local current
  current="$(fzf --version 2>/dev/null | awk '{print $1}' || true)"
  if printf '0.36.0\n%s\n' "${current:-0.0.0}" | sort -V -C 2>/dev/null; then
    return 0
  fi

  local tmp arch url
  tmp="$(mktemp -d)"
  arch="$(uname -m)"
  case "$arch" in
    x86_64)  arch="amd64" ;;
    aarch64) arch="arm64"  ;;
    *)       log "Unsupported architecture: $arch"; return 1 ;;
  esac

  url="$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest \
    | grep "browser_download_url.*linux_${arch}.tar.gz" \
    | cut -d '"' -f 4)"

  [[ -n "$url" ]] || { log "Could not determine fzf download URL"; return 1; }

  log "Downloading fzf from $url"
  curl -fsSL "$url" -o "$tmp/fzf.tar.gz"
  tar -xzf "$tmp/fzf.tar.gz" -C "$tmp" fzf
  as_root install "$tmp/fzf" /usr/local/bin/fzf
  rm -rf "$tmp"
  log "fzf installed to /usr/local/bin"
}

check_neovim_version() {
  if [[ "$dry_run" -eq 1 ]]; then
    log "Neovim version check: requires 0.11 or newer."
    return 0
  fi

  local nvim_bin
  nvim_bin="$(command -v nvim 2>/dev/null || true)"

  # If nvim wasn't installed by the PPA yet, check /usr/bin/nvim directly
  if [[ -z "$nvim_bin" ]] && [[ -x /usr/bin/nvim ]]; then
    nvim_bin=/usr/bin/nvim
  fi

  if [[ -z "$nvim_bin" ]]; then
    log "nvim was not found after package installation."
    exit 1
  fi

  local version
  version="$("$nvim_bin" --version | awk 'NR == 1 { print $2 }' | sed 's/^v//')"
  if ! printf '0.11.0\n%s\n' "$version" | sort -V -C; then
    log "Neovim $version is too old. Install Neovim 0.11 or newer (ppa:neovim-ppa/unstable), then rerun this script with --skip-packages."
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

  # Bootstrap: if not running from within the cloned config directory,
  # clone (or pull) the repo there and re-exec from it.
  # This avoids CDN staleness when the script was piped via curl.
  local self_dir
  self_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P 2>/dev/null || true)"
  if [[ "$self_dir" != "$config_dir" ]]; then
    if [[ -d "$config_dir/.git" ]]; then
      log "Updating existing config in $config_dir ..."
      run git -C "$config_dir" pull --ff-only
    else
      if [[ -e "$config_dir" ]]; then
        local backup_dir="${config_dir}.backup.$(date +%Y%m%d%H%M%S)"
        log "Backing up existing config to $backup_dir"
        run mv "$config_dir" "$backup_dir"
      fi
      run mkdir -p "$(dirname "$config_dir")"
      log "Cloning config to $config_dir ..."
      run git clone "$repo_url" "$config_dir"
    fi
    exec "$config_dir/install.sh" "$@"
    # never reached
  fi

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
  install_language_tools
  install_nvim_dev_launcher

  log "Lazy sync: installing or updating Neovim plugins."
  sync_plugins

  log "Neovim setup complete."
}

main "$@"
