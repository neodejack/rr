# Align Multi-Cluster Profiles With The Revised Product Spec

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `docs/PLANS.md`.

## Purpose / Big Picture

`rr` already supports more than one Rancher auth profile, but the revised product spec changes the contract in several important ways. The remaining work is not “add profiles”; it is “make the existing multi-profile implementation behave exactly like the new spec.” In particular, alias creation must become fully interactive, alias text must be globally unique across all profiles, and user-facing flows must stop implying a single default auth context except when migrating truly old config.

After this change, a user can run `rr login` to create or update named profiles, run `rr list` without `-p` to see clusters across profiles, run `rr kf` without `-p` to search across profiles with actionable ambiguity errors, and run `rr alias` with no positional alias arguments. Instead, `rr alias` will ask the user to choose a profile, enter alias text, and select one cluster from that profile. The observable proof is that one alias string resolves to exactly one `{profile, cluster}` target everywhere in the CLI.

## Progress

- [x] (2026-03-19 10:16Z) Read `docs/PLANS.md`, `docs/ARCHITECTURE.md`, the revised `docs/product-specs/multi-cluster-profiles.md`, the existing ExecPlan, and the current `login` / `list` / `alias` / `kf` / config / test code to map the spec onto the current repository state.
- [x] (2026-03-19 10:16Z) Rewrote this ExecPlan so it starts from the actual codebase, where profile-aware login, list, and kubeconfig flows already exist, instead of assuming profile support still needs to be built from scratch.
- [x] (2026-03-20 03:20Z) Moved the ExecPlan from `docs/exec-plans/todo/` to `docs/exec-plans/active/` and implemented Milestone 1 in `RR.Config.Profiles`, including cross-profile alias write rejection, same-profile overwrite support, and defensive duplicate-alias detection for malformed config.
- [x] (2026-03-20 03:45Z) Replaced positional alias creation with an interactive `rr alias` flow that picks a profile, prompts for alias text, fetches clusters only after ownership checks, confirms same-profile overwrites, and keeps `--list` as a local-config operation.
- [x] (2026-03-20 04:05Z) Tightened `rr kf` around the new alias contract by relying on `resolve_alias/1` as a strict two-outcome API, and extended focused coverage so alias hits stay profile-scoped and malformed duplicate local alias state raises before Rancher calls.
- [x] (2026-03-20 04:35Z) Ran the focused test targets from this plan (`profiles`, `alias`, `kf`, `login`, `list`), fixed the last stale help assertion in `test/rr/rr_test.exs`, and passed `just check`.
- [x] (2026-03-20 04:39Z) Completed a mock-backed smoke run in a temporary `RR_HOME` under `MIX_ENV=test` that exercised `RR.List.run/1`, the interactive `RR.Alias.run/1` flow, `RR.Alias.run(["--list"])`, and `RR.KubeConfig.run/1` without touching real Rancher state.

## Surprises & Discoveries

- Observation: the repository already contains most of the profile-aware infrastructure the old ExecPlan described as future work.
  Evidence: `lib/cmds/login.ex` already parses `-p` and prompts for create-versus-update, `lib/cmds/list.ex` already renders a combined table with `PROFILE`, and `lib/cmds/kf.ex` already fans out across saved profiles and writes kubeconfigs under `RR_HOME/kubeconfigs/<profile>/<cluster>`.

- Observation: the main gap is `rr alias`, not profile storage.
  Evidence: `lib/cmds/alias.ex` still requires positional `<cluster_alias> <cluster_full_name>` arguments and never calls Rancher to let the user choose from live clusters.

- Observation: alias resolution still exposes a handled duplicate-alias branch, which now conflicts with the revised spec’s global uniqueness invariant.
  Evidence: `lib/config/profiles.ex` stores aliases under each profile and `resolve_alias/1` explicitly returns `{:error, :ambiguous, matches}` when the same alias text appears in more than one profile.

- Observation: the repository still carries compatibility helpers around a `"default"` profile even though the revised spec rejects a hidden current-profile concept.
  Evidence: `lib/config.ex` exposes `get_auth/0` and `put_auth/1` as thin wrappers over profile `"default"`, and `lib/config/migrations/v0_to_current.ex` migrates legacy root auth into `"default"`.

- Observation: the current test suite already proves some important revised-spec behavior and should be preserved rather than rewritten wholesale.
  Evidence: `test/rr/list_test.exs` already asserts early failure for a missing `-p` profile, and `test/rr/kf_test.exs` already covers cross-profile ambiguity guidance and profile-scoped kubeconfig paths.

