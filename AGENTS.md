# Repository Guidelines

## Start Here

- Read `docs/GUIDELINES.md` before making changes. It is the index for the repo's working rules and points to the detailed pages under `docs/guidelines/`.
- Read `docs/ARCHITECTURE.md` before planning or making changes. It is small enough to treat as standard context, and it answers "where does this change live?"
- Before planning a code change, read `docs/DESIGN.md`. If it points to an area-specific design doc for the code you are touching, read that doc before editing.

## Canonical Commands

- `mix deps.get` installs dependencies.
- `mix compile` is the baseline compile check.
- `mix test` runs the full test suite.
- `mix test path/to/test_file.exs` runs focused tests while iterating.
- `mix format --check-formatted` verifies formatting; `mix format` applies it.
- `iex -S mix` starts the CLI in an interactive Elixir shell.
- `just dev build` builds the local development binaries.
- `just dev macos` opens the isolated macOS dev shell.
- `just dev linux` opens the isolated Linux dev shell.
- `MIX_ENV=prod BURRITO_TARGET=macos_arm mix release --overwrite` builds the local macOS arm64 release binary.
- `rr maintenance uninstall` removes Burrito's cached runtime when a same-version rebuild looks stale.

## Verification

- Run the smallest reliable command set for the files you changed, then run `mix test` for behavior changes.
- Use `mix compile` plus targeted tests as the baseline for narrow refactors.
- Run `mix format --check-formatted` before finishing any code change.
- If you touch Burrito packaging or the dev shell scripts, validate with the relevant `just dev ...` workflow.

## ExecPlans

- Use an ExecPlan for complex features, multi-step fixes, or significant refactors.
- Read `docs/PLANS.md` for the format and maintenance rules.
- Store plans in `docs/exec-plans/todo/`, move them to `docs/exec-plans/active/` while implementing, and keep completed plans in `docs/exec-plans/completed/`.
