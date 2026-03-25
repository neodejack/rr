# Refactor RR into a Layered Architecture

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository stores the ExecPlan guidance in `docs/PLAN.md` rather than `docs/PLANS.md`. Maintain this document in accordance with `docs/PLAN.md`.


## Purpose / Big Picture

The `rr` CLI codebase currently has modules scattered across inconsistent namespaces (`External.*` lives outside `RR`), mixed concerns (a single module defines a struct, validates auth against a remote API, caches results in ETS, and writes to disk), and command modules that combine arg parsing with business logic and file I/O. As the tool grows, this makes it harder to reason about, test, and extend.

After this refactoring, every module in the codebase will belong to one of four clearly defined layers — Config, Providers, Services, CLI — each with a strict dependency direction. A developer looking at a module will immediately know where it sits, what it is allowed to depend on, and what its responsibility is. All existing behavior (commands, output, mocking in tests) will remain identical. The user will notice no difference; the test suite will pass without changes to assertions.

The four layers, from bottom to top:

- **Config** — filesystem paths and application-level constants. Depends on nothing.
- **Providers** — behaviour-based boundaries to external or stateful systems (Rancher HTTP API, JSON settings file, ETS auth cache). Depends on Config for paths. Providers accept data explicitly; they never reach up into Services.
- **Services** — business logic and orchestration. Owns struct definitions. Depends on Config and Providers.
- **CLI** — arg parsing, user prompts, output rendering. Thin wrappers that call Services. Depends on Services.

The dependency rule: arrows point only downward. CLI → Services → Providers → Config. Anything else is a violation.


## Progress

- [x] (2026-03-25 07:58Z) Milestone 1: Providers layer completed. Moved this plan to `docs/exec-plans/active/`, replaced `External.*` with `RR.Providers.*`, added `RR.Providers.AuthCache`, updated tests to use provider mocks, and verified with `mix compile --warnings-as-errors`, `mix test`, `mix format --check-formatted`, and `rg "External\." lib test config`.
- [x] (2026-03-25 08:05Z) Milestone 2: Config layer completed. Renamed `RR.Config` to `RR.Settings`, added `RR.Config.Paths` for home, settings, kubeconfig, and template paths, updated callers and tests, and verified with `mix compile --warnings-as-errors`, `mix test`, and `mix format --check-formatted`.
- [x] (2026-03-25 08:12Z) Milestone 3: Services layer completed. Added `RR.Services.Auth`, `RR.Services.Clusters`, `RR.Services.Kubeconfigs`, and `RR.Services.Aliases`, removed `RR.Config.Auth`, rewired the existing command modules to call services, and verified with `mix compile --warnings-as-errors`, `mix test`, and `mix format --check-formatted`.
- [x] (2026-03-25 08:15Z) Milestone 4: CLI layer completed. Moved the router to `RR.CLI`, renamed `RR.Shell` to `RR.CLI.Output`, moved command modules and tests into the `RR.CLI.*` namespace, removed `RR.Constants`, and verified with `mix compile --warnings-as-errors`, `mix test`, `mix format --check-formatted`, and `rg -n "RR\\.Shell|RR\\.KubeConfig\\b|RR\\.Login\\b|RR\\.List\\b|RR\\.Alias\\b|RR\\.Yo\\b|RR\\.Constants" lib test`.
- [ ] Milestone 5: Cleanup (remove old files, inline RR.Constants, final validation)


## Surprises & Discoveries

- Observation: The repository guidance file is `docs/PLAN.md`, not `docs/PLANS.md` as referenced by the skill and the original draft of this plan.
  Evidence: `find docs -maxdepth 3 -type f | sort` returned `docs/PLAN.md` and `docs/exec-plans/refactor-layered-architecture.md`.

- Observation: Replacing the ETS cache with a mocked provider changed the tests' setup requirements. `start_supervised!/1` used the default `Agent` child id, so repeated setup blocks collided until each agent received a unique `id`.
  Evidence: `mix test` initially failed with `bad child specification, got: {:already_started, ...}` in `test/rr/config/auth_test.exs` and `test/rr/login_test.exs`.

- Observation: The original Milestone 2 stale-reference check was too strict for the actual migration sequence. `RR.Config.Auth` still exists until Milestone 3, so the verification must allow that module while confirming that generic settings and path lookups moved to `RR.Settings` and `RR.Config.Paths`.
  Evidence: `rg "RR\.Config\." lib test | grep -v "RR\.Config\.Paths"` still matched `RR.Config.Auth` after the settings/path refactor.

