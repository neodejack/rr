#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
image_tag="rr-dev-env"

copy_artifact() {
  local source="$1"
  local destination="$2"
  local tmp_destination
  local matches

  if [[ ! -f "$source" ]]; then
    shopt -s nullglob
    matches=("${source}".*)
    shopt -u nullglob

    if [[ "${#matches[@]}" -gt 0 ]]; then
      printf 'Expected Burrito artifact %s without an extension, but found: %s\n' "$source" "${matches[*]}" >&2
    else
      printf 'Expected Burrito artifact %s was not produced.\n' "$source" >&2
    fi

    exit 1
  fi

  tmp_destination="${destination}.tmp"
  cp "$source" "$tmp_destination"
  chmod +x "$tmp_destination"
  mv "$tmp_destination" "$destination"
}

if [[ "${1:-}" == "--in-container" ]]; then
  export HOME="${HOME:-/tmp/rr-dev-home}"
  export MIX_ENV=prod
  export MIX_HOME="${MIX_HOME:-$HOME/.mix}"
  export HEX_HOME="${HEX_HOME:-$HOME/.hex}"

  mkdir -p "$HOME" "$MIX_HOME" "$HEX_HOME" "$repo_root/dev_out/bin"

  mix local.hex --force
  mix local.rebar --force
  mix deps.get --only prod
  mix compile

  for target in macos_arm linux; do
    BURRITO_TARGET="$target" mix release --overwrite
  done

  copy_artifact "$repo_root/burrito_out/rr_macos_arm" "$repo_root/dev_out/bin/rr_macos_arm"
  copy_artifact "$repo_root/burrito_out/rr_linux" "$repo_root/dev_out/bin/rr_linux"

  exit 0
fi

if [[ ! -f "$repo_root/Dockerfile.dev" ]]; then
  printf '%s\n' "Missing $repo_root/Dockerfile.dev. The shared dev image is required for just dev build." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  printf '%s\n' "docker is required for just dev build. Install Docker or provide a docker-compatible CLI in PATH." >&2
  exit 1
fi

mkdir -p "$repo_root/dev_out/bin"

docker build \
  --tag "$image_tag" \
  --file "$repo_root/Dockerfile.dev" \
  "$repo_root"

docker run \
  --rm \
  --user "$(id -u):$(id -g)" \
  --volume "$repo_root:/workspace" \
  --workdir /workspace \
  --env HOME=/tmp/rr-dev-home \
  "$image_tag" \
  ./scripts/dev/build.sh --in-container
