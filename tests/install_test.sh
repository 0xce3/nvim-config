#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_script="$repo_root/install.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

[[ -f "$install_script" ]] || fail "install.sh exists"

bash -n "$install_script"
bash -n "$repo_root/bin/nvim-download" "$repo_root/bin/nvim-open" "$repo_root/bin/nvim-git-editor" "$repo_root/bin/nvim-dev"
bash -n "$repo_root/bin/install-wrappers" "$repo_root/bin/install-shell-env" "$repo_root/bin/install-opencode-config"
python3 -c 'compile(open(__import__("sys").argv[1], encoding="utf-8").read(), __import__("sys").argv[1], "exec")' "$repo_root/bin/nvim-port-relay"

for required_script in bin/install-shell-env bin/install-opencode-config bin/install-wrappers; do
  [[ -x "$repo_root/$required_script" ]] || fail "$required_script is executable"
done

shell_env_dir="$(mktemp -d)"
printf 'export EXISTING=1\n' > "$shell_env_dir/.bashrc"
NVIM_SHELL_PROFILE="$shell_env_dir/.bashrc" "$repo_root/bin/install-shell-env" >/dev/null
NVIM_SHELL_PROFILE="$shell_env_dir/.bashrc" "$repo_root/bin/install-shell-env" >/dev/null
[[ "$(grep -c '>>> nvim-config managed block >>>' "$shell_env_dir/.bashrc")" -eq 1 ]] \
  || fail "shell env block is written exactly once"
grep -q 'export EXISTING=1' "$shell_env_dir/.bashrc" || fail "shell env keeps existing profile content"
shell_env_path="$(env -i HOME="$shell_env_dir" PATH=/usr/bin:/bin bash -ic 'printf %s "$PATH"' 2>/dev/null)"
[[ "$shell_env_path" == "$shell_env_dir/.local/bin:"* ]] || fail "user bin directory takes PATH precedence"
[[ "$shell_env_path" == *"$shell_env_dir/.opencode/bin"* ]] || fail "OpenCode bin directory is on PATH"
[[ "$shell_env_path" == *"$shell_env_dir/.bun/bin"* ]] || fail "Bun bin directory is on PATH"
rm -rf "$shell_env_dir"

download_test_dir="$(mktemp -d)"
printf 'pdf fixture\n' > "$download_test_dir/manual.pdf"
mkdir "$download_test_dir/Downloads"
NVIM_WINDOWS_DOWNLOAD_DIR="$download_test_dir/Downloads" "$repo_root/bin/nvim-download" "$download_test_dir/manual.pdf" >/dev/null
NVIM_WINDOWS_DOWNLOAD_DIR="$download_test_dir/Downloads" "$repo_root/bin/nvim-download" "$download_test_dir/manual.pdf" >/dev/null
[[ -f "$download_test_dir/Downloads/manual.pdf" ]] || fail "downloaded file exists"
[[ -f "$download_test_dir/Downloads/manual (1).pdf" ]] || fail "download name conflict is resolved"
rm -rf "$download_test_dir"

open_test_dir="$(mktemp -d)"
printf 'pdf fixture\n' > "$open_test_dir/manual.pdf"
cat > "$open_test_dir/wslpath" <<'STUB'
#!/usr/bin/env sh
printf '%s\n' 'C:\Users\test\manual.pdf'
STUB
cat > "$open_test_dir/powershell.exe" <<'STUB'
#!/usr/bin/env sh
printf '%s\n' "$NVIM_OPEN_FILE" > "$NVIM_OPEN_RESULT"
STUB
chmod +x "$open_test_dir/wslpath" "$open_test_dir/powershell.exe"
NVIM_OPEN_RESULT="$open_test_dir/result" PATH="$open_test_dir:/usr/bin:/bin" "$repo_root/bin/nvim-open" "$open_test_dir/manual.pdf"
[[ "$(cat "$open_test_dir/result")" == 'C:\Users\test\manual.pdf' ]] || fail "Windows file path is passed to PowerShell"
rm -rf "$open_test_dir"

readme_install_command="$(grep -F 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/0xce3/nvim-config/main/install.sh)"' "$repo_root/README.md" | head -n 1)"
[[ -n "$readme_install_command" ]] || fail "README install command exists"
bash -n -c "$readme_install_command"