- Observation: `RR.Services.Kubeconfigs.fetch/2` now asks `RR.Services.Auth` for valid auth before listing clusters, and `RR.Services.Clusters.list/0` also validates auth internally. The second check is satisfied from the auth cache, so this preserves the planned service boundaries without adding another Rancher token lookup.
  Evidence: `mix test` remained green after the service split, including `test/rr/config/auth_test.exs`, which still asserts that repeated auth validation uses the cache.

- Observation: Moving the command modules and output module under `RR.CLI.*` did not require assertion changes in the tests. The test suite continued to pass after updating only module names, aliases, and file locations.
  Evidence: `mix test` passed immediately after the namespace move once the files were reformatted.


## Decision Log

- Decision: Use 4 layers (Config, Providers, Services, CLI) instead of the full 6-layer model from the OpenAI harness engineering post (Types → Config → Repo → Service → Runtime → UI).
  Rationale: This is a small CLI with ~15 modules. A dedicated Domain/Types layer would mean creating files with nothing but a 2-field struct. A Repo layer has no purpose since there is no database or complex data access. A Runtime layer would contain only a single ETS cache module. Collapsing Domain into Services (structs live next to their logic), Repo into Providers, and Runtime into Providers keeps the same separation of concerns without empty abstraction.
  Date/Author: 2026-03-25

- Decision: Make the ETS auth cache a Provider (with behaviour + impl) rather than a plain module.
  Rationale: The codebase already uses the behaviour + `impl()` pattern for `External.Config` and `External.RancherHttpClient`. Making the auth cache follow the same pattern means tests can stub it with Mox instead of manually creating and deleting ETS tables. Consistency in the mocking pattern across all stateful dependencies.
  Date/Author: 2026-03-25

- Decision: Providers must accept auth explicitly (e.g., `get_clusters(auth)`) rather than loading it internally.
  Rationale: The current `External.RancherHttpClient.Impl.rancher_base_req/0` calls `Auth.ensure_valid_auth()` inside itself, meaning the Provider reaches up into the Service layer. This creates a circular dependency (Provider → Auth → Provider). After refactoring, Services load auth and pass it down.
  Date/Author: 2026-03-25

- Decision: Treat `docs/PLAN.md` as the repository-local source of truth for ExecPlan maintenance and note the naming discrepancy inside this plan instead of renaming files mid-refactor.
  Rationale: The repository already checks in `docs/PLAN.md`, and changing the plan-guidance filename would add unrelated churn to an architecture refactor. Recording the discrepancy keeps the plan self-consistent without expanding scope.
  Date/Author: 2026-03-25

- Decision: Keep the shared provider app-env key as `:external_bound` during the refactor instead of renaming it to `:provider_impl`.
  Rationale: The repository already uses one shared switch across environments, and the new provider modules preserve that behavior. Renaming the key would add configuration churn without improving the layered split.
  Date/Author: 2026-03-25

- Decision: Land `RR.Settings` and `RR.Config.Paths` in Milestone 2 while intentionally leaving `RR.Config.Auth` in place until Milestone 3.
  Rationale: Auth logic is still a service concern that will move wholesale in the next milestone. Keeping `RR.Config.Auth` temporarily avoids a half-step where auth helpers bounce between modules before the services layer exists.
  Date/Author: 2026-03-25

- Decision: Keep the old command module names (`RR.KubeConfig`, `RR.Login`, `RR.List`, `RR.Alias`, `RR.Yo`) in Milestone 3 and make them thin wrappers over services, deferring the namespace move to `RR.CLI.*` until Milestone 4.
  Rationale: The service extraction and the CLI namespace move are separate milestones in this plan. Keeping the public command modules stable during the service split reduces churn and keeps the verification surface smaller.
  Date/Author: 2026-03-25

- Decision: Remove `RR.Constants` during the CLI namespace move because it was unused.
  Rationale: The module held only the `:rr` atom and its string form, and there were no remaining callers by the time the router and command modules moved under `RR.CLI.*`. Deleting it during the same namespace pass avoids carrying dead code into the cleanup milestone.
  Date/Author: 2026-03-25


## Outcomes & Retrospective

