# Implement Multi-Cluster Profiles

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `docs/PLANS.md`.

## Purpose / Big Picture

After this change, `rr` can hold more than one Rancher credential set at the same time, and the user can choose which one a command should use with `-p` or `--profile`. A user who logs into both a production Rancher environment and a staging Rancher environment can keep both profiles side by side, run `rr list` to see clusters from all saved profiles with a profile column, and run `rr kf -p production cluster-x` to generate a kubeconfig from only the production profile.

The feature is observable in three ways. First, `rr login` must let the user create or update a named profile instead of overwriting one global auth record. Second, `rr list` without `-p` must render a combined table across saved profiles, while `rr list -p <profile>` must narrow to one profile. Third, `rr kf` and `rr alias` must respect profile scoping so the same alias text and the same cluster name can exist under different profiles without colliding.

## Progress

- [x] (2026-03-18 09:31Z) Read `docs/PLANS.md`, `docs/ARCHITECTURE.md`, and `docs/product-specs/multi-cluster-profiles.md`, then inspected the current auth, alias, list, kubeconfig, config, and Rancher boundary code paths.
- [x] (2026-03-18 09:42Z) Implemented `RR.Config.Profiles` with normalized `"profiles"` storage, legacy migration from root auth and alias keys into `"default"`, and focused ExUnit coverage for profile helpers and alias resolution.
- [x] (2026-03-18 09:45Z) Refactored `RR.Config.Auth` and `External.RancherHttpClient` to use explicit profile-aware auth structs, updated the current `login`, `list`, and `kf` flows to target `"default"` through the new boundary, and added focused auth/login/list coverage for the new cache and client signatures.
- [x] (2026-03-18 09:51Z) Updated `rr login` and `rr list` for profile-aware flows: `login` now supports `-p`, create-vs-update selection, and profile-specific overwrite prompts; `list` now supports `-p`, validates missing profiles early, and renders a combined `PROFILE` table when no profile is specified.
- [ ] Update `rr alias` and `rr kf` to accept `-p` / `--profile` and follow the product-spec flows when `-p` is omitted.
- [ ] Make alias lookup, cluster search, and kubeconfig cache paths profile-aware.
- [ ] Add focused ExUnit coverage for profile storage, login flows, list rendering, alias scoping, kubeconfig path selection, and ambiguous cross-profile matches.
- [ ] Run focused tests during implementation, then finish with `just check` and one manual `RR_HOME` end-to-end validation flow.

## Surprises & Discoveries

- Observation: the current Rancher client cannot target a specific auth context because `External.RancherHttpClient.get_clusters/0` and `External.RancherHttpClient.get_kubeconfig/1` fetch auth internally through `RR.Config.Auth.ensure_valid_auth/0`.
  Evidence: `lib/external/rancher_http_client.ex` defines zero-argument `get_clusters/0`, and `lib/external/rancher_http_client/impl.ex` builds the `Req` client in `rancher_base_req/0`.

- Observation: kubeconfig cache files are keyed only by cluster name today, so two profiles that contain the same cluster name would overwrite or reuse the same local file.
  Evidence: `lib/cmds/kf.ex` writes to `Path.join(RR.Config.home_dir(), "kubeconfigs")` and `kubeconfig_file_path/1` uses only `%RR.KubeConfig{name: name}`.

- Observation: aliases are stored in one global map, which blocks the product requirement that the same alias text may exist under multiple profiles.
  Evidence: `lib/cmds/alias.ex` writes to `Config.put_in([Access.key("alias", %{}), alias_name], full_name)` and resolves through `Config.get_in(["alias", alias])`.

- Observation: test coverage is strongest around auth and login, while kubeconfig and alias behavior are either missing or skeletal.
  Evidence: `test/rr/login_test.exs` and `test/rr/config/auth_test.exs` contain substantial coverage, `test/rr/kf_test.exs` is still a placeholder, and there is no `test/rr/alias_test.exs`.