- Observation: the existing plan text conflicted on how malformed duplicate aliases should be handled on read.
  Evidence: the Progress section asked for a defensive read path, while the earlier Decision Log and `Plan of Work` text described crashing through unmatched pattern handling.

- Observation: `Owl.IO.select/2` autoselects a single cluster result, which keeps the new alias flow terse when one profile has only one cluster.
  Evidence: the rewritten `test/rr/alias_test.exs` can drive the no-`-p` happy path with only profile selection and alias-text input when the chosen profile exposes one cluster.

- Observation: `config/test.exs` forces `RR_HOME` to `~/.rr/test`, so a smoke run that genuinely isolates state must override `RR_HOME` again after the test environment boots.
  Evidence: the first mock-backed smoke attempt still wrote kubeconfig output under `~/.rr/test`, and rerunning after `System.put_env("RR_HOME", tmp_home)` produced a temp-directory kubeconfig path as intended.

## Decision Log

- Decision: keep the persisted schema at the current profile-nested shape unless implementation work proves that a migration is strictly necessary.
  Rationale: the spec requires global alias uniqueness as a behavior, not a new storage format. The current shape already stores alias owner and target implicitly because aliases live under one profile record. A write-time uniqueness check plus read-time duplicate detection is enough unless a later implementation step proves otherwise.
  Date/Author: 2026-03-19 / Codex

- Decision: treat duplicate alias resolution as an invariant violation instead of a user-facing branch once writes enforce global uniqueness.
  Rationale: the revised spec now defines alias text as globally unique, so the normal read API should expose only “found one” or “found none.” If malformed local state still produces duplicate aliases, callers should crash through unmatched pattern handling so the invariant break is loud during development rather than normalized into supported behavior.
  Date/Author: 2026-03-19 / Codex

- Decision: keep legacy migration into a `"default"` profile for schema-v0 configs, but do not let any user-facing command infer `"default"` when `-p` is omitted.
  Rationale: migration compatibility and runtime UX are separate concerns. Old config still needs a stable landing place, while new command behavior must remain command-specific and explicit.
  Date/Author: 2026-03-19 / Codex

- Decision: make `rr alias` fetch clusters only after the profile is fixed and alias text is entered.
  Rationale: this matches the revised product spec’s user journey exactly and keeps network work scoped to the chosen profile.
  Date/Author: 2026-03-19 / Codex

- Decision: keep `RR.Config.Profiles.resolve_alias/1` as a strict two-outcome API even when malformed local config violates alias uniqueness.
  Rationale: the revised spec defines alias resolution as “found one” or “found none.” Write-time enforcement prevents new duplicates, and a manually edited config that violates the invariant should raise loudly from the config layer rather than expanding the public return contract.
  Date/Author: 2026-03-20 / Codex

## Outcomes & Retrospective

At plan creation time, the repository already satisfies much of the revised product spec: named profiles exist, `rr login` already manages them, `rr list` already supports all-profiles rendering, and `rr kf` already searches across profiles and stores kubeconfigs under profile-specific paths. The remaining outcome is to align alias storage and alias UX with the revised spec, then confirm the existing profile behavior still holds under the new tests.

Milestone 1 is complete. `RR.Config.Profiles.put_alias/3` now enforces global uniqueness across profiles while still allowing same-profile updates, and `resolve_alias/1` now exposes only `:miss` or one exact alias hit. Malformed duplicate aliases still fail loudly, but they do so by raising from the config layer instead of expanding the public return contract. The next outcome is to consume that contract from the interactive `rr alias` flow and from `rr kf`.

Milestone 2 is complete. `rr alias` no longer accepts positional alias or cluster arguments. The command now validates or prompts for a profile, prompts for alias text, rejects cross-profile alias collisions before any Rancher call, loads clusters only for the selected profile, and asks for confirmation before overwriting an alias in that same profile.

Milestone 3 is complete. `rr kf` now relies on the strict alias invariant exposed by `RR.Config.Profiles.resolve_alias/1`, so the command only handles `:miss` or one resolved alias hit. Malformed local config still fails loudly, but it does so by raising from the config layer instead of adding a third branch to the alias result contract. The focused regression suite now covers that edge case in addition to the existing profile-scoped alias resolution and cross-profile cluster ambiguity coverage.