Milestones 1 through 4 are complete. The provider boundary lives under `lib/rr/providers/`, persisted settings access is isolated in `RR.Settings`, filesystem path logic is centralized in `RR.Config.Paths`, business logic lives in `RR.Services.*`, and the CLI router and commands now live in `RR.CLI.*`. The remaining work is the final cleanup and validation pass.


## Context and Orientation

`rr` is an Elixir CLI tool that manages Rancher-generated kubeconfigs. It is built with Mix, packaged as a native binary via Burrito, and uses `mox` for test mocking. The CLI entry point is `lib/rr.ex`, which routes subcommands (kf, login, list, alias, yo) to their respective modules.

### Current file layout and what each file does

    lib/
      rr.ex                                 # RR — Burrito entry point, command router, help/version
      rr/
        application.ex                      # RR.Application — OTP app start, optionally calls RR.main()
        cli.ex                              # RR.CLI — command router, help, version
        settings.ex                         # RR.Settings — generic persisted settings read/write
        cli/
          output.ex                         # RR.CLI.Output — stdout/stderr rendering
          commands/
            alias.ex                        # RR.CLI.Commands.Alias — arg parsing + alias output
            kf.ex                           # RR.CLI.Commands.Kf — arg parsing + kubeconfig output
            list.ex                         # RR.CLI.Commands.List — arg parsing + table rendering
            login.ex                        # RR.CLI.Commands.Login — arg parsing + prompts
            yo.ex                           # RR.CLI.Commands.Yo — arg parsing + shell integration output
        config/
          paths.ex                          # RR.Config.Paths — home_dir, settings_file, kubeconfig_dir, template paths
        providers/
          auth_cache.ex                     # RR.Providers.AuthCache — cache behaviour
          auth_cache/
            ets.ex                          # RR.Providers.AuthCache.ETS — ETS-backed cache provider
          rancher.ex                        # RR.Providers.Rancher — Rancher API behaviour
          rancher/
            impl.ex                         # RR.Providers.Rancher.Impl — Req-based HTTP calls
          settings_store.ex                 # RR.Providers.SettingsStore — settings persistence behaviour
          settings_store/
            file.ex                         # RR.Providers.SettingsStore.File — JSON settings file provider
        services/
          aliases.ex                        # RR.Services.Aliases — alias persistence and resolution
          auth.ex                           # RR.Services.Auth — %Auth{} and token validation
          clusters.ex                       # RR.Services.Clusters — cluster lookup and matching
          kubeconfigs.ex                    # RR.Services.Kubeconfigs — kubeconfig fetch/save/validation
    test/
      test_helper.exs                       # defines Mox mocks, starts ExUnit
      rr/
        services/
          auth_test.exs                     # tests for RR.Services.Auth
        cli/
          commands/
            kf_test.exs                     # tests for RR.CLI.Commands.Kf
            list_test.exs                   # tests for RR.CLI.Commands.List
            login_test.exs                  # tests for RR.CLI.Commands.Login
            yo_test.exs                     # tests for RR.CLI.Commands.Yo

    config/
      config.exs                            # imports env-specific config
      dev.exs                               # external_bound: Impl, run_cli: true
      prod.exs                              # external_bound: Impl, run_cli: true
      test.exs                              # external_bound: Mock, run_cli: false, RR_HOME override

### How mocking works

All provider boundaries use a behaviour module with a delegating public function and a private `impl/0` function that resolves to either `Impl`, `File`, `ETS`, or `Mock` based on the `:external_bound` app env. In test config, `:external_bound` is set to `Mock`. In `test/test_helper.exs`, `Mox.defmock/2` creates mock modules for each provider behaviour. Tests use `Mox.expect/3` and `Mox.stub/3` to control behaviour.

The current app env key is a single `:external_bound` atom shared by all providers. Each provider constructs its impl module name from its own namespace, for example `Module.concat([RR.Providers.Rancher, Application.get_env(:rr, :external_bound, Impl)])`. This means all providers switch between production implementations and mocks together.

### Templates

`priv/templates/sh.eex` is used by the `kf --sh` command to output an `export KUBECONFIG=` shell snippet. `priv/templates/yo.eex` is used by the `yo` command to output shell integration functions.


## Plan of Work

The refactoring is split into five milestones. Each milestone ends with all existing tests passing. No user-visible behavior changes at any point.