- Observation: normalizing even an empty config into `%{"profiles" => %{}}` makes the on-disk shape stable and lets later code assume the top-level `"profiles"` key always exists after the first profile-store read.
  Evidence: `test/rr/config/profiles_test.exs` now asserts that `RR.Config.Profiles.state/0` rewrites `%{}` into the explicit multi-profile shape on first read.

- Observation: keeping `RR.Config.get_auth/0` and `RR.Config.put_auth/1` as thin compatibility wrappers over the `"default"` profile lets the refactor land without breaking existing command tests while the CLI flags and prompts are still single-profile.
  Evidence: `test/rr/login_test.exs` and `test/rr/list_test.exs` now pass while `RR.Login`, `RR.List`, and `RR.KubeConfig` are already calling the explicit-auth Rancher boundary with `%RR.Config.Auth{profile_name: "default", ...}`.

- Observation: `Owl.IO.select/2` autoselects a single-item list, which keeps the update-existing-profile branch terse when only one profile exists and made the login tests simpler to drive deterministically.
  Evidence: the updated `test/rr/login_test.exs` no longer needs a second numeric selection when only `"default"` exists because `Owl.IO.select/2` prints `Autoselect: default`.

## Decision Log

- Decision: normalize persisted state around a top-level `"profiles"` map and migrate legacy root keys into an explicit `"default"` profile the first time legacy state is read or written.
  Rationale: existing users should not have to hand-edit `~/.rr/config.json` before the new release becomes usable. The migration output is explicit and stable, while new logic no longer relies on a hidden current profile.
  Date/Author: 2026-03-18 / Codex

- Decision: add a dedicated `RR.Config.Profiles` module to own profile persistence, alias persistence, and legacy migration, while keeping `RR.Config` as the raw config file helper and `RR.Config.Auth` as the validation layer.
  Rationale: the current `RR.Alias` module mixes CLI behavior with storage, and the current `RR.Config.Auth` module should stay focused on building and validating auth structs instead of becoming the entire persistence API.
  Date/Author: 2026-03-18 / Codex

- Decision: change the Rancher HTTP boundary so cluster listing and kubeconfig generation take an explicit `%RR.Config.Auth{}` argument.
  Rationale: cross-profile `list` and `kf` need to iterate over more than one saved auth, which is not possible while the HTTP boundary reaches back into global config.
  Date/Author: 2026-03-18 / Codex

- Decision: store aliases under each profile record and store kubeconfigs under per-profile directories.
  Rationale: both alias texts and cluster names must be reusable across profiles without overwriting one another or resolving in the wrong auth context.
  Date/Author: 2026-03-18 / Codex

- Decision: when a profile-less command fans out across multiple saved profiles, do not silently skip auth or API failures. Accumulate those failures and return one combined error that names each failing profile and reason.
  Rationale: partial output would hide broken credentials and make ambiguous matching harder to reason about. A combined error keeps the behavior explicit while still checking every targeted profile.
  Date/Author: 2026-03-18 / Codex

- Decision: treat ambiguous alias lookup without `-p` as the same class of ambiguity as an ambiguous cluster-name lookup, and include the required guidance line `please use -p auth_name to specify the cluster`.
  Rationale: once aliases become profile-scoped, the same alias text is allowed in more than one profile. The command needs deterministic guidance instead of picking one profile implicitly.
  Date/Author: 2026-03-18 / Codex

## Outcomes & Retrospective

The first three implementation slices are complete. The repository now has the profile store, the explicit-auth Rancher boundary, and profile-aware `login`/`list` flows. Users can already save multiple named profiles and list clusters across them with a visible `PROFILE` column. The remaining work is concentrated in `alias` and `kf`, where profile-aware alias resolution, ambiguity handling, and kubeconfig path scoping still need to be applied.

The main residual risk is scope expansion while reshaping the config layout. The implementation should stay disciplined about changing only the four user-facing commands named in the product spec plus the supporting persistence and Rancher boundary code they depend on.

## Context and Orientation

