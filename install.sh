#!/usr/bin/env bash
set -euo pipefail

repo_url="${NVIM_CONFIG_REPO:-https://github.com/0xce3/nvim-config.git}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
dry_run=0
yes=0
skip_packages=0

if [[ -t 1 && "${NO_COLOR:-}" == "" ]]; then
  c_reset=$'\033[0m'
  c_dim=$'\033[2m'
  c_red=$'\033[31m'
  c_green=$'\033[32m'
  c_yellow=$'\033[33m'
  c_blue=$'\033[34m'
  c_magenta=$'\033[35m'
  c_cyan=$'\033[36m'
  c_bold=$'\033[1m'
else
  c_reset= c_dim= c_red= c_green= c_yellow= c_blue= c_magenta= c_cyan= c_bold=
fi

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--dry-run] [--yes] [--skip-packages]

Installs the host-side Neovim workflow: packages, wrappers, language tools,
and plugins. Dev toolchains stay in each project's devcontainer.

Options:
  --dry-run        Print planned actions without changing the system.
  --yes           Accept package/tool install prompts.
  --skip-packages Do not install or update system packages.
  -h, --help      Show this help.
USAGE
}

log() { printf '%b\n' "$*"; }
banner() { log "${c_cyan}${c_bold}╭─ nvim-config installer${c_reset} ${c_dim}host bootstrap${c_reset}"; }
step() { log "${c_blue}▸${c_reset} ${c_bold}$1${c_reset}${2:+ ${c_dim}$2${c_reset}}"; }
ok() { log "${c_green}✓${c_reset} $1${2:+ ${c_dim}$2${c_reset}}"; }
warn() { log "${c_yellow}!${c_reset} $1${2:+ ${c_dim}$2${c_reset}}"; }
fail() { log "${c_red}✗${c_reset} ${c_bold}$1${c_reset}${2:+ ${c_dim}$2${c_reset}}"; }
info() { log "${c_magenta}λ${c_reset} $1${2:+ ${c_dim}$2${c_reset}}"; }

run() {
  if [[ "$dry_run" -eq 1 ]]; then
    printf '  $'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    run "$@"
  elif command -v sudo >/dev/null 2>&1; then
    run sudo "$@"
  else
    fail "sudo is required" "cannot install system packages"
    exit 1
  fi
}

version_ge() {
  printf '%s\n%s\n' "$2" "$1" | sort -V -C 2>/dev/null
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

prompt_action() {
  local message="$1"
  if [[ "$yes" -eq 1 ]]; then
    printf 'install\n'
    return 0
  fi
  if [[ ! -t 0 ]]; then
    printf 'skip\n'
    return 0
  fi

  printf '%b' "${c_yellow}?${c_reset} $message ${c_dim}[install/skip/abort]${c_reset}: "
  local answer
  read -r answer
  case "${answer,,}" in
    i|install|y|yes) printf 'install\n' ;;
    s|skip|"") printf 'skip\n' ;;
    *) printf 'abort\n' ;;
  esac
}

install_system_packages() {
  local manager="$1"; shift
  local packages=("$@")
  [[ "${#packages[@]}" -eq 0 ]] && return 0

  case "$manager" in
    apt)
      as_root apt-get update || true
      as_root apt-get install -y software-properties-common || true
      as_root add-apt-repository -y ppa:neovim-ppa/unstable 2>/dev/null || true
      as_root apt-get update || true
      as_root apt-get install -y "${packages[@]}"
      ;;
    dnf) as_root dnf install -y "${packages[@]}" ;;
    pacman) as_root pacman -Sy --needed --noconfirm "${packages[@]}" ;;
    apk) as_root apk add --no-cache "${packages[@]}" ;;
    brew) run brew install "${packages[@]}" ;;
    *) fail "unsupported package manager" "install missing packages manually"; return 1 ;;
  esac
}

