# Repository Guidelines

## Start Here

- Read `docs/ARCHITECTURE.md` before making non-trivial code changes. It is the canonical code map for this repo.
- Read `lib/rr.ex` before adding, renaming, or removing commands so the CLI dispatcher stays aligned with command modules.
- Read the relevant test file under `test/rr/` before changing behavior in that area.

## Canonical Commands

- `just setup` installs dependencies with `mix deps.get`.
- `just compile` builds the project with `mix compile`.
- `just dev-shell` starts `iex -S mix` for local CLI debugging.
- `just dbg-command command` runs an `rr` command through `iex --dbg pry -S mix run --no-halt -- ...`, which is useful when you want `dbg`/pry while exercising a CLI path. For example `just dbg-command list`, `just dbg-command kf id1`. Quoted forms like `just dbg-command 'kf id1'` work too.
- `just test` runs the full ExUnit suite.
- `just test-target test/rr/login_test.exs` runs a focused test file or line.
- `just lint` checks formatting with `mix format --check-formatted`.
- `just format` rewrites formatting with `mix format`.
- `just check` runs the standard verification pass for most changes.
- `just release-macos-arm` builds the local Burrito binary for macOS arm64.

## Editing Workflow

- Before changing command behavior, read `lib/rr.ex`, the relevant `lib/cmds/*.ex` file, and `lib/rr/shell.ex`.
- Before changing Rancher or config behavior, read the matching `lib/external/*` behavior and implementation pair first, then the related tests under `test/rr/`.
- Preserve the behavior-to-implementation indirection in `External.Config` and `External.RancherHttpClient`; tests rely on swapping those modules with Mox.
- Use `RR_HOME` to point manual testing at a temporary directory so local experiments do not touch real `~/.rr` state.
- Do not commit Rancher tokens, kubeconfigs, or files created under `RR_HOME`.

## Testing Notes

- ExUnit is the test framework; Mox is the mocking strategy.
- `RR.Config.Auth` caches token validation results in ETS table `:rr_auth_cache`. Tests that exercise auth behavior should clear that cache between examples.
- `RR.KubeConfig` validates cached kubeconfigs by shelling out to `kubectl`, so manual end-to-end testing assumes `kubectl` is installed and usable.
- There is no separate typecheck step in this repo today. Treat `mix compile` plus focused tests as the closest verification for structural changes.

## ExecPlans

When writing complex features or significant refactors, use an ExecPlan from design through implementation as described in `docs/PLANS.md`.

Store plans in `docs/exec-plans/` using `todo/`, `active/`, and `completed/` to reflect status.