`rr` is a small Elixir CLI. `lib/rr.ex` dispatches the top-level command name to one command module. The profile-aware work lives mainly in `lib/cmds/login.ex`, `lib/cmds/list.ex`, `lib/cmds/kf.ex`, and `lib/cmds/alias.ex`.

Local state is stored as JSON under `RR.Config.home_dir/0`, which resolves to `RR_HOME` when present or `~/.rr` otherwise. `lib/external/config/impl.ex` reads and writes `config.json` in that directory. Today that JSON is effectively flat: auth lives at `"rancher_hostname"` and `"rancher_token"`, and aliases live under `"alias"`. There is no current concept of more than one auth record.

`lib/config/auth.ex` defines `%RR.Config.Auth{}` and validates Rancher tokens, with an ETS cache named `:rr_auth_cache` to avoid repeated token checks. The cache key currently uses only `{hostname, token}`. That is safe for one global auth, but it should become profile-aware once the same hostname and token pair can be saved under more than one profile name and once commands enumerate many profiles in one run.

`lib/external/rancher_http_client.ex` and `lib/external/rancher_http_client/impl.ex` are the boundary between command modules and Rancher HTTP. That boundary is important because tests replace it with Mox mocks. The current interface assumes one implicit auth by calling back into `RR.Config.Auth.ensure_valid_auth/0` inside the runtime implementation, so multi-profile command logic cannot be implemented cleanly without changing this boundary.

`lib/cmds/kf.ex` owns cluster name matching, kubeconfig generation, and kubeconfig file writes. A “kubeconfig” in this repository is the YAML file that `kubectl` uses for cluster access. `RR.KubeConfig` considers an existing kubeconfig reusable only if `kubectl get pods --kubeconfig=...` exits successfully. Because `kubeconfig_file_path/1` uses only the cluster name today, profile support must also change the local cache layout or one profile will trample another when cluster names overlap.

The existing tests most relevant to this work are `test/rr/login_test.exs`, `test/rr/list_test.exs`, and `test/rr/config/auth_test.exs`. `test/rr/kf_test.exs` exists but is only a placeholder, and no alias test file exists yet. The implementation should add the missing focused tests rather than relying on manual checks alone.

In this plan, a “profile” means one named saved Rancher auth context, including the Rancher hostname, the Rancher token, and the aliases that should only be meaningful inside that auth context. A “profile-aware command” means one of `login`, `list`, `kf`, or `alias`, because those are the only commands in scope for this feature.

## Plan of Work

Start by introducing a profile persistence layer that sits above the existing raw config helper. Add `lib/config/profiles.ex` as `RR.Config.Profiles`. That module should read the map returned by `External.Config.read/0`, normalize it into the new shape, and expose small operations such as listing profile names, fetching one profile, writing one profile, listing aliases for one or all profiles, and performing the legacy migration. The normalized on-disk shape should be:

    %{
      "profiles" => %{
        "default" => %{
          "rancher_hostname" => "https://rancher.example",
          "rancher_token" => "token-123:abc",
          "aliases" => %{"prod" => "production-cluster"}
        },
        "staging" => %{
          "rancher_hostname" => "https://staging.example",
          "rancher_token" => "token-456:def",
          "aliases" => %{}
        }
      }
    }

The migration rule should be simple and idempotent. If the config already contains `"profiles"`, leave it alone. If it only contains the legacy `"rancher_hostname"`, `"rancher_token"`, and optional `"alias"` keys, rewrite it into `"profiles" => %{"default" => ...}` and drop the legacy top-level keys from the normalized output. Re-running the migration against already-normalized state must be a no-op.

Once profile storage exists, reshape `RR.Config.Auth` so it works with named profiles instead of one global record. Add `profile_name` to `%RR.Config.Auth{}`. Replace `get_auth/0`, `put_auth/1`, and `ensure_valid_auth/0` with profile-aware forms that either accept a profile name or enumerate all saved profiles. The auth cache key should become `{profile_name, hostname, token}` so token validity cached for one saved profile never bleeds into a different profile entry. Keep the current warning and expiry behavior unchanged once a concrete auth struct has been selected.