### Milestone 1: Providers Layer

This milestone renames the `External.*` namespace into `RR.Providers.*` and extracts the ETS auth cache into a new provider. At the end, `lib/external/` is deleted, all modules live under `lib/rr/providers/`, and tests pass using the new mock names.

**What changes:**

Create `lib/rr/providers/rancher.ex` as `RR.Providers.Rancher` — this is the behaviour module (currently `External.RancherHttpClient`). It defines the same three callbacks (`get_clusters/1`, `get_kubeconfig/2`, `get_token_info/1`) but the signatures change: every function now takes an `auth` struct as its first argument. The `impl/0` function continues to use the existing shared app env key `:external_bound`.

Create `lib/rr/providers/rancher/impl.ex` as `RR.Providers.Rancher.Impl` — move the implementation from `External.RancherHttpClient.Impl`. Remove the private `rancher_base_req/0` function that internally loads auth. Instead, each function receives auth and builds the Req client inline or via a private helper that takes auth as a parameter.

Create `lib/rr/providers/settings_store.ex` as `RR.Providers.SettingsStore` — this is the behaviour module (currently `External.Config`). Same two callbacks: `read/0`, `write/1`. Keep the same `impl/0` pattern with `:external_bound`.

Create `lib/rr/providers/settings_store/file.ex` as `RR.Providers.SettingsStore.File` — move the implementation from `External.Config.Impl`.

Create `lib/rr/providers/auth_cache.ex` as `RR.Providers.AuthCache` — new behaviour module with three callbacks: `get(key)` returns `{:hit, boolean()} | :miss`, `put(key, boolean())` returns `:ok`, `clear()` returns `:ok`. The `impl/0` function follows the same pattern.

Create `lib/rr/providers/auth_cache/ets.ex` as `RR.Providers.AuthCache.ETS` — move the ETS logic from `RR.Config.Auth` (the `cached_auth_result/1`, `cache_auth_result/2`, `ensure_auth_cache_table/0` functions). The key is a tuple `{hostname, token}`.

Update `config/dev.exs` and `config/prod.exs`: change `:external_bound` to `:provider_impl` (value stays `Impl`).

Update `config/test.exs`: change `:external_bound` to `:provider_impl` (value stays `Mock`).

Update `test/test_helper.exs`: define three mocks:

    Mox.defmock(RR.Providers.Rancher.Mock, for: RR.Providers.Rancher)
    Mox.defmock(RR.Providers.SettingsStore.Mock, for: RR.Providers.SettingsStore)
    Mox.defmock(RR.Providers.AuthCache.Mock, for: RR.Providers.AuthCache)

Update all existing modules and tests that reference `External.RancherHttpClient` or `External.Config` to use the new `RR.Providers.Rancher` and `RR.Providers.SettingsStore` names. Update `RR.Config.Auth` to use `RR.Providers.AuthCache` instead of direct ETS calls.

Delete the entire `lib/external/` directory.

**Verification:** Run `mix test`. All 10 existing tests must pass. Run `mix compile --warnings-as-errors` to confirm no dangling references to `External.*`.


### Milestone 2: Config Layer

This milestone extracts path-related helpers from `RR.Config` into `RR.Config.Paths`, and renames `RR.Config` to `RR.Settings` so that its purpose (persisted key-value settings) is clear and distinct from application config.

**What changes:**

Create `lib/rr/config/paths.ex` as `RR.Config.Paths`. Move `home_dir/0` here from `RR.Config`. Add `kubeconfig_dir/0` (currently a private function in `RR.KubeConfig`), `settings_file/0` (currently computed inside `External.Config.Impl`), and `sh_template_path/0` and `yo_template_path/0` (currently private in `RR.KubeConfig` and `RR.Yo` respectively). This centralizes all filesystem path logic.

Rename `lib/config.ex` to `lib/rr/settings.ex` as `RR.Settings`. It keeps `get/1`, `put/2`, `get_in/1`, `put_in/2` — the generic settings read/write functions. Remove `home_dir/0` (moved to Paths), remove `get_auth/0` and `put_auth/1` (these are auth-specific convenience methods that belong in Services.Auth, to be moved in Milestone 3). Update internal calls from `External.Config.read()` to `RR.Providers.SettingsStore.read()`.