The plan is complete. The repository now matches the revised product spec for the remaining deltas that were still open at the start of this work: aliases are globally unique across profiles, `rr alias` is fully interactive, `rr kf` narrows through globally unique aliases and reports malformed duplicate local alias state clearly, and help plus regression coverage match the new command contract.

Verification is complete for repository-local behavior. The focused milestone tests passed, `just check` passed with the full ExUnit suite, and a mock-backed smoke run in a temporary `RR_HOME` showed the end-to-end flow for `list`, interactive `alias`, `alias --list`, and alias-driven `kf` without touching real user state. The only remaining validation gap is live Rancher credentials, which were not available in this session; that gap affects external integration confidence, not the checked-in command and config behavior exercised by the automated suite and smoke run.

## Context and Orientation

`rr` is a small Elixir CLI. `lib/rr.ex` is the top-level dispatcher. Every user-facing workflow in scope here is implemented in `lib/cmds/`: `login.ex`, `list.ex`, `alias.ex`, and `kf.ex`. Output should continue to flow through `lib/rr/shell.ex`.

The local config schema already uses a current-version JSON object stored under `RR_HOME/config.json` or `~/.rr/config.json`. The schema is defined in `lib/config/schema.ex` and currently looks like:

    %{
      "schema_version" => 1,
      "profiles" => %{
        "profile_name" => %{
          "rancher_hostname" => "...",
          "rancher_token" => "...",
          "aliases" => %{"short" => "full-cluster-name"}
        }
      }
    }

`lib/config/profiles.ex` owns reads and writes for this shape. `lib/config/auth.ex` builds `%RR.Config.Auth{profile_name, rancher_hostname, rancher_token}`, validates tokens through `External.RancherHttpClient.get_token_info/1`, and caches validity in ETS table `:rr_auth_cache` keyed by `{profile_name, hostname, token}`.

`lib/external/rancher_http_client.ex` is the HTTP boundary. It already exposes explicit-auth functions `get_clusters(auth)`, `get_kubeconfig(auth, kubeconfig)`, and `get_token_info(auth)`. Tests replace this module through Mox, so new HTTP work must stay behind this boundary.

The current command behavior is mixed relative to the revised spec. `lib/cmds/login.ex` already supports `-p` and the create-versus-update prompt. `lib/cmds/list.ex` already supports `-p` and combined multi-profile output. `lib/cmds/kf.ex` already supports `-p`, cross-profile search, alias narrowing, and profile-scoped kubeconfig files. `lib/cmds/alias.ex` is the outlier: it still expects positional `<alias> <full_name>` arguments, stores duplicates under different profiles, and cannot guide the user through profile-specific cluster selection.

Tests already exist in `test/rr/login_test.exs`, `test/rr/list_test.exs`, `test/rr/alias_test.exs`, `test/rr/kf_test.exs`, and `test/rr/config/profiles_test.exs`. Those files are the first places to update because the revised spec is primarily about user-visible behavior, not internal refactoring.

## Milestones

### Milestone 1: Make alias persistence match the new uniqueness rule

At the end of this milestone, the config layer can answer one question deterministically: “who owns this alias text?” The profile store must reject attempts to save alias text that is already claimed by another profile, still allow same-profile updates after the caller confirms overwrite, and expose alias resolution as a strict two-outcome API: “one match” or “no match.” This milestone is complete when focused profile-store tests prove that one alias string can map to only one `{profile, cluster}` pair and malformed duplicate aliases raise instead of widening the public return contract.

### Milestone 2: Replace positional alias arguments with the interactive flow

At the end of this milestone, `rr alias` no longer takes positional `<cluster_alias> <cluster_full_name>` arguments for create or update. Instead, the command chooses or validates a profile, prompts for alias text, fetches the clusters for that profile, and requires the user to choose one interactively. It must reject a cross-profile alias collision before writing config, ask for overwrite confirmation when the alias already belongs to the selected profile, and fail clearly when the selected profile has no clusters. This milestone is complete when `test/rr/alias_test.exs` covers the interactive happy path plus the revised-spec failure cases for missing profiles, cross-profile alias conflicts, same-profile overwrite, overwrite decline, and empty cluster lists.

### Milestone 3: Tighten command integration, help text, and regression coverage