Then refactor the Rancher boundary to be explicit. In `lib/external/rancher_http_client.ex`, change the callbacks and public functions so `get_clusters/1` takes `%RR.Config.Auth{}` and `get_kubeconfig/2` takes `%RR.Config.Auth{}` plus `%RR.KubeConfig{}`. In `lib/external/rancher_http_client/impl.ex`, replace `rancher_base_req/0` with `rancher_base_req/1` and remove any remaining reach-back into global auth lookup. After this change, command modules are responsible for selecting and validating the profile before making Rancher calls.

With the storage and boundary changes in place, update the command modules. In `lib/cmds/login.ex`, add `-p` and `--profile` parsing. `rr login -p <profile>` should skip profile selection and go straight to the credential prompts for that profile. `rr login` without `-p` should inspect the saved profile list through `RR.Config.Profiles.names/0`. If there are no saved profiles, prompt only for a new profile name, then prompt for hostname and token. If profiles exist, use `Owl.IO.select/2` first to choose between “update existing profile” and “create new profile”; the update branch should prompt the user to select an existing profile, while the create branch should ask for a new profile name and reject blank or duplicate names before continuing. The existing “you already have a valid auth config” confirmation should become profile-specific and should only inspect the selected profile.

Update `lib/cmds/list.ex` next. Add `-p` and `--profile` parsing and a small helper that either resolves one named profile or all saved profiles. When `-p` is provided and the profile does not exist, fail immediately before any network calls. When `-p` is omitted and no profiles exist, return a clear “no profiles configured” message that points the user at `rr login`. When listing one profile, keep the current two-column output. When listing all profiles, fetch clusters from every saved profile, annotate each row with the owning profile name, and render a table with a `PROFILE` column so same-named clusters remain understandable.

Refactor `lib/cmds/alias.ex` to move all alias storage through `RR.Config.Profiles`. Add `-p` and `--profile` for set operations, keep `--list`, and group the `--list` output by profile. When the user runs `rr alias <alias> <full-name>` without `-p`, prompt for a profile with `Owl.IO.select/2`; if there are no profiles, fail with a clear message that the user must run `rr login` first. Replace the current `resolve/1` helper with a profile-aware resolver that can report one of three outcomes: no alias hit, exactly one profile-scoped alias hit, or ambiguous alias hits across more than one profile.

Refactor `lib/cmds/kf.ex` last, because it depends on every previous change. Add `-p` and `--profile` parsing. Extend `%RR.KubeConfig{}` with `profile_name` so the selected cluster carries its owning profile all the way through matching and kubeconfig path creation. If `-p` is provided, fail immediately when the profile is missing, then resolve aliases only inside that profile and fetch clusters only for that profile. If `-p` is omitted, ask the alias resolver whether the input token is a profile-scoped alias. One alias hit should narrow the search to that profile before cluster matching. Multiple alias hits should return an ambiguity error naming the matching profiles and including the required line `please use -p auth_name to specify the cluster`. If the input is not an alias, fetch clusters across all profiles, annotate each cluster with its profile name, and run substring matching across the combined set. One match should proceed, zero matches should report that no profile contained the requested cluster, and multiple matches should list each `{profile, cluster}` pair and instruct the user to tighten the name, use `-p`, or use `rr alias`.

When updating `RR.KubeConfig`, also change the local kubeconfig cache layout so profile and cluster names no longer collide. The safest path within the current repo shape is `~/.rr/kubeconfigs/<profile_name>/<cluster_name>`, created through `RR.Config.home_dir/0` and `File.mkdir_p/1`. Keep the existing reuse semantics: if the file at that profile-scoped path exists and `kubectl get pods --kubeconfig=...` succeeds, reuse it unless `--new` is set. Only the path key changes.