Update `RR.Providers.SettingsStore.File` to use `RR.Config.Paths.settings_file/0` and `RR.Config.Paths.home_dir/0` instead of calling `RR.Config.home_dir/0`.

Update all modules referencing `RR.Config.home_dir/0` to use `RR.Config.Paths.home_dir/0`. Update all modules referencing `RR.Config.get/1`, `RR.Config.put/2`, etc., to use `RR.Settings.*`.

**Verification:** Run `mix test`. All tests pass.


### Milestone 3: Services Layer

This milestone creates the Services layer by extracting business logic from command modules and `RR.Config.Auth` into dedicated service modules. After this milestone, each service module owns its struct definition and business rules, and command modules only contain arg parsing and output rendering.

**What changes:**

Create `lib/rr/services/auth.ex` as `RR.Services.Auth`. This module absorbs everything from `RR.Config.Auth`:
- The `%Auth{}` struct definition (`defstruct [:rancher_hostname, :rancher_token]`) and its `@type t`.
- `get_auth/0` — loads auth from `RR.Settings`.
- `put_auth/1` — saves auth to `RR.Settings`.
- `ensure_valid_auth/0` — loads auth, checks cache via `RR.Providers.AuthCache`, validates via `RR.Providers.Rancher.get_token_info/1`, caches result.
- `check_auth_validity/1` — the renamed `check_auth_validity_from_ets_or_rancher/1`.
- The private `token_valid?/1` function with its expiry-warning side effect (printing to stderr via `RR.Shell` — this is acceptable; the alternative is returning warning messages, which can be done in Milestone 4 if desired).

Delete `lib/config/auth.ex`. Delete `lib/config/` directory (now empty).

Create `lib/rr/services/clusters.ex` as `RR.Services.Clusters`. Define `%RR.Services.Clusters.Cluster{}` with fields `[:id, :name, :kubeconfig]` (currently the struct in `RR.KubeConfig`). Move these functions from `RR.KubeConfig`:
- `list/0` — calls `RR.Providers.Rancher.get_clusters/1` (passing auth) and maps raw data to `%Cluster{}` structs. This is the current `parse_cluster/1`.
- `find_one/2` — takes a list of clusters and a substring, returns `{:ok, cluster}` or `{:error, message}`. This is the current `select_cluster/2`.

Create `lib/rr/services/kubeconfigs.ex` as `RR.Services.Kubeconfigs`. Move these functions from `RR.KubeConfig`:
- `fetch/2` — takes `cluster_name_substring` and `opts` (keyword list with `:overwrite` and `:shell_output` keys). Orchestrates: resolve alias → ensure valid auth → list clusters → select cluster → ensure valid kubeconfig → return path. This is the core of the current `RR.KubeConfig.run/1` minus arg parsing.
- `ensure_valid_kubeconfig/2` — the current private function, takes a cluster and overwrite flag.
- `save_to_file/1`, `kf_valid?/1`, `kubeconfig_file_path/1` — the current private helpers. Use `RR.Config.Paths.kubeconfig_dir/0`.

Create `lib/rr/services/aliases.ex` as `RR.Services.Aliases`. Move these functions from `RR.Alias`:
- `set/2` — takes alias_name and full_name, writes to settings.
- `resolve/1` — takes an alias, returns the resolved name or the original.
- `list/0` — returns the alias map from settings.

**Verification:** Run `mix test`. All tests pass. The test files themselves may need alias/import updates to reference the new module names.


### Milestone 4: CLI Layer

This milestone restructures the command modules into the `RR.CLI` namespace and makes each one a thin wrapper: parse args, call service, render output.

**What changes:**

Create `lib/rr/cli.ex` as `RR.CLI`. Move the command routing logic from `RR.main/0` and `RR.run/1` into this module. `RR.CLI.run/1` takes argv, matches the subcommand, and dispatches to the appropriate `RR.CLI.Commands.*` module. Help and version rendering stay here.

Create `lib/rr/cli/output.ex` as `RR.CLI.Output`. Move `RR.Shell` functions here: `info_stdout/1`, `info_stderr/1`, `error/1`. This is a simple rename.

Create `lib/rr/cli/commands/kf.ex` as `RR.CLI.Commands.Kf`. Keep only arg parsing (`parse_args/1`, `args_definition/0`) and output formatting (`output_kubeconfig_path/2`, `render_help/0`). The `run/1` function parses args, then calls `RR.Services.Kubeconfigs.fetch/2`, then renders the result.