pkg_name() {
  local manager="$1" cmd="$2"
  case "$manager:$cmd" in
    apt:nvim) printf 'neovim' ;;
    apt:rg) printf 'ripgrep' ;;
    apt:fd) printf 'fd-find' ;;
    apt:python3) printf 'python3' ;;
    apt:pip3) printf 'python3-pip' ;;
    apt:node) printf 'nodejs' ;;
    apt:npm) printf 'npm' ;;
    apt:gh) printf 'gh' ;;
    apt:convert) printf 'imagemagick' ;;
    apt:gs) printf 'ghostscript' ;;
    dnf:rg) printf 'ripgrep' ;;
    dnf:fd) printf 'fd-find' ;;
    dnf:node) printf 'nodejs' ;;
    dnf:pip3) printf 'python3-pip' ;;
    dnf:convert) printf 'ImageMagick' ;;
    dnf:gs) printf 'ghostscript' ;;
    pacman:python3) printf 'python' ;;
    pacman:pip3) printf 'python-pip' ;;
    pacman:gh) printf 'github-cli' ;;
    pacman:convert) printf 'imagemagick' ;;
    pacman:gs) printf 'ghostscript' ;;
    apk:pip3) printf 'py3-pip' ;;
    apk:gh) printf 'github-cli' ;;
    apk:convert) printf 'imagemagick' ;;
    apk:gs) printf 'ghostscript' ;;
    brew:python3) printf 'python' ;;
    brew:pip3) printf 'python' ;;
    brew:convert) printf 'imagemagick' ;;
    brew:gs) printf 'ghostscript' ;;
    *) printf '%s' "$cmd" ;;
  esac
}

command_version() {
  local cmd="$1"
  case "$cmd" in
    nvim) nvim --version 2>/dev/null | awk 'NR == 1 { print $2 }' | sed 's/^v//' ;;
    fzf) fzf --version 2>/dev/null | awk '{ print $1 }' ;;
    node) node --version 2>/dev/null | sed 's/^v//' ;;
    *) "$cmd" --version 2>/dev/null | awk 'NR == 1 { for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+(\.[0-9]+)+/) { print $i; exit } }' ;;
  esac
}

command_available() {
  local cmd="$1"
  if [[ "$cmd" == "fd" ]]; then
    command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1
    return $?
  fi
  command -v "$cmd" >/dev/null 2>&1
}

ensure_command() {
  local manager="$1" cmd="$2" min_version="${3:-}" reason="$4"
  local current=""
  if command_available "$cmd"; then
    current="$(command_version "$cmd" || true)"
    if [[ -z "$min_version" || -z "$current" || "$(version_ge "$current" "$min_version" && printf ok || true)" == ok ]]; then
      ok "$cmd" "${current:-installed}"
      return 0
    fi
    warn "$cmd too old" "$current < $min_version; $reason"
  else
    warn "$cmd missing" "$reason"
  fi

  if [[ "$skip_packages" -eq 1 ]]; then
    warn "skipped package install" "$cmd"
    return 0
  fi

  local action package
  action="$(prompt_action "Install/update $cmd for $reason?")"
  case "$action" in
    install)
      package="$(pkg_name "$manager" "$cmd")"
      install_system_packages "$manager" "$package" || true
      ;;
    skip) warn "skipped" "$cmd" ;;
    *) fail "aborted" "$cmd required for $reason"; exit 1 ;;
  esac
}

install_lazygit_github() {
  command -v lazygit >/dev/null 2>&1 && { ok "lazygit" "installed"; return 0; }
  [[ "$skip_packages" -eq 1 ]] && { warn "lazygit missing" "skipped"; return 0; }
  [[ "$(prompt_action "Install lazygit from GitHub release?")" == install ]] || { warn "skipped" "lazygit"; return 0; }
  [[ "$dry_run" -eq 1 ]] && { run curl -fsSL https://github.com/jesseduffield/lazygit/releases/latest; return 0; }

  local tmp arch version
  tmp="$(mktemp -d)"
  case "$(uname -m)" in
    x86_64|amd64) arch=x86_64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) fail "unsupported architecture" "$(uname -m)"; rm -rf "$tmp"; return 1 ;;
  esac
  version="$(python3 -c 'import json, urllib.request; print(json.load(urllib.request.urlopen("https://api.github.com/repos/jesseduffield/lazygit/releases/latest", timeout=20))["tag_name"].lstrip("v"))')"
  curl -fsSL -o "$tmp/lazygit.tar.gz" "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${version}_Linux_${arch}.tar.gz"
  tar -C "$tmp" -xf "$tmp/lazygit.tar.gz" lazygit
  as_root install -m 0755 "$tmp/lazygit" /usr/local/bin/lazygit
  rm -rf "$tmp"
  ok "lazygit installed" "$version"
}

install_wrappers() {
  step "install wrappers" "nvim nvim-dev opencode"
  run "$config_dir/bin/install-wrappers"

  if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    step "install wrapper" "fd → fdfind"
    run mkdir -p "$HOME/.local/bin"
    if [[ "$dry_run" -eq 1 ]]; then
      run ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    else
      ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
      ok "fd wrapper installed" "$HOME/.local/bin/fd"
    fi
  fi
}