At the end of this milestone, the remaining commands describe and enforce the revised behavior consistently. `rr kf` must treat alias resolution as globally unique by design while still guarding against malformed duplicate aliases. Help text must stop advertising positional alias arguments. Focused tests must cover the exact revised-spec promises for missing profiles, ambiguity messages, alias uniqueness, and all-profiles behavior. This milestone is complete when focused tests pass, `just check` passes, and a temporary-`RR_HOME` smoke run shows the interactive alias flow working without touching real state.

## Plan of Work

Start in `lib/config/profiles.ex`. Keep the current schema version unless a concrete implementation blocker appears. Add explicit helpers for alias ownership and uniqueness so callers do not have to scan raw profile maps themselves. `put_alias/3` should no longer blindly write into the selected profile. It should first inspect every profile. If the alias does not exist anywhere, save it. If it exists in the same profile, keep same-profile overwrite legal so the caller can decide whether to confirm before calling `put_alias/3`. If it exists in a different profile, return a structured conflict that names the owning profile and cluster. `resolve_alias/1` should stay a strict two-outcome API: `:miss` or one exact alias match. If malformed config violates the uniqueness invariant, let the config layer raise loudly instead of returning a third public result shape.

Next, refactor `lib/cmds/alias.ex` around the revised interactive flow. Parsing should only accept `--list`, `--help`, and optional `-p` / `--profile`; create or update operations should no longer accept positional alias arguments. The execution flow should be:

1. If `--list` is present, keep the grouped-by-profile output.
2. Otherwise, determine the target profile. `-p missing` must fail immediately before prompts or network calls. Without `-p`, prompt the user to choose a profile, and if there are no profiles, return the same clear “run rr login” guidance used elsewhere.
3. Prompt for alias text and reject blank input.
4. Check for alias ownership across all profiles. If another profile already owns the alias, return a clear conflict error without changing config. If the selected profile already owns the alias, remember the current mapping so the command can ask for overwrite confirmation later.
5. Validate auth for the selected profile with `RR.Config.Auth.ensure_valid_auth/1`, fetch clusters through `External.RancherHttpClient.get_clusters/1`, and fail clearly when no clusters are available.
6. Present the profile’s full cluster names with `Owl.IO.select/2` and require the user to choose one.
7. If the alias already existed in the selected profile, show the current mapping and ask for overwrite confirmation before saving. If the user declines, exit with `:ok` and leave config unchanged.
8. Save the alias and print a confirmation message that includes the profile name and full cluster name.

Then adjust `lib/cmds/kf.ex` so it matches the new alias contract. The `-p` path already looks correct: it validates the named profile first, resolves aliases only inside that profile, then fetches clusters only for that profile. Keep that order. The no-`-p` path should continue to check aliases before substring matching, and it should treat `resolve_alias/1` as a strict two-outcome contract: one exact alias hit or `:miss`. Use one shared ambiguity renderer for both single-profile and cross-profile multi-match results so the guidance stays consistent.

Review `lib/cmds/login.ex`, `lib/cmds/list.ex`, and `lib/rr.ex` last. Most of the revised-spec behavior is already present there, so the expected work is small: keep the command help text aligned with the new alias syntax, keep terminology consistently on “profile”, and ensure no help output or prompt text suggests a hidden current profile. Internal compatibility wrappers around `"default"` may remain only where they support legacy migration or old tests; do not route new user-facing behavior through them.

Finally, update tests before declaring the feature complete. `test/rr/config/profiles_test.exs` should prove alias uniqueness and duplicate-detection behavior. `test/rr/alias_test.exs` should be rewritten around the interactive flow, including profile prompt, alias conflict, same-profile overwrite confirmation, overwrite decline, no-clusters failure, and `--list`. `test/rr/kf_test.exs` should keep the existing profile-scoped kubeconfig coverage and add assertions that alias resolution narrows the profile. Only touch `test/rr/login_test.exs`, `test/rr/list_test.exs`, or bootstrap/migration tests if implementation changes behavior there.

## Concrete Steps

Work from `/Users/zilizhang/code/sre/rr`.

After changing the profile-store helpers, run:

    just test-target test/rr/config/profiles_test.exs

After refactoring the interactive alias flow, run:

    just test-target test/rr/alias_test.exs

After tightening kubeconfig alias resolution and any surrounding command/help behavior, run:

    just test-target test/rr/kf_test.exs
    just test-target test/rr/login_test.exs
    just test-target test/rr/list_test.exs

Before finishing, run formatting and the standard verification pass:

    just format
    just check

