#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ ! -f "$repo_root/Dockerfile.dev" ]]; then
  printf '%s\n' "Dockerfile.dev is not available yet. Finish the shared dev image milestone first." >&2
  exit 1
fi

printf '%s\n' "scripts/dev/build.sh is wired. The Docker-backed build flow will be added in the next milestone." >&2
exit 1