install_language_tools() {
  step "language tools" "pyright ruff"
  if command -v npm >/dev/null 2>&1; then
    run npm install -g pyright || warn "pyright install failed" "run npm install -g pyright manually"
  else
    warn "npm missing" "pyright skipped"
  fi
  if command -v python3 >/dev/null 2>&1; then
    run python3 -m pip install --user ruff || run python3 -m pip install --user --break-system-packages ruff || warn "ruff install failed" "run python3 -m pip install --user ruff manually"
  else
    warn "python3 missing" "ruff skipped"
  fi
}

install_media_tools() {
  step "media preview tools" "snacks.image"
  ensure_command "$manager" kitty "" "inline image rendering in terminal"
  ensure_command "$manager" convert "" "image conversion for previews"
  ensure_command "$manager" gs "" "PDF rendering for previews"
  ensure_command "$manager" chafa "" "terminal image fallback previews"
  if ! command -v mmdc >/dev/null 2>&1; then
    warn "mmdc missing" "Mermaid previews need @mermaid-js/mermaid-cli or snap install mermaid-cli"
  else
    ok "mmdc" "installed"
  fi
}

sync_plugins() {
  step "Lazy sync" "install/update plugins"
  local nvim_bin
  nvim_bin="$(command -v nvim 2>/dev/null || true)"
  [[ -n "$nvim_bin" ]] || nvim_bin="/usr/local/bin/nvim"
  run "$nvim_bin" --headless '+Lazy! sync' '+qa' || warn "Lazy sync failed" "run :Lazy sync manually"
}

script_dir() {
  local source="${BASH_SOURCE[0]:-${0:-}}"
  [[ -n "$source" && "$source" == */* && -e "$source" ]] || return 0
  cd "$(dirname "$source")" 2>/dev/null && pwd -P 2>/dev/null
}

bootstrap_repo() {
  local original_args=("$@") self_dir
  self_dir="$(script_dir || true)"
  if [[ "$self_dir" == "$config_dir" ]]; then
    return 0
  fi

  step "config repository" "$config_dir"
  if [[ -d "$config_dir/.git" ]]; then
    run git -C "$config_dir" pull --ff-only
  else
    if [[ -e "$config_dir" ]]; then
      local backup_dir="${config_dir}.backup.$(date +%Y%m%d%H%M%S)"
      warn "existing config found" "moving to $backup_dir"
      run mv "$config_dir" "$backup_dir"
    fi
    run mkdir -p "$(dirname "$config_dir")"
    run git clone "$repo_url" "$config_dir"
  fi
  if [[ "$dry_run" -eq 1 ]]; then
    run "$config_dir/install.sh" "${original_args[@]}"
    return 0
  fi
  exec "$config_dir/install.sh" "${original_args[@]}"
}

main() {
  local original_args=("$@")
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=1 ;;
      --yes|-y) yes=1 ;;
      --skip-packages) skip_packages=1 ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; exit 2 ;;
    esac
    shift
  done

  banner
  [[ "$dry_run" -eq 1 ]] && warn "Dry run" "no changes will be made"
  info "Neovim config repository" "$repo_url"
  info "Config directory" "$config_dir"

  bootstrap_repo "${original_args[@]}"

  local manager
  manager="$(detect_package_manager)"
  info "Package manager" "$manager"

  step "host dependencies" "checking commands and versions"
  ensure_command "$manager" git "" "clone and update plugins"
  ensure_command "$manager" curl "" "download installers and releases"
  ensure_command "$manager" tar "" "extract release archives"
  ensure_command "$manager" nvim "0.12.0" "editor runtime"
  ensure_command "$manager" rg "" "fast text search"
  ensure_command "$manager" fd "" "fast file search"
  ensure_command "$manager" fzf "0.36.0" "interactive launchers and pickers"
  ensure_command "$manager" python3 "" "python tooling and tests"
  ensure_command "$manager" pip3 "" "python package installs"
  ensure_command "$manager" node "18.0.0" "pyright and plugin tooling"
  ensure_command "$manager" npm "" "node package installs"
  ensure_command "$manager" docker "" "devcontainer workflow"
  ensure_command "$manager" gh "" "GitHub integration"

  install_lazygit_github
  install_wrappers
  install_language_tools
  install_media_tools
  sync_plugins

  ok "setup complete" "open a project and run: nvim ."
}

main "$@"
