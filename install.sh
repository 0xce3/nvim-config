#!/usr/bin/env bash
set -euo pipefail

repo_url="${NVIM_CONFIG_REPO:-https://github.com/0xce3/nvim-config.git}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
dry_run=0
yes=0
skip_packages=0
unmet_requirements=()

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

Installs the host-side Neovim and OpenCode workflow: packages, wrappers,
language tools, plugins, the OpenCode agent configuration, and the shell
environment. Dev toolchains stay in each project's devcontainer.

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
    printf 'install\n'
    return 0
  fi

  printf '%b' "${c_yellow}?${c_reset} $message ${c_dim}[install/skip/abort]${c_reset}: " >&2
  local answer
  read -r answer
  answer="${answer//$'\r'/}"
  answer="${answer#"${answer%%[![:space:]]*}"}"
  answer="${answer%"${answer##*[![:space:]]}"}"
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
    apt:unzip) printf 'unzip' ;;
    apt:python3) printf 'python3' ;;
    apt:pip3) printf 'python3-pip' ;;
    apt:node) printf 'nodejs' ;;
    apt:npm) printf 'npm' ;;
    apt:gh) printf 'gh' ;;
    apt:docker) printf 'docker.io' ;;
    apt:gcc|apt:make) printf 'build-essential' ;;
    apt:convert) printf 'imagemagick' ;;
    apt:gs) printf 'ghostscript' ;;
    apt:glab) printf 'glab' ;;
    apt:jq) printf 'jq' ;;
    apt:podman) printf 'podman' ;;
    dnf:rg) printf 'ripgrep' ;;
    dnf:fd) printf 'fd-find' ;;
    dnf:node) printf 'nodejs' ;;
    dnf:pip3) printf 'python3-pip' ;;
    dnf:convert) printf 'ImageMagick' ;;
    dnf:gs) printf 'ghostscript' ;;
    dnf:glab) printf 'glab' ;;
    dnf:gcc) printf 'gcc' ;;
    dnf:make) printf 'make' ;;
    pacman:python3) printf 'python' ;;
    pacman:pip3) printf 'python-pip' ;;
    pacman:gh) printf 'github-cli' ;;
    pacman:convert) printf 'imagemagick' ;;
    pacman:gs) printf 'ghostscript' ;;
    pacman:gcc) printf 'gcc' ;;
    pacman:make) printf 'make' ;;
    apk:pip3) printf 'py3-pip' ;;
    apk:gh) printf 'github-cli' ;;
    apk:convert) printf 'imagemagick' ;;
    apk:gs) printf 'ghostscript' ;;
    apk:gcc) printf 'build-base' ;;
    apk:make) printf 'build-base' ;;
    brew:python3) printf 'python' ;;
    brew:pip3) printf 'python' ;;
    brew:convert) printf 'imagemagick' ;;
    brew:gs) printf 'ghostscript' ;;
    brew:gcc) printf 'gcc' ;;
    brew:make) printf 'make' ;;
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
  local resolved
  # Debian and Ubuntu ship these under a different binary name. The installer
  # links the expected name into ~/.local/bin later on.
  case "$cmd" in
    fd)
      command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1
      return $?
      ;;
    bat)
      command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1
      return $?
      ;;
  esac
  resolved="$(command -v "$cmd" 2>/dev/null || true)"
  [[ -n "$resolved" && "$resolved" != /mnt/c/* ]]
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
      [[ "$dry_run" -eq 1 ]] && return 0

      # A package manager can report success and still deliver an older
      # build, for example when a third-party repository is unreachable.
      if ! command_available "$cmd"; then
        warn "$cmd still missing" "$reason"
        unmet_requirements+=("$cmd is not installed ($reason)")
        return 0
      fi
      current="$(command_version "$cmd" || true)"
      if [[ -n "$min_version" && -n "$current" ]] && ! version_ge "$current" "$min_version"; then
        warn "$cmd still too old" "$current < $min_version"
        unmet_requirements+=("$cmd $current is older than $min_version ($reason)")
      else
        ok "$cmd" "${current:-installed}"
      fi
      ;;
    skip) warn "skipped" "$cmd" ;;
    *) fail "aborted" "$cmd required for $reason"; exit 1 ;;
  esac
}

# The installer downloads from several HTTPS origins. A TLS-inspecting proxy
# without its root certificate in the system trust store makes those downloads
# fail in ways that look like unrelated errors, so check the trust store first.
check_tls_trust() {
  step "TLS trust" "verifying HTTPS downloads work"
  if [[ "$dry_run" -eq 1 ]]; then
    info "skipped in dry run" "TLS probe"
    return 0
  fi

  local endpoint status untrusted=()
  for endpoint in https://github.com https://ppa.launchpadcontent.net https://bun.sh; do
    status=0
    curl -sS --max-time 20 -o /dev/null "$endpoint" 2>/dev/null || status=$?
    # 35 SSL connect error, 60 certificate not verified, 77 CA store unreadable.
    case "$status" in
      35|60|77) untrusted+=("$endpoint") ;;
    esac
  done

  if [[ "${#untrusted[@]}" -eq 0 ]]; then
    ok "TLS trust" "all download origins verified"
    return 0
  fi

  fail "TLS certificate verification failed" "${untrusted[*]}"
  warn "a TLS-inspecting proxy is in the way" "its root certificate is not trusted here"
  info "install the certificates, then re-run" "NVIM_EXTRA_CA_DIR=/path/to/certs ./install.sh"
  unmet_requirements+=("TLS trust is incomplete for: ${untrusted[*]}")
}

# Corporate root certificates cannot live in a public repository. Point
# NVIM_EXTRA_CA_DIR at a local directory holding the .crt files instead.
install_extra_ca_certificates() {
  local source_dir="${NVIM_EXTRA_CA_DIR:-}"
  [[ -n "$source_dir" ]] || return 0

  step "extra CA certificates" "$source_dir"
  if [[ ! -d "$source_dir" ]]; then
    warn "certificate directory not found" "$source_dir"
    return 0
  fi

  local certificate found=0
  for certificate in "$source_dir"/*.crt; do
    [[ -f "$certificate" ]] || continue
    as_root install -m 0644 "$certificate" "/usr/local/share/ca-certificates/$(basename "$certificate")"
    found=$((found + 1))
  done

  if [[ "$found" -eq 0 ]]; then
    warn "no .crt files found" "$source_dir"
    return 0
  fi
  as_root update-ca-certificates
  ok "installed CA certificates" "$found file(s)"
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

install_yazi_github() {
  yazi --version >/dev/null 2>&1 && { ok "yazi" "installed"; return 0; }
  [[ "$skip_packages" -eq 1 ]] && { warn "yazi missing" "skipped"; return 0; }
  [[ "$(prompt_action "Install yazi from GitHub release?")" == install ]] || { warn "skipped" "yazi"; return 0; }
  [[ "$dry_run" -eq 1 ]] && { run curl -fsSL https://github.com/sxyazi/yazi/releases/latest; return 0; }

  local tmp target
  tmp="$(mktemp -d)"
  case "$(uname -m)" in
    x86_64|amd64) target=x86_64-unknown-linux-musl ;;
    aarch64|arm64) target=aarch64-unknown-linux-musl ;;
    *) fail "unsupported architecture" "$(uname -m)"; rm -rf "$tmp"; return 1 ;;
  esac
  curl -fsSL -o "$tmp/yazi.zip" "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${target}.zip"
  unzip -q "$tmp/yazi.zip" -d "$tmp"
  as_root install -m 0755 "$tmp/yazi-${target}/yazi" "$tmp/yazi-${target}/ya" /usr/local/bin/
  rm -rf "$tmp"
  ok "yazi" "installed"
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

opencode_version() {
  local binary="$1" raw
  raw="$("$binary" --version 2>/dev/null | head -n 1)" || return 1
  raw="${raw##* }"
  printf '%s' "${raw#v}"
}

opencode_major_version() {
  local version
  version="$(opencode_version "$1")" || return 1
  printf '%s' "${version%%.*}"
}

install_opencode() {
  step "install OpenCode" "AI coding assistant"
  # The configuration in ~/.config/opencode targets OpenCode 2: the v2 CLI
  # schema, the background service, and the plugin API. The installer at
  # opencode.ai/install still serves the 1.x line, so use the v2 endpoint.
  local installer="${OPENCODE_INSTALLER:-https://opencode.ai/v2/install}"
  local binary="$HOME/.opencode/bin/opencode"
  local major=""

  [[ -x "$binary" ]] && major="$(opencode_major_version "$binary" || true)"
  if [[ "$major" == 2 ]]; then
    ok "opencode" "v$(opencode_version "$binary")"
    return 0
  fi
  [[ -n "$major" ]] && warn "opencode v$(opencode_version "$binary") is too old" "the configuration requires OpenCode 2"

  if [[ "$skip_packages" -eq 1 ]]; then
    warn "opencode missing" "skipped"
    return 0
  fi
  [[ "$(prompt_action "Install OpenCode 2 from the official installer?")" == install ]] || {
    warn "skipped" "opencode"
    return 0
  }
  if [[ "$dry_run" -eq 1 ]]; then
    run curl -fsSL "$installer"
    return 0
  fi

  curl -fsSL "$installer" | bash || true
  major=""
  [[ -x "$binary" ]] && major="$(opencode_major_version "$binary" || true)"
  if [[ "$major" == 2 ]]; then
    ok "opencode" "v$(opencode_version "$binary")"
  else
    warn "opencode 2 install failed" "run curl -fsSL $installer | bash manually"
    unmet_requirements+=("OpenCode 2 is not installed (the configuration requires it)")
  fi
}

install_opencode_config() {
  step "OpenCode configuration" "agents, commands, plugins, theme"
  run bash "$config_dir/bin/install-opencode-config"
}

install_bun() {
  step "install Bun" "OpenCode plugin runtime"
  if command -v bun >/dev/null 2>&1 || [[ -x "$HOME/.bun/bin/bun" ]]; then
    ok "bun" "installed"
    return 0
  fi
  if [[ "$skip_packages" -eq 1 ]]; then
    warn "bun missing" "skipped"
    return 0
  fi
  [[ "$(prompt_action "Install Bun from the official installer?")" == install ]] || {
    warn "skipped" "bun"
    return 0
  }
  if [[ "$dry_run" -eq 1 ]]; then
    run curl -fsSL https://bun.sh/install
    return 0
  fi
  curl -fsSL https://bun.sh/install | bash || warn "bun install failed" "run curl -fsSL https://bun.sh/install | bash manually"
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  command -v bun >/dev/null 2>&1 && ok "bun" "$(bun --version)"
}

install_gitleaks_github() {
  command -v gitleaks >/dev/null 2>&1 && { ok "gitleaks" "installed"; return 0; }
  [[ -x "$HOME/.local/bin/gitleaks" ]] && { ok "gitleaks" "installed"; return 0; }
  [[ "$skip_packages" -eq 1 ]] && { warn "gitleaks missing" "skipped"; return 0; }
  [[ "$(prompt_action "Install gitleaks from GitHub release?")" == install ]] || { warn "skipped" "gitleaks"; return 0; }
  [[ "$dry_run" -eq 1 ]] && { run curl -fsSL https://github.com/gitleaks/gitleaks/releases/latest; return 0; }

  local tmp arch version
  tmp="$(mktemp -d)"
  case "$(uname -m)" in
    x86_64|amd64) arch=x64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) fail "unsupported architecture" "$(uname -m)"; rm -rf "$tmp"; return 1 ;;
  esac
  version="$(python3 -c 'import json, urllib.request; print(json.load(urllib.request.urlopen("https://api.github.com/repos/gitleaks/gitleaks/releases/latest", timeout=20))["tag_name"].lstrip("v"))')" || {
    warn "gitleaks lookup failed" "install it manually"; rm -rf "$tmp"; return 0
  }
  if curl -fsSL -o "$tmp/gitleaks.tar.gz" "https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_linux_${arch}.tar.gz"; then
    tar -C "$tmp" -xf "$tmp/gitleaks.tar.gz" gitleaks
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$tmp/gitleaks" "$HOME/.local/bin/gitleaks"
    ok "gitleaks installed" "$version"
  else
    warn "gitleaks download failed" "install it manually"
  fi
  rm -rf "$tmp"
}

install_devcontainer_cli() {
  step "devcontainer CLI" "nvim-dev container workflow"
  if command -v devcontainer >/dev/null 2>&1; then
    ok "devcontainer" "installed"
    return 0
  fi
  if [[ "$skip_packages" -eq 1 ]]; then
    warn "devcontainer CLI missing" "skipped"
    return 0
  fi
  if command -v npm >/dev/null 2>&1; then
    as_root npm install -g @devcontainers/cli \
      || warn "devcontainer CLI install failed" "nvim-dev falls back to npx -y @devcontainers/cli"
  else
    warn "npm missing" "devcontainer CLI skipped"
  fi
}

install_rootless_podman() {
  step "rootless Podman" "OpenCode agent container profiles"
  if [[ "$skip_packages" -eq 1 ]]; then
    warn "podman setup skipped" "--skip-packages"
    return 0
  fi
  ensure_command "$manager" podman "" "sandboxed agent containers"
  if [[ "$manager" == apt ]]; then
    install_system_packages apt slirp4netns fuse-overlayfs uidmap \
      || warn "rootless Podman dependencies failed" "install slirp4netns fuse-overlayfs uidmap manually"
  fi
}

configure_docker_access() {
  command -v docker >/dev/null 2>&1 || return 0
  getent group docker >/dev/null 2>&1 || return 0

  # USER is not exported by every shell that can run this installer.
  local account
  account="${USER:-$(id -un)}"

  id -nG "$account" | tr ' ' '\n' | grep -qx docker && return 0

  if [[ "$skip_packages" -eq 1 ]]; then
    warn "docker group membership skipped" "run: sudo usermod -aG docker $account"
    return 0
  fi
  [[ "$(prompt_action "Add $account to the docker group for rootless Docker access?")" == install ]] || {
    warn "docker group membership skipped" "run: sudo usermod -aG docker $account"
    return 0
  }
  as_root usermod -aG docker "$account"
  ok "docker group membership added" "restart WSL before using docker without sudo"
}

install_language_tools() {
  step "language tools" "pyright ruff"
  if command -v npm >/dev/null 2>&1; then
    as_root npm install -g pyright || warn "pyright install failed" "run sudo npm install -g pyright manually"
  else
    warn "npm missing" "pyright skipped"
  fi
  if command -v python3 >/dev/null 2>&1; then
    run python3 -m pip install --user --break-system-packages ruff || run python3 -m pip install --user ruff || warn "ruff install failed" "run python3 -m pip install --user ruff manually"
  else
    warn "python3 missing" "ruff skipped"
  fi
}

install_media_tools() {
  step "media preview tools" "snacks.image yazi"
  ensure_command "$manager" bat "" "syntax-highlighted Yazi previews"
  if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    run mkdir -p "$HOME/.local/bin"
    run ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi
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

install_shell_env() {
  step "shell environment" "PATH for wrappers, OpenCode, Bun"
  run bash "$config_dir/bin/install-shell-env"
}

nvim_binary() {
  local nvim_bin
  nvim_bin="$(command -v nvim 2>/dev/null || true)"
  [[ -n "$nvim_bin" ]] || nvim_bin="/usr/local/bin/nvim"
  printf '%s\n' "$nvim_bin"
}

# Headless Neovim must never be able to stall the installer forever.
nvim_headless() {
  local limit="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    run timeout "$limit" "$(nvim_binary)" --headless "$@"
  else
    run "$(nvim_binary)" --headless "$@"
  fi
}

sync_plugins() {
  step "Lazy sync" "install/update plugins"
  nvim_headless 30m '+Lazy! sync' '+qa' || warn "Lazy sync failed" "run :Lazy sync manually"
}

install_mason_packages() {
  step "Mason packages" "language servers, formatters, linters"
  # mason-tool-installer already installs on VimEnter. MasonToolsInstallSync
  # would race with that run and wait for a callback that never arrives, so
  # wait for the completion event instead. The autocommand is registered with
  # --cmd, before the configuration loads, so the event cannot be missed.
  nvim_headless 40m \
    --cmd "lua vim.g.nvim_config_mason_done = false; vim.api.nvim_create_autocmd('User', { pattern = 'MasonToolsUpdateCompleted', callback = function() vim.g.nvim_config_mason_done = true end })" \
    -c "lua vim.wait(2100000, function() return vim.g.nvim_config_mason_done end, 500)" \
    -c 'qa!' \
    || warn "Mason package install failed" "run :MasonToolsInstall manually"
}

build_treesitter_parsers() {
  step "Treesitter parsers" "build locally for this system"
  # TSInstall returns before the parsers are compiled, so wait on the handle.
  nvim_headless 30m -c \
    "lua require('nvim-treesitter').install({'bash','c','http','lua','luap','markdown','markdown_inline','python','query','vim','vimdoc','yaml'}, { force = true }):wait(1500000)" \
    -c 'qa' \
    || warn "Treesitter parser build failed" "run :TSInstall <language> after fixing the compiler"
}

verify_editor_tools() {
  step "verify editor tools" "Mason binaries and Treesitter parsers"
  [[ "$dry_run" -eq 1 ]] && return 0

  local mason_bin="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin"
  local parser_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/parser"
  local tool missing=()

  for tool in clangd lua-language-server stylua; do
    [[ -e "$mason_bin/$tool" ]] || missing+=("Mason tool $tool")
  done
  for tool in lua vim vimdoc c python; do
    [[ -e "$parser_dir/$tool.so" ]] || missing+=("Treesitter parser $tool")
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    ok "editor tools verified" "Mason and Treesitter are complete"
    return 0
  fi
  for tool in "${missing[@]}"; do
    warn "missing" "$tool"
    unmet_requirements+=("$tool was not installed")
  done
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

  install_extra_ca_certificates
  check_tls_trust

  step "host dependencies" "checking commands and versions"
  ensure_command "$manager" git "" "clone and update plugins"
  ensure_command "$manager" curl "" "download installers and releases"
  ensure_command "$manager" tar "" "extract release archives"
  ensure_command "$manager" unzip "" "extract Mason packages"
  ensure_command "$manager" nvim "0.12.0" "editor runtime"
  ensure_command "$manager" tmux "" "editor, shell, and task windows"
  if [[ "$skip_packages" -eq 0 ]]; then
    run bash "$config_dir/bin/install-tmux"
  fi
  ensure_command "$manager" rg "" "fast text search"
  ensure_command "$manager" fd "" "fast file search"
  ensure_command "$manager" fzf "0.36.0" "interactive launchers and pickers"
  ensure_command "$manager" python3 "" "python tooling and tests"
  ensure_command "$manager" pip3 "" "python package installs"
  ensure_command "$manager" node "18.0.0" "pyright and plugin tooling"
  ensure_command "$manager" npm "" "node package installs"
  ensure_command "$manager" gcc "" "compile local Treesitter parsers"
  ensure_command "$manager" make "" "compile local Treesitter parsers"
  ensure_command "$manager" docker "" "devcontainer workflow"
  configure_docker_access
  ensure_command "$manager" gh "" "GitHub integration"
  ensure_command "$manager" glab "" "GitLab integration"
  ensure_command "$manager" jq "" "JSON processing in scripts and hooks"

  install_lazygit_github
  install_yazi_github
  install_gitleaks_github
  install_bun
  install_opencode
  install_opencode_config
  install_devcontainer_cli
  install_rootless_podman
  install_wrappers
  install_shell_env
  install_language_tools
  install_media_tools
  sync_plugins
  install_mason_packages
  build_treesitter_parsers
  verify_editor_tools

  if [[ "${#unmet_requirements[@]}" -gt 0 ]]; then
    local requirement
    fail "setup incomplete" "${#unmet_requirements[@]} requirement(s) not satisfied"
    for requirement in "${unmet_requirements[@]}"; do
      warn "unmet" "$requirement"
    done
    info "fix the above, then re-run" "./install.sh"
    return 1
  fi

  ok "setup complete" "restart the shell, then run: nvim ."
  info "authenticate" "gh auth login · glab auth login · opencode auth login"
}

main "$@"