dry_run_output="$("$install_script" --dry-run)"
assert_contains "$dry_run_output" "Dry run"
assert_contains "$dry_run_output" "Neovim config repository"
assert_contains "$dry_run_output" "Lazy sync"
assert_contains "$dry_run_output" "pyright"
assert_contains "$dry_run_output" "ruff"
assert_contains "$dry_run_output" "host dependencies"
assert_contains "$dry_run_output" "install wrappers"
assert_contains "$dry_run_output" "OpenCode configuration"
assert_contains "$dry_run_output" "install-opencode-config"
assert_contains "$dry_run_output" "shell environment"
assert_contains "$dry_run_output" "install-shell-env"
assert_contains "$dry_run_output" "devcontainer CLI"
assert_contains "$dry_run_output" "rootless Podman"
assert_contains "$dry_run_output" "Bun"

apt_path="$(mktemp -d)"
trap 'rm -rf "$apt_path"' EXIT
cat > "$apt_path/apt-get" <<'STUB'
#!/usr/bin/env sh
exit 0
STUB
chmod +x "$apt_path/apt-get"

detect_output="$(PATH="$apt_path:/usr/bin:/bin" "$install_script" --dry-run)"
assert_contains "$detect_output" "Package manager"
assert_contains "$detect_output" "apt"

install_path="$(mktemp -d)"
trap 'rm -rf "$apt_path" "$install_path"' EXIT
cat > "$install_path/apt-get" <<'STUB'
#!/usr/bin/env sh
exit 0
STUB
cat > "$install_path/sudo" <<'STUB'
#!/usr/bin/env sh
exec "$@"
STUB
chmod +x "$install_path/apt-get" "$install_path/sudo"

noninteractive_output="$(PATH="$install_path:/usr/bin:/bin" "$install_script" --dry-run </dev/null)"
if [[ "$noninteractive_output" != *"apt-get install -y neovim" && "$noninteractive_output" != *"nvim"* ]]; then
  fail "expected Neovim to be detected or scheduled for installation"
fi

interactive_answers="$(printf 'i\r\n%.0s' {1..20})"
interactive_output="$(PATH="$install_path:/usr/bin:/bin" script -qec "$install_script --dry-run" /dev/null <<< "$interactive_answers")"
if [[ "$interactive_output" != *"apt-get install -y neovim" && "$interactive_output" != *"nvim"* ]]; then
  fail "expected Neovim to be detected or scheduled for installation"
fi

pipe_home="$(mktemp -d)"
pipe_output="$(HOME="$pipe_home" XDG_CONFIG_HOME="$pipe_home/.config" NVIM_CONFIG_REPO="$repo_root" bash -c "$(cat "$install_script")" -- --dry-run)"
rm -rf "$pipe_home"
assert_contains "$pipe_output" "config repository"
assert_contains "$pipe_output" "git clone"
assert_contains "$pipe_output" "Package manager"

blocked_terms=(
  'qm.''x'
  'endr.''ess'
  'hau.''ser'
  'firm.''ware'
  'cust.''omer'
  'kun.''de'
  'fir.''ma'
  'native_''sim'
  'zeph''yr'
  'west_''workspace'
  'shell''hopper'
  'main_''app'
)
blocked_pattern="$(IFS='|'; printf '%s' "${blocked_terms[*]}")"

if grep -RniE "$blocked_pattern" "$repo_root/install.sh" "$repo_root/README.md" "$repo_root/bin"; then
  fail "non-neutral terms found"
fi

# A fresh system must be able to restore the OpenCode configuration.
opencode_config_script="$repo_root/bin/install-opencode-config"
grep -q 'opencode-agent-crew' "$opencode_config_script" || fail "OpenCode config repository is referenced"
grep -q 'core.hooksPath' "$opencode_config_script" || fail "OpenCode git hooks are enabled"
grep -q '@opencode-ai/plugin' "$opencode_config_script" || fail "OpenCode plugin runtime is installed"
for preserved in service.json ensemble.db; do
  grep -q "$preserved" "$opencode_config_script" || fail "$preserved is preserved across re-clone"
done

printf 'install_test.sh: ok\n'
