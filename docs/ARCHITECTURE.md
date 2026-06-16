# Architecture

`rr` is an Elixir CLI for authenticating against Rancher, discovering clusters, and materializing kubeconfig-oriented shell workflows. The repository is intentionally small, so the main architectural value is knowing which layer owns parsing, business rules, and side effects.

## Bird's-Eye View

The runtime path is: OS entrypoint -> CLI parsing -> command action execution -> services -> providers. The CLI layer turns argv into a typed invocation. Service modules apply repository rules such as auth validation, cluster lookup, and kubeconfig generation. Provider modules isolate side effects such as terminal IO, file-backed settings, auth caching, and Rancher HTTP calls.

The repository also carries a packaging surface alongside the application code. Burrito builds release binaries, while the `just dev ...` workflows create isolated macOS and Linux shells for testing packaged behavior without mutating the developer's real `~/.rr` state.

## Coarse Codemap

- `lib/rr.ex` is the CLI entrypoint used by the packaged executable. It delegates to `RR.CLI` and routes terminal errors through `RR.Providers.Terminal`.
- `lib/rr/application.ex` starts the OTP application and provider-backed runtime pieces.
- `lib/rr/cli.ex` handles top-level argv dispatch, built-in help/version behavior, and parse-error rendering.
- `lib/rr/cli/arg_parser.ex`, `lib/rr/cli/invocation.ex`, and `lib/rr/cli/parse_error.ex` define the parsing support types used across commands.
- `lib/rr/cli/commands/` contains one module per user-facing command such as `login`, `list`, `kf`, `alias`, and `yo`. New commands should be added here, with mirrored tests under `test/rr/cli/commands/`.
- `lib/rr/services/` contains the application logic shared by commands. If a change is about Rancher auth, cluster selection, kubeconfig generation, or alias behavior, it usually belongs here.
- `lib/rr/providers/` contains side-effect boundaries. Each provider exposes callbacks and delegates to an `Impl` module through runtime indirection so tests can swap implementations.
- `lib/rr/settings.ex` and `lib/rr/config/paths.ex` define the persistent config surface and the `RR_HOME`-aware path rules.
- `priv/templates/` contains shell-oriented templates used when commands emit snippets such as `export KUBECONFIG=...`.
- `test/` mirrors the runtime layout. Command tests live under `test/rr/cli/commands/`, service tests under `test/rr/services/`, and provider/mock tests under `test/rr/providers/`.
- `scripts/dev/`, `Dockerfile.dev`, and `dev.just` support the isolated dev-shell workflow.
- `.github/workflows/release.yml` is the release pipeline for tagged builds and published Burrito artifacts.

## Important Boundaries And Invariants

- Keep CLI parsing and user-command dispatch in the `RR.CLI` layer. Avoid pushing argv handling down into services.
- Keep domain logic in `lib/rr/services/`. Commands should stay thin and primarily translate parsed actions into service calls.
- Keep side effects behind provider modules in `lib/rr/providers/`. This is how the repo preserves testability for terminal IO, HTTP access, cache reads, and settings persistence.
- Route user-visible terminal output through `RR.Providers.Terminal` rather than calling IO modules directly from arbitrary places.
- Treat `RR_HOME` and `RR.Config.Paths` as the source of truth for on-disk state. Avoid hard-coding `~/.rr` paths outside the config/path layer.

## Cross-Cutting Concerns

- Provider changes have an extra documentation step: `docs/DESIGN.md` points provider work to `docs/design/providers.md`.
- Release and dev-shell behavior depend on Burrito, Podman, and the scripts under `scripts/dev/`; CLI-only tests are not enough if you change packaging or shell bootstrapping.
- The repo uses ExecPlans for larger work under `docs/exec-plans/`, with the format defined in `docs/PLANS.md`.
