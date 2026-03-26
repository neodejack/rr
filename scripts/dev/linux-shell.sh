#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image_tag="rr-dev-env"
binary="$repo_root/dev_out/bin/rr_linux"
rr_home="$repo_root/dev_out/home/linux"
shell_dir="$repo_root/dev_out/shells"
bashrc_path="$shell_dir/linux.bashrc"
seed_config="$HOME/.rr/config.json"

container_platform() {
  local arch

  arch="$(podman info --format '{{.Host.Arch}}')"

  case "$arch" in
  amd64 | arm64)
    printf 'linux/%s\n' "$arch"
    ;;
  x86_64)
    printf '%s\n' 'linux/amd64'
    ;;
  aarch64)
    printf '%s\n' 'linux/arm64'
    ;;
  *)
    printf 'Unsupported Podman architecture: %s\n' "$arch" >&2
    exit 1
    ;;
  esac
}

if [[ ! -x "$binary" ]]; then
  printf '%s\n' "Missing $binary. Run 'just dev build' first." >&2
  exit 1
fi

if ! command -v podman >/dev/null 2>&1; then
  printf '%s\n' "podman is required for just dev linux. Install Podman and ensure it is available in PATH." >&2
  exit 1
fi

mkdir -p "$rr_home" "$shell_dir"

platform="$(container_platform)"

cat >"$bashrc_path" <<'EOF'
if [ -f /etc/bash.bashrc ]; then
  . /etc/bash.bashrc
fi

export RR_HOME=/rr-home

if [ "$(uname -m)" = "x86_64" ]; then
  alias rr='/workspace/dev_out/bin/rr_linux'
else
  alias rr='qemu-x86_64-static /workspace/dev_out/bin/rr_linux'
fi

PS1='(rr-dev-linux) \w\$ '
EOF

image_platform="$(podman image inspect "$image_tag" --format '{{.Os}}/{{.Architecture}}' 2>/dev/null || true)"

if [[ "$image_platform" != "$platform" ]]; then
  podman build \
    --platform "$platform" \
    --tag "$image_tag" \
    --file "$repo_root/Dockerfile.dev" \
    "$repo_root"
fi

podman_args=(
  run
  --platform "$platform"
  --rm
  --interactive
  --tty
  --user "$(id -u):$(id -g)"
  --workdir /workspace
  --env HOME=/tmp/rr-dev-linux-home
  --env TERM="${TERM:-xterm-256color}"
  --volume "$repo_root:/workspace"
  --volume "$binary:/workspace/dev_out/bin/rr_linux:ro"
  --volume "$rr_home:/rr-home"
)

if [[ -f "$seed_config" ]]; then
  podman_args+=(--volume "$seed_config:/seed-config/config.json:ro")
fi

container_cmd=$(
  cat <<'EOF'
set -euo pipefail
mkdir -p /rr-home

if [ ! -f /rr-home/config.json ] && [ -f /seed-config/config.json ]; then
  cp /seed-config/config.json /rr-home/config.json
fi

printf 'rr dev shell: linux\nbinary: %s\nRR_HOME: %s\n' '/workspace/dev_out/bin/rr_linux' '/rr-home'
exec bash --rcfile /workspace/dev_out/shells/linux.bashrc -i
EOF
)

podman "${podman_args[@]}" "$image_tag" bash -lc "$container_cmd"