Create `lib/rr/cli/commands/login.ex` as `RR.CLI.Commands.Login`. Keep arg parsing, prompting (`prompt/0`), and confirmation. Call `RR.Services.Auth` for validation and saving.

Create `lib/rr/cli/commands/list.ex` as `RR.CLI.Commands.List`. Keep arg parsing and table rendering. Call `RR.Services.Clusters.list/0` for data.

Create `lib/rr/cli/commands/alias.ex` as `RR.CLI.Commands.Alias`. Keep arg parsing and output. Call `RR.Services.Aliases` for set/resolve/list.

Create `lib/rr/cli/commands/yo.ex` as `RR.CLI.Commands.Yo`. Keep arg parsing. Use `RR.Config.Paths.yo_template_path/0`.

Update `lib/rr.ex` (`RR` module): slim it down to just `main/0` which calls `RR.CLI.run/1` and handles the exit code. Delete `run/1`, `render_help/0`, `render_version/0` from this module.

Delete old files: `lib/cmds/kf.ex`, `lib/cmds/login.ex`, `lib/cmds/list.ex`, `lib/cmds/alias.ex`, `lib/cmds/yo.ex`, `lib/rr/shell.ex`. Delete the `lib/cmds/` directory.

Delete `lib/rr/constants.ex` — inline the cli name atom where needed (it is only used in `RR.Constants.cli_name/0` which appears unused outside of the module itself).

Update test files: rename module references, update aliases. Move test files to mirror the new structure:
- `test/rr/config/auth_test.exs` → `test/rr/services/auth_test.exs`
- `test/rr/kf_test.exs` → `test/rr/cli/commands/kf_test.exs`
- `test/rr/list_test.exs` → `test/rr/cli/commands/list_test.exs`
- `test/rr/login_test.exs` → `test/rr/cli/commands/login_test.exs`
- `test/rr/yo_test.exs` → `test/rr/cli/commands/yo_test.exs`

**Verification:** Run `mix test`. All tests pass. Run `mix compile --warnings-as-errors`.


### Milestone 5: Cleanup and Final Validation

This milestone ensures no stale references, files, or modules remain, and that the full build and test pipeline is green.

**What changes:**

Run `mix compile --warnings-as-errors` and fix any warnings about unused aliases, undefined modules, or deprecated references.

Run `mix format --check-formatted` and fix any formatting issues.

Run `mix test` and confirm all tests pass.

Verify the final directory tree matches:

    lib/
      rr.ex                              # RR — Burrito entry point, delegates to RR.CLI
      rr/
        application.ex                    # RR.Application — unchanged
        cli.ex                            # RR.CLI — command router, help, version
        cli/
          output.ex                       # RR.CLI.Output — info_stdout, info_stderr, error
          commands/
            kf.ex                         # RR.CLI.Commands.Kf
            login.ex                      # RR.CLI.Commands.Login
            list.ex                       # RR.CLI.Commands.List
            alias.ex                      # RR.CLI.Commands.Alias
            yo.ex                         # RR.CLI.Commands.Yo
        config/
          paths.ex                        # RR.Config.Paths — home_dir, kubeconfig_dir, template paths
        settings.ex                       # RR.Settings — generic key/value settings read/write
        providers/
          rancher.ex                      # RR.Providers.Rancher — behaviour
          rancher/
            impl.ex                       # RR.Providers.Rancher.Impl — Req HTTP
          settings_store.ex               # RR.Providers.SettingsStore — behaviour
          settings_store/
            file.ex                       # RR.Providers.SettingsStore.File — JSON file
          auth_cache.ex                   # RR.Providers.AuthCache — behaviour
          auth_cache/
            ets.ex                        # RR.Providers.AuthCache.ETS
        services/
          auth.ex                         # RR.Services.Auth — %Auth{}, validation, expiry
          clusters.ex                     # RR.Services.Clusters — %Cluster{}, list, find
          kubeconfigs.ex                  # RR.Services.Kubeconfigs — fetch, save, validate
          aliases.ex                      # RR.Services.Aliases — set, resolve, list

    test/
      test_helper.exs
      rr/
        services/
          auth_test.exs
        cli/
          commands/
            kf_test.exs
            list_test.exs
            login_test.exs
            yo_test.exs

