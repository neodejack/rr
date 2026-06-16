#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
binary="$repo_root/dev_out/bin/rr_macos_arm"
rr_home="$repo_root/dev_out/home/macos"
shell_dir="$repo_root/dev_out/shells/macos-zdotdir"
seed_config="$HOME/.rr/config.json"
dev_config="$rr_home/config.json"

if [[ ! -x "$binary" ]]; then
  printf '%s\n' "Missing $binary. Run 'just dev build' first." >&2
  exit 1
fi

mkdir -p "$rr_home" "$shell_dir"

if [[ ! -f "$dev_config" && -f "$seed_config" ]]; then
  cp "$seed_config" "$dev_config"
fi

cat > "$shell_dir/.zshrc" <<EOF
if [[ -f "$HOME/.zshrc" ]]; then
  source "$HOME/.zshrc"
fi

export RR_HOME="$rr_home"
alias rr='$binary'

if [[ -n "\${PROMPT:-}" ]]; then
  PROMPT="(rr-dev-macos) \${PROMPT}"
else
  PROMPT="(rr-dev-macos) %n@%m:%~%# "
fi

export PS1="\$PROMPT"
EOF

printf 'rr dev shell: macos\nbinary: %s\nRR_HOME: %s\n' "$binary" "$rr_home"

exec env ZDOTDIR="$shell_dir" zsh -i