Finally, update help text and tests. `lib/rr.ex` should keep the top-level dispatcher aligned with the command modules and should include `alias` in the main help output, since alias behavior is central to this feature. The command-specific help text in `login`, `list`, `kf`, and `alias` should show the new profile flags and the no-profile behavior. In tests, add one new file for profile storage and one new file for alias command behavior, then expand the existing login, list, auth, and kubeconfig tests to cover the new semantics. Clear the ETS cache between auth-related examples exactly as the existing tests do now.

## Concrete Steps

Work from `/Users/zilizhang/code/sre/rr`.

Start by implementing the profile store and auth refactor, then run focused tests after each slice:

    just test-target test/rr/config/profiles_test.exs
    just test-target test/rr/config/auth_test.exs
    just test-target test/rr/login_test.exs

After the Rancher boundary changes and the `list` command updates, run:

    just test-target test/rr/list_test.exs

After the alias and kubeconfig command changes, run:

    just test-target test/rr/alias_test.exs
    just test-target test/rr/kf_test.exs

When the focused tests pass, run formatting and the standard local verification pass:

    just format
    just check

Do one manual end-to-end smoke test in a temporary home directory so the feature is exercised without touching a real `~/.rr`:

    export RR_HOME="$(mktemp -d)"
    mix run --no-halt -- login -p prod
    mix run --no-halt -- login -p stage
    mix run --no-halt -- list
    mix run --no-halt -- alias -p prod prod-api production-api
    mix run --no-halt -- kf prod-api

The expected manual behavior is that the second `login` does not overwrite the first profile, `list` prints a `PROFILE` column, and `kf prod-api` either resolves directly inside the `prod` profile or prints a profile-specific ambiguity message if the alias text was duplicated.

## Validation and Acceptance

Acceptance is behavior, not just passing compilation. A completed implementation must demonstrate all of the following:

`rr login` can save at least two profiles side by side in `RR_HOME/config.json`, and re-running `rr login` without `-p` lets the user choose between updating an existing profile and creating a new one.

`rr list -p profile_a` calls Rancher only for `profile_a` and prints only clusters from that profile. `rr list` without `-p` prints clusters from all saved profiles and includes a visible `PROFILE` column in the table.

`rr kf -p profile_a cluster-x` searches only inside `profile_a`, while `rr kf cluster-x` searches across all profiles and succeeds only when there is one total match. When there are multiple matches, the error output names both the cluster and the profile for each match and includes the guidance line `please use -p auth_name to specify the cluster`.

`rr alias -p profile_a short full-name` saves the alias only for `profile_a`, `rr alias --list` prints aliases grouped by profile, and `rr kf short` uses the alias’s profile scope instead of searching unrelated profiles.

Passing `-p does-not-exist` to `rr list`, `rr kf`, or `rr alias` fails before any prompt, network call, alias lookup, cluster lookup, or kubeconfig write. The tests should assert that the Rancher mock was not called in those paths.

The focused test files for profile storage, login, list, alias, kubeconfig, and auth all pass, followed by a clean `just check`.

## Idempotence and Recovery

The profile-store migration must be idempotent. Reading or writing a config that already contains `"profiles"` must not rewrite it into a different shape. A failed run during development should be safe to retry because the implementation only adds or rewrites JSON under `RR_HOME/config.json` and kubeconfig files under `RR_HOME/kubeconfigs/`.

Use `RR_HOME` pointing at `mktemp -d` for manual verification so experiments do not touch a developer’s real Rancher tokens or kubeconfigs. If you must test against a real home directory, copy `~/.rr/config.json` first and restore it manually if the migration logic is still under development.

The kubeconfig path change is also idempotent. Re-running `rr kf` for the same profile and cluster should reuse the same profile-scoped file unless `--new` is set or the existing file fails the `kubectl` validity check.

## Artifacts and Notes

Expected combined config shape after two logins and one alias:

    {
      "profiles": {
        "prod": {
          "rancher_hostname": "https://prod.example",
          "rancher_token": "token-prod:abc",
          "aliases": {
            "prod-api": "production-api"
          }
        },
        "stage": {
          "rancher_hostname": "https://stage.example",
          "rancher_token": "token-stage:def",
          "aliases": {}
        }
      }
    }