Confirm no files remain in `lib/external/`, `lib/cmds/`, or `lib/config/`.

Optionally: run `MIX_ENV=prod mix compile` to verify the production build compiles.

**Verification:** `mix compile --warnings-as-errors && mix format --check-formatted && mix test` all succeed.


## Concrete Steps

For each milestone, the working directory is the project root `/Users/zili/code/rr`. The primary commands are:

    mix compile --warnings-as-errors
    mix test
    mix format

Run these after completing each milestone. Expected result: zero warnings, zero failures, zero format violations.

To verify no stale External references remain after Milestone 1:

    rg "External\." lib test config

Expected output: no matches.

To verify no stale RR.Config references remain after Milestone 2 (should only appear in the new RR.Config.Paths):

    rg "RR\.Config\." lib test | grep -v "RR\.Config\.Paths" | grep -v "RR\.Config\.Auth"

Expected output: no matches.

To verify old cmds/ directory is gone after Milestone 4:

    ls lib/cmds/

Expected output: "No such file or directory".


## Validation and Acceptance

After all milestones are complete:

1. `mix test` — all existing tests pass (currently 10 tests across 5 test files). No test assertions change; only module references and aliases are updated.
2. `mix compile --warnings-as-errors` — zero warnings.
3. `mix format --check-formatted` — clean.
4. The CLI behavior is identical: `rr login`, `rr kf <name>`, `rr list`, `rr alias`, `rr yo` all work exactly as before.
5. The dependency direction is strictly Config ← Providers ← Services ← CLI (no upward arrows).


## Idempotence and Recovery

Each milestone is independently verifiable via `mix test`. If a milestone is partially applied and tests fail, the safest recovery is `git checkout .` to revert to the last passing state and re-apply.

The refactoring is purely structural (renaming, moving, splitting modules). No business logic changes. No data migration. No config file format changes. The persisted `~/.rr/config.json` is untouched.


## Artifacts and Notes

Current dependency graph (showing violations the refactoring fixes):

    External.RancherHttpClient.Impl → RR.Config.Auth (provider reaches into service layer)
    RR.Config.Auth → External.RancherHttpClient (service reaches into provider without going through a clean boundary)
    RR.KubeConfig → External.RancherHttpClient (command module directly calls provider)
    RR.Config → External.Config (config module knows about external boundary)

After refactoring, all arrows flow downward:

    RR.CLI.Commands.* → RR.Services.* → RR.Providers.* → RR.Config.Paths


## Interfaces and Dependencies

In `lib/rr/providers/rancher.ex`, define:

    defmodule RR.Providers.Rancher do
      @callback get_clusters(auth :: struct()) :: {:ok, [map()]} | {:error, String.t()}
      @callback get_kubeconfig(auth :: struct(), cluster :: struct()) :: {:ok, struct()} | {:error, String.t()}
      @callback get_token_info(auth :: struct()) :: {:ok, map()} | {:error, atom(), String.t()}
    end

In `lib/rr/providers/settings_store.ex`, define:

    defmodule RR.Providers.SettingsStore do
      @callback read() :: map()
      @callback write(map()) :: :ok | {:error, term()}
    end

In `lib/rr/providers/auth_cache.ex`, define:

    defmodule RR.Providers.AuthCache do
      @callback get(key :: term()) :: {:hit, boolean()} | :miss
      @callback put(key :: term(), valid? :: boolean()) :: :ok
      @callback clear() :: :ok
    end


Revision note (2026-03-25): Activated this plan under `docs/exec-plans/active/` and updated the document after completing Milestone 1 so the recorded file paths, verification commands, discoveries, and decisions match the repository state.
Revision note (2026-03-25): Updated the plan after Milestone 2 to reflect the `RR.Settings` / `RR.Config.Paths` split, document the decision to keep `:external_bound`, and correct the stale-reference verification to allow the still-temporary `RR.Config.Auth` module.
Revision note (2026-03-25): Updated the plan after Milestone 3 to reflect the new `RR.Services.*` modules, the removal of `RR.Config.Auth`, and the fact that the old command modules now act as wrappers pending the CLI namespace move in Milestone 4.
Revision note (2026-03-25): Updated the plan after Milestone 4 to reflect the `RR.CLI.*` namespace move, the `RR.CLI.Output` rename, the relocated tests, and the removal of the unused `RR.Constants` module.
