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

dry_run_output="$("$install_script" --dry-run)"
assert_contains "$dry_run_output" "Dry run"
assert_contains "$dry_run_output" "Neovim config repository"
assert_contains "$dry_run_output" "Lazy sync"
assert_contains "$dry_run_output" "pyright"
assert_contains "$dry_run_output" "ruff"
assert_contains "$dry_run_output" "Neovim version check"

apt_path="$(mktemp -d)"
trap 'rm -rf "$apt_path"' EXIT
cat > "$apt_path/apt-get" <<'STUB'
#!/usr/bin/env sh
exit 0
STUB
chmod +x "$apt_path/apt-get"

detect_output="$(PATH="$apt_path:/usr/bin:/bin" "$install_script" --dry-run)"
assert_contains "$detect_output" "Package manager: apt"

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
