# Architecture

`rr` is a small Elixir CLI for Rancher-backed Kubernetes access. It authenticates against a Rancher server, lists available clusters, generates kubeconfig files on demand, and stores the resulting local state under a per-user home directory. The system is intentionally narrow: one command dispatcher, a handful of command modules, and two external boundaries for persistence and Rancher HTTP.

## Code Map

`lib/rr.ex` is the entrypoint and command router. `RR.run/1` maps top-level CLI arguments to command modules, while `RR.main/0` wraps execution in consistent exit-code and error handling.

`lib/cmds/` contains the user-facing workflows. `RR.Login` prompts for Rancher credentials and validates them before saving. `RR.List` renders the cluster table. `RR.KubeConfig` resolves aliases, fetches cluster metadata, generates kubeconfigs, and writes them to disk. `RR.Alias` stores name shortcuts in config. `RR.Yo` renders shell integration from an EEx template.

`lib/config.ex` and `lib/config/auth.ex` are the local state layer. `RR.Config` owns the effective home directory and simple key/value access. `RR.Config.Auth` builds the auth struct, validates tokens, and keeps a short-lived in-memory ETS cache named `:rr_auth_cache` so repeated validations do not keep hitting Rancher.

`lib/external/` is the main boundary layer. `External.Config` abstracts config file reads and writes. `External.RancherHttpClient` abstracts Rancher API calls for cluster lookup, kubeconfig generation, and token inspection. The `impl.ex` files provide the default runtime implementations. Tests replace these boundaries through `Application.get_env(:rr, :external_bound, ...)` and the Mox mocks declared in `test/test_helper.exs`.

`priv/templates/` holds shell-facing snippets. `priv/templates/sh.eex` renders the `export KUBECONFIG=...` output for `rr kf --sh`, and `priv/templates/yo.eex` renders the helper function emitted by `rr yo`.

`test/` mirrors the runtime layout. Most useful coverage today is around auth and login behavior, including cache handling and token-expiry edge cases. That makes the auth/config boundary the first place to look when changing login behavior.

## Important Entities

`%RR.Config.Auth{}` is the in-memory representation of Rancher credentials. `%RR.KubeConfig{}` carries the Rancher cluster id, human-readable name, and fetched kubeconfig contents. `External.RancherHttpClient.get_token_info/1` returns a plain map with `expired`, `enabled`, `created_ts`, and `ttl`, and `RR.Config.Auth` uses those fields to decide whether a token is still acceptable.

## Invariants And Boundaries

Keep command output flowing through `RR.Shell` so stdout and stderr stay consistent across commands.

Preserve the `External.*` behavior boundary when adding I/O or HTTP work. If new side effects bypass those modules, the current Mox-based tests become harder to isolate.

`RR.Config.home_dir/0` is the single source of truth for local state placement. Anything persisted for end users should stay under that directory so `RR_HOME` remains a safe override for tests and manual experiments.

`RR.KubeConfig` is the only place that writes generated kubeconfig files, and it treats an existing file as valid only if `kubectl get pods --kubeconfig=...` succeeds. That means kubeconfig behavior depends on both Rancher responses and the local `kubectl` binary.

## Cross-Cutting Concerns

The application starts an otherwise empty supervisor in `RR.Application`; there are no background workers or long-lived processes to coordinate. Most behavior is request/response CLI work with local file writes.

Error handling is user-facing rather than telemetry-heavy. Commands typically return `:ok` or `{:error, message}`, `RR.main/0` converts that into an exit code, and `RR.Shell.error/1` prints the final message.

Release packaging is handled through Burrito in `mix.exs` and `.github/workflows/release.yml`. Operational build notes such as `rr maintenance uninstall` matter for local binary testing, but they are outside the normal source verification path.
