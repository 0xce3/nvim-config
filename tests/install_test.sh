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
assert_contains "$noninteractive_output" "apt-get install -y neovim"

interactive_answers="$(printf 'i\r\n%.0s' {1..20})"
interactive_output="$(PATH="$install_path:/usr/bin:/bin" script -qec "$install_script --dry-run" /dev/null <<< "$interactive_answers")"
assert_contains "$interactive_output" "apt-get install -y neovim"

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

if grep -RniE "$blocked_pattern" "$repo_root" --exclude-dir=.git; then
  fail "non-neutral terms found"
fi

printf 'install_test.sh: ok\n'
