# list available recipes
[default]
default:
  @just --list --list-heading $'RR tasks\n' --list-prefix '■ '

# list available recipes
list:
  @just --list --list-heading $'RR tasks\n' --list-prefix '■ '

# install dependencies
setup:
  mix deps.get

# compile the project
compile:
  mix compile

# start an interactive shell with the project loaded
dev-shell:
  iex -S mix --no-halt

# run an rr command through iex with pry/dbg enabled
dbg-command +command:
  iex --dbg pry -S mix run --no-halt -- {{command}}

# run the full test suite
test:
  mix test

# run one test file or a file:line target
test-target target:
  mix test "{{target}}"

# check formatting
lint:
  mix format --check-formatted

# apply formatting
format:
  mix format

# run the standard local verification pass
check: lint test

# build the local macOS arm64 Burrito binary
release-macos-arm:
  MIX_ENV=prod BURRITO_TARGET=macos_arm mix release --overwrite

# install or upgrade rr via the published bootstrap script
upgrade_rr:
  curl -fsSL https://raw.githubusercontent.com/neodejack/rr/main/upgrade.sh | bash
