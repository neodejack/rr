# Repository Guidelines

## Project Structure & Module Organization
- `lib/` contains the Elixir source. CLI entrypoint is `lib/rr.ex`; command modules live under `lib/cmds/`; configuration helpers are under `lib/config/`.
- `priv/templates/` holds EEx templates (e.g., `sh.eex` for `rr kf --sh`).
- `test/` mirrors `lib/` and uses `*_test.exs` naming (e.g., `test/rr/kf_test.exs`).
- Build artifacts land in `_build/` and release binaries in `burrito_out/`.

## Build, Test, and Development Commands
- `mix deps.get` installs dependencies.
- `mix compile` builds the project.
- `iex -S mix` runs the CLI in an interactive shell for local debugging.
- `mix test` runs the full test suite; `mix test test/rr/kf_test.exs` runs a single file.
- `MIX_ENV=prod mix release` produces Burrito-wrapped binaries in `burrito_out/`.
- `mix format --check-formatted` verifies formatting; `mix format` applies it.

## Coding Style & Naming Conventions
- Use standard Elixir formatting (2-space indentation; `mix format` enforced).
- Test files must end with `_test.exs` and mirror the `lib/` module path.
- Prefer clear, lower_snake_case function names and modules that reflect their domain (`RR.Config.Auth`, `RR.Cmds.Kf`).
- Keep command output and errors centralized in `lib/rr/shell.ex` to preserve CLI consistency.

## Testing Guidelines
- Framework: ExUnit. Mocks use `mox` where applicable.
- To mock a behavior, define callbacks in the behavior module and rely on the runtime `impl()` indirection; tests use the `*.Mock` module to stub callbacks with `expect/3` and `setup :verify_on_exit!` to enforce usage.
- Add or update tests for CLI behavior changes and config/auth edge cases.
- Run `mix test` before submitting; target-specific tests when iterating.

## Commit & Pull Request Guidelines
- Commit history favors short, imperative, lower-case summaries (e.g., “refactor”, “update readme”).
- Use `release: vX.Y.Z` for version bumps.
- PRs should include: a brief problem/solution summary, test commands run, and any user-facing behavior changes. Add screenshots only if CLI output changes meaningfully.

## Configuration & Security Notes
- Local state is stored in `~/.rr/` by default; override with `RR_HOME`.
- Do not commit Rancher tokens or kubeconfigs. Add new secrets to environment variables or local config only.