Then do a smoke run in a temporary home directory so no real Rancher state is touched. A live-Rancher run is ideal when credentials are available, but a mock-backed `MIX_ENV=test` run is acceptable when the goal is to exercise the checked-in command flow without external dependencies:

    export RR_HOME="$(mktemp -d)"
    mix run --no-halt -- login -p prod
    mix run --no-halt -- login -p stage
    mix run --no-halt -- list
    mix run --no-halt -- alias -p prod
    mix run --no-halt -- alias --list
    mix run --no-halt -- kf prod-api

or, when live credentials are unavailable, run a one-off `MIX_ENV=test mix run -e '...'` script that:

    1. overrides `RR_HOME` to a fresh temp directory after `config/test.exs` loads,
    2. stubs `External.Config.Mock` and `External.RancherHttpClient.Mock`,
    3. seeds `prod` and `stage` profiles,
    4. exercises `RR.List.run([])`, `RR.Alias.run(["-p", "prod"])`, `RR.Alias.run(["--list"])`, and `RR.KubeConfig.run(["--new", "prod-api"])`,
    5. confirms that the kubeconfig path is written under `<temp>/kubeconfigs/prod/production-api`.

The expected manual behavior is:

- `rr alias -p prod` prompts for alias text and then prompts for one cluster from the `prod` profile.
- attempting to reuse that alias under `stage` fails with a clear ownership error.
- `rr alias --list` shows aliases grouped under `prod` and `stage`.
- `rr kf prod-api` resolves through the alias’s profile without searching unrelated profiles.

## Validation and Acceptance

The implementation is acceptable only when a human can observe the revised-spec behavior end to end.

`rr login` must remain the only entry point for creating or updating profiles. `rr login -p <profile>` must still write directly into the named profile. `rr login` without `-p` must still offer the create-versus-update flow and must not imply a persistent current profile.

`rr list -p <profile>` must still list only that profile’s clusters, and `rr list` should render a `PROFILE` column in its table output regardless of whether one profile or many profiles are being shown. When no profiles exist, the command must return a clear no-profiles message instead of behaving as if one implicit auth exists.

`rr alias` and `rr alias -p <profile>` must now complete alias creation through prompts only. No positional alias or cluster arguments should be required. After the profile is fixed, the command must prompt for alias text first and cluster choice second. If the selected profile has no clusters, the command must fail with a clear message before asking the user to pick a cluster from an empty list.

Alias text must be globally unique across all profiles. Creating alias `prod` under profile `a` must prevent creating or moving alias `prod` under profile `b`. Reusing alias `prod` inside profile `a` must show the current mapping and ask for explicit overwrite confirmation before saving.

`rr kf -p <profile> token` must keep searching only inside that profile. `rr kf token` without `-p` must continue to search across profiles, but when `token` is an alias, alias resolution must narrow to the alias’s owning profile before cluster lookup. Ambiguous full-cluster-name matches must still name both the cluster and the profile and must explain the three supported resolution paths: use `-p`, be more specific, or use `rr alias`.

Focused tests for profiles, alias, kubeconfig, login, and list must pass, followed by a clean `just check`.

A temporary-`RR_HOME` smoke run must demonstrate the interactive alias flow and alias-driven kubeconfig resolution without mutating real user state. If live Rancher access is unavailable, a mock-backed smoke run is sufficient as long as it exercises the checked-in command modules end to end and records the remaining live-integration gap explicitly.

## Idempotence and Recovery

This plan assumes the existing schema version can remain unchanged. That keeps the rollout low risk because no migration is required for the normal path. Alias writes only change `config.json` under the selected profile entry, so the work is retry-safe: if the command fails before the final write, config remains unchanged.

Use `RR_HOME="$(mktemp -d)"` for manual verification so no real Rancher tokens or kubeconfigs are touched. If implementation later proves that schema changes are unavoidable, stop and add an explicit migration step under `lib/config/migrator.ex`, `lib/config/schema.ex`, and `lib/config/migrations/`, with a backup path through `RR.Config.Bootstrap`.

Duplicate aliases discovered while reading config should be treated as an invariant violation during development, not normalized into a supported user-facing branch. The implementation should not silently rewrite config. If malformed local state produces duplicate aliases, the intended recovery path is to fix the offending test fixture or temporary config rather than adding another runtime ambiguity path to the alias API.

## Artifacts and Notes