Expected `rr list` table shape when more than one profile is saved:

    PROFILE  NAME        ID
    -------  ----------  ------
    prod     production  c-prod
    stage    staging     c-stage

Expected ambiguity transcript for the same cluster name under two profiles:

    more than one matches were found for the cluster name 'api'
    these matches are found:
      prod -> api
      stage -> api
    please use -p auth_name to specify the cluster
    or narrow the cluster name / use rr alias

## Interfaces and Dependencies

In `lib/config/profiles.ex`, define a new `RR.Config.Profiles` module with repository-local helpers along these lines:

    defmodule RR.Config.Profiles do
      @spec state() :: map()
      @spec names() :: [String.t()]
      @spec get(String.t()) :: {:ok, map()} | {:error, String.t()}
      @spec put(String.t(), RR.Config.Auth.t()) :: :ok | {:error, term()}
      @spec exists?(String.t()) :: boolean()
      @spec aliases(String.t()) :: map()
      @spec aliases_by_profile() :: %{String.t() => map()}
      @spec put_alias(String.t(), String.t(), String.t()) :: :ok | {:error, term()}
      @spec resolve_alias(String.t()) ::
              :miss
              | {:ok, %{profile_name: String.t(), cluster_name: String.t()}}
              | {:error, :ambiguous, [%{profile_name: String.t(), cluster_name: String.t()}]}
    end

`RR.Config.Profiles` should be the only place that knows the exact persisted JSON shape and the legacy migration rule.

In `lib/config/auth.ex`, the auth struct and public API should end this work in a profile-aware form:

    defmodule RR.Config.Auth do
      defstruct [:profile_name, :rancher_hostname, :rancher_token]

      @spec get_auth(String.t()) :: {:ok, t()} | {:error, String.t()}
      @spec put_auth(String.t(), t()) :: :ok | {:error, term()}
      @spec ensure_valid_auth(String.t()) :: {:ok, t()} | error()
      @spec all_auths() :: [t()]
    end

The validation rules and token-warning behavior should stay the same once a specific auth has been selected.

In `lib/external/rancher_http_client.ex`, change the callbacks and wrappers to explicit-auth forms:

    @callback get_clusters(RR.Config.Auth.t()) :: {:ok, [map()]} | {:error, String.t()}
    @callback get_kubeconfig(RR.Config.Auth.t(), RR.KubeConfig.t()) ::
      {:ok, RR.KubeConfig.t()} | {:error, String.t()}

`get_token_info/1` should remain unchanged because it already receives an auth struct explicitly.

In `lib/cmds/kf.ex`, update `%RR.KubeConfig{}` to include `:profile_name` and ensure `kubeconfig_file_path/1` returns `Path.join([RR.Config.home_dir(), "kubeconfigs", profile_name, name])`.

In tests, keep using the `External.Config` and `External.RancherHttpClient` behaviors through Mox. The command tests should assert both output and call counts so the “fail immediately when profile is missing” requirement is proven, not assumed.

## Change Note

Created the initial ExecPlan from `docs/product-specs/multi-cluster-profiles.md` and the current repository state on 2026-03-18. The plan records the concrete config migration, Rancher boundary refactor, profile-scoped alias storage, and kubeconfig path changes needed so later implementation work can proceed without rediscovering these constraints.

Updated on 2026-03-18 after landing the first implementation slice. The document now records the completed profile-store work, the decision to normalize empty configs into an explicit `"profiles"` map, and the fact that focused profile-store tests now exist and pass.

Updated again on 2026-03-18 after landing the explicit-auth refactor. The plan now records that `RR.Config.Auth`, the Rancher HTTP boundary, and the current default-profile command paths all use explicit auth structs, while the next work item remains the profile-aware CLI flow itself.

Updated again on 2026-03-18 after landing the `login` and `list` command slice. The progress checklist now splits the remaining user-facing work so the outstanding `alias`/`kf` profile behavior and kubeconfig path changes are explicit.