Expected persisted shape after two profiles and one globally unique alias:

    %{
      "schema_version" => 1,
      "profiles" => %{
        "prod" => %{
          "rancher_hostname" => "https://prod.example",
          "rancher_token" => "token-prod:abc",
          "aliases" => %{"prod-api" => "production-api"}
        },
        "stage" => %{
          "rancher_hostname" => "https://stage.example",
          "rancher_token" => "token-stage:def",
          "aliases" => %{}
        }
      }
    }

Expected `rr alias --list` shape:

    these aliases are found:

    prod
      prod-api -> production-api
    stage
      web -> staging-web

Expected cross-profile cluster ambiguity transcript for `rr kf api`:

    more than one matches were found for the cluster name 'api'
    these matches are found:
      prod -> api
      stage -> api
    you have three options:
    1. to select a certain profile, use -p
    2. be more specific on the name
    3. use rr alias

Expected cross-profile alias ownership error:

    alias 'prod-api' is already claimed by profile 'prod' for cluster 'production-api'

## Interfaces and Dependencies

In `lib/config/profiles.ex`, end this work with explicit alias-ownership helpers so command modules do not need to inspect raw config maps. The module should still expose profile reads and writes, and it should additionally provide a way to answer:

    @spec resolve_alias(String.t()) ::
            :miss
            | {:ok, %{profile_name: String.t(), cluster_name: String.t()}}

and a write path that can distinguish free, same-profile, and cross-profile alias ownership, for example:

    @spec put_alias(String.t(), String.t(), String.t()) ::
            :ok
            | {:error, :alias_owned_by_other_profile, %{profile_name: String.t(), cluster_name: String.t()}}
            | {:error, String.t()}

`resolve_alias/1` should be implemented so duplicate aliases are not part of the public return contract. Callers such as `RR.KubeConfig` should treat `:miss` and `{:ok, ...}` as exhaustive outcomes and allow malformed duplicate-alias config to raise loudly from the config layer.

If a helper richer than `put_alias/3` makes the calling code cleaner, add it here rather than duplicating alias-scan logic in `RR.Alias` and `RR.KubeConfig`.

In `lib/cmds/alias.ex`, the command should end this work with no positional create/update arguments. It must depend on `RR.Config.Profiles`, `RR.Config.Auth`, and `External.RancherHttpClient` for profile selection, auth validation, uniqueness checks, and cluster listing. Keep `--list` as a pure local-config operation with no network calls.

In `lib/cmds/kf.ex`, keep `%RR.KubeConfig{profile_name, id, name, kubeconfig}` and the profile-scoped kubeconfig path `Path.join([RR.Config.home_dir(), "kubeconfigs", profile_name, name])`. Alias resolution must happen before cluster fan-out, and callers should rely on `RR.Config.Profiles.resolve_alias/1` returning only `:miss` or one resolved alias hit.

In tests, continue mocking `External.Config` and `External.RancherHttpClient` through Mox. For revised-spec failure cases, assert call counts of zero where “fail immediately” is required so the behavior is proven rather than inferred.

## Change Note

Rewritten on 2026-03-19 because `docs/product-specs/multi-cluster-profiles.md` changed materially after the earlier plan was written. The previous plan described building profile support from scratch and recorded completed implementation work that is already present in the repository. This revision replaces that stale framing with a plan focused on the real remaining deltas: interactive alias creation, global alias uniqueness, cleanup of the last user-facing default-profile assumptions, and the removal of handled duplicate-alias resolution branches from the normal alias API.

Updated on 2026-03-20 after Milestone 1 implementation. The plan now records the chosen handling for malformed duplicate aliases: write-time enforcement keeps aliases globally unique, while read-time resolution remains a strict two-outcome API and raises if a manually edited config violates the invariant.

Updated on 2026-03-20 after Milestone 2 implementation. The plan now records the interactive alias flow that replaced positional alias arguments, the same-profile overwrite confirmation step, and the focused alias-command coverage that now exercises profile prompts, conflict rejection, and empty-cluster failure handling.

Updated on 2026-03-20 after Milestone 3 implementation. The plan now records the final `kf` alignment work: alias-driven profile narrowing remains unchanged, and malformed duplicate aliases now raise from the config layer instead of introducing another handled return branch.

Updated on 2026-03-20 after verification and archive preparation. The plan now records the full test pass, the mock-backed temporary-`RR_HOME` smoke run used in place of live Rancher credentials, and the residual external-integration validation gap.
