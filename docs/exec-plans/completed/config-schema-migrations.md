# Add Versioned Config Migration Bootstrap

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `docs/PLANS.md`.

## Purpose / Big Picture

After this change, `rr` will treat `config.json` schema upgrades as a first-class startup concern instead of burying migration logic inside business modules. A user upgrading from an older `rr` release will see a short stderr message when `rr` migrates their config, `rr` will write a backup of the pre-migration file before rewriting it, and commands that only print help or version information will stay side-effect free. Future schema changes will follow the same mechanism: the application declares the schema version it expects, checks the on-disk version at startup for stateful commands, and upgrades the file to the current shape before any command logic reads config data.

The finished behavior is observable in four ways. First, running a stateful command such as `rr list` against a legacy config will print a short migration notice to stderr and then proceed using the new schema. Second, the old config file will be preserved as a backup next to the migrated file. Third, malformed legacy config will fail fast with a clear error instead of being silently normalized into partial state. Fourth, `rr --help` and `rr --version` will not trigger migration or rewrite `RR_HOME/config.json`.

## Progress

- [x] (2026-03-18 11:20Z) Read `docs/PLANS.md`, `docs/ARCHITECTURE.md`, `lib/rr.ex`, `lib/external/config.ex`, `lib/external/config/impl.ex`, `lib/config.ex`, `lib/config/profiles.ex`, and `test/rr/config/profiles_test.exs` to map the current config read/write path and the legacy migration embedded in `RR.Config.Profiles.state/0`.
- [x] (2026-03-18 11:27Z) Converted the design discussion into this ExecPlan, including startup-triggered migration, backup requirements, hard-fail behavior for malformed legacy config, help/version exemptions, and a migration API that allows any supported source version to upgrade directly to the current version.
- [x] (2026-03-19 02:34Z) Moved the plan to `docs/exec-plans/active/`, added `RR.Config.Schema`, `RR.Config.Migrator`, `RR.Config.Migrations.V0ToCurrent`, and `RR.Config.Bootstrap`, and extended `External.Config` with `read_result/0` and `backup/0` so migration can validate malformed JSON, create backups, and write only on successful upgrade.
- [x] (2026-03-19 02:34Z) Added focused ExUnit coverage for schema version detection, legacy-to-current migration behavior, backup orchestration, stderr notices, and malformed legacy failures in `test/rr/config/schema_test.exs`, `test/rr/config/migrator_test.exs`, and `test/rr/config/bootstrap_test.exs`.
- [x] (2026-03-19 02:34Z) Refactored `RR.Config.Profiles` and `RR.Config` to treat only the explicit current schema as authoritative, leaving current-version normalization limited to alias/default conveniences and updating `test/rr/config/profiles_test.exs`; verified with `just test-target test/rr/config/profiles_test.exs` and `just test-target test/rr/config/auth_test.exs`.
- [x] (2026-03-19 02:38Z) Wired startup bootstrap into `RR.run/1` for `login`, `list`, `alias`, and `kf`, added `test/rr/rr_test.exs` to prove stateful-command migration and help/version bypass, and verified the command-level suites with `just test-target test/rr/alias_test.exs`, `just test-target test/rr/list_test.exs`, `just test-target test/rr/login_test.exs`, `just test-target test/rr/kf_test.exs`, and `just test-target test/rr/rr_test.exs`.
- [x] (2026-03-19 02:38Z) Ran the final verification pass with `just format` and `just check`, manually confirmed migration behavior under temporary `RR_HOME` directories, updated `docs/ARCHITECTURE.md`, and prepared the plan for archival under `docs/exec-plans/completed/`.

## Surprises & Discoveries

- Observation: the current legacy migration is performed implicitly inside `RR.Config.Profiles.state/0`, which means profile business logic also owns raw-file schema normalization.
  Evidence: `lib/config/profiles.ex` reads `External.Config.read/0`, normalizes the raw map, and writes the normalized result back when the map changes.

- Observation: the current migration has no explicit schema version and infers the legacy shape by checking for root keys such as `"rancher_hostname"`, `"rancher_token"`, and `"alias"`.
  Evidence: `normalize_legacy_profile/1` in `lib/config/profiles.ex` builds the `"default"` profile from those keys and falls back to `%{"profiles" => %{}}` when none are present.

- Observation: top-level command dispatch already passes through a single entrypoint in `lib/rr.ex`, which makes startup bootstrap practical without scattering checks through every command module.
  Evidence: `RR.main/0` calls `run/1`, and `run/1` dispatches `login`, `list`, `alias`, `kf`, `yo`, help, and version from one place.

- Observation: `External.Config` is already a dedicated read/write boundary and is mocked in tests, so the migration bootstrap can stay testable if it is layered above this boundary instead of bypassing it.
  Evidence: `lib/external/config.ex` delegates to an implementation module selected from application env, and current tests use the mock boundary for config state.

- Observation: the existing `External.Config.read/0` helper hides malformed JSON by returning `%{}`, which would have made the new migrator silently skip broken files instead of failing fast.
  Evidence: the first implementation pass needed a separate `read_result/0` callback so `RR.Config.Bootstrap.ensure_current/0` could distinguish `:enoent` from JSON decode errors and surface a clear migration failure.

- Observation: existing command and auth tests stayed stable once shared config helpers returned a versioned empty state without writing it back to disk.
  Evidence: `just test-target test/rr/config/profiles_test.exs` and `just test-target test/rr/config/auth_test.exs` both passed after `RR.Config.Profiles.state/0` stopped mutating empty config and started treating versioned schema as the only persisted shape it understands.

- Observation: startup migration could be verified end-to-end with `rr alias --list`, which exercised real disk I/O without needing Rancher API access.
  Evidence: a manual run against a legacy `RR_HOME/config.json` printed `config schema 0 detected, migrating to 1`, created `config.json.bak`, and rewrote the file into the versioned `"profiles"` layout before listing aliases.

## Decision Log

- Decision: trigger config migration during CLI startup for stateful commands rather than inside `RR.Config.Profiles` or other business modules.
  Rationale: this keeps schema handling at the boundary of the application, lets the rest of the code assume one canonical config shape, and avoids side effects during help/version commands.
  Date/Author: 2026-03-18 / Codex + user

- Decision: the application must declare the schema version it requires and compare that value against the on-disk config version before any stateful command executes.
  Rationale: future migrations should be explicit and discoverable; version inference should only be a compatibility fallback for legacy files that predate the version field.
  Date/Author: 2026-03-18 / Codex + user

- Decision: require a backup of the pre-migration config file before rewriting `config.json`.
  Rationale: config migration is user-state mutation, and a backup gives an immediate recovery path if the migration code or assumptions are wrong.
  Date/Author: 2026-03-18 / user

- Decision: malformed legacy config must fail hard instead of being partially salvaged.
  Rationale: silent best-effort recovery hides data loss and makes migration behavior unpredictable. A hard failure is easier to reason about and safer for credentials.
  Date/Author: 2026-03-18 / user

- Decision: migration notices should be short stderr messages emitted only when migration actually runs.
  Rationale: users should know why a startup rewrote state, but normal command output must stay focused and machine-usable.
  Date/Author: 2026-03-18 / user

- Decision: do not impose a structural rule that migrations must always be implemented as `N -> N+1`; a migration may upgrade any supported source version directly to the current version.
  Rationale: this leaves room for simpler source-version-specific migrations such as `legacy -> current` or `v1 -> current` without forcing intermediate transforms that add little value in a small CLI.
  Date/Author: 2026-03-18 / user

- Decision: `rr --help` and `rr --version` must not trigger config migration.
  Rationale: informational commands should remain side-effect free and should not fail because a user has a broken config file.
  Date/Author: 2026-03-18 / user

- Decision: treat a completely absent or empty config file as a bootstrap no-op instead of eagerly writing a versioned empty config at startup.
  Rationale: stateful commands should migrate existing state, not create new disk state merely because a user ran `rr list` or `rr alias --list` with no saved profiles.
  Date/Author: 2026-03-19 / Codex

- Decision: keep `RR.Config.Profiles` permissive only for current-schema conveniences such as defaulting missing alias maps, and remove all historical-layout inference from that module.
  Rationale: after bootstrap exists, only one layer should own cross-version schema handling; leaving any legacy inference in profile helpers would recreate the split authority this change is meant to remove.
  Date/Author: 2026-03-19 / Codex

- Decision: skip bootstrap whenever a top-level invocation is purely informational, including subcommand help such as `rr alias --help`.
  Rationale: the side-effect-free requirement is about the whole invocation, not just the top-level `--help` and `--version` forms, so `RR.run/1` now checks for help flags before calling `RR.Config.Bootstrap`.
  Date/Author: 2026-03-19 / Codex

## Outcomes & Retrospective

This plan shipped the intended config-boundary refactor end to end. `rr` now has an explicit schema version, a dedicated startup bootstrap that migrates legacy config before stateful commands run, a byte-for-byte backup path, and profile helpers that assume only the current schema. The CLI dispatcher owns the bootstrap trigger, so help/version invocations remain side-effect free while `login`, `list`, `alias`, and `kf` all see already-migrated config.

Validation covered both focused and end-to-end behavior. The new schema/migrator/bootstrap/profile/dispatcher tests all passed, the broader command suites still passed, `just check` finished cleanly with 50 tests passing, and manual `RR_HOME` smoke checks showed both the migration path and the help no-op path behaving as designed. No known blockers remain for this plan; future schema changes now have a single migration entrypoint and a version field to build on.

## Context and Orientation

`rr` is a small Elixir CLI that stores user state under `RR_HOME` or `~/.rr` when `RR_HOME` is not set. The persisted config file is `config.json` in that home directory. The current runtime file I/O boundary is `lib/external/config.ex`, with the default filesystem implementation in `lib/external/config/impl.ex`. That implementation reads JSON from disk and writes JSON back to the same path.

Top-level command execution begins in `lib/rr.ex`. `RR.main/0` wraps command execution in exit-code handling, and `RR.run/1` dispatches the first CLI token to a command module such as `RR.Login`, `RR.List`, `RR.Alias`, or `RR.KubeConfig`. This is the narrowest place to insert a startup bootstrap that runs before stateful commands but skips help and version.

The local config helper in `lib/config.ex` is a thin wrapper around `External.Config`. The current profile storage logic lives in `lib/config/profiles.ex`. Today that module reads the raw config, rewrites it into a normalized `%{"profiles" => ...}` shape, and writes it back if the raw and normalized maps differ. That means a module whose main job is profile access also owns migration of old file layouts. The current implicit migration accepts a legacy root-level shape with `"rancher_hostname"`, `"rancher_token"`, and `"alias"` keys and rewrites it into a `"default"` profile under `"profiles"`.

The new design should create a clear boundary between raw persisted config and domain-level profile helpers. After the change, all business logic should read only the latest schema. Migration is the one-time transformation from an older on-disk schema into the current schema that this application release expects. A schema version is a number stored inside `config.json` that identifies which layout the file uses. A backup file is a byte-for-byte copy of the original `config.json` written before migration overwrites it.

## Plan of Work

Begin by introducing a dedicated config schema module, a bootstrap module, and a migration runner. In `lib/config/`, add a module such as `RR.Config.Schema` that exposes the current required schema version and a helper to detect the version of a raw config map. The detection rule must treat missing `schema_version` as legacy version `0`, must accept the current explicit schema version key when present, and must reject versions newer than the application knows how to read. In the same area, add `RR.Config.Bootstrap` (or `RR.Config.Store` if that name fits the repository better) with an entrypoint such as `ensure_current!/0` or `ensure_current/0`. This entrypoint must read the raw config through `External.Config`, decide whether migration is needed, print a short stderr message when migration starts, create a backup of the existing config file, run the migration, write the migrated config, and return the migrated map. If the config is malformed for its detected source version, return an error and do not overwrite the original file.

Keep `External.Config` as a dumb boundary for raw file I/O. Extend it only where necessary to support backup-safe migration. The current interface has `read/0` and `write/1`; if the bootstrap needs access to the config path or file existence checks, either add narrow helpers to `External.Config` such as `path/0`, `exists?/0`, `backup/1`, and `write_raw/1`, or add a new filesystem-oriented boundary under `lib/external/` that the bootstrap owns. Do not bypass the boundary from business modules, and preserve testability through Mox in the same style the repo already uses for config and Rancher access. Keep the default implementation in `lib/external/config/impl.ex` responsible for filesystem details such as atomic write strategy and naming of the backup file. The backup filename must be deterministic and easy to find; a good default is `config.json.bak` written in the same directory before migration overwrites `config.json`. If the backup file already exists, overwrite it with the latest pre-migration bytes so retries stay predictable.

Implement the migration runner as an explicit mapping from source version to a migration module that upgrades that source version directly to the current version. Do not force intermediate `N -> N+1` hops. A simple shape is a module like `RR.Config.Migrator` with `migrate(raw_config, target_version)` that dispatches to modules such as `RR.Config.Migrations.V0ToCurrent` and future `RR.Config.Migrations.V1ToCurrent`. Each migration module must validate the raw input shape it expects. For the current migration, legacy version `0` means the pre-version config layout used before multi-cluster profiles, including the existing root-level `rancher_hostname`, `rancher_token`, and `alias` keys. That migration should produce the canonical current schema, including the new explicit `schema_version` key and the existing top-level `"profiles"` map. If the legacy map contains contradictory or malformed data, return an error instead of normalizing partial state.

Once the bootstrap exists, refactor `lib/config/profiles.ex` so it assumes the latest schema only. Remove the implicit legacy normalization and write-back behavior from `state/0`. Replace it with a simple read of the already-bootstrapped config, plus normalization limited to cheap invariants inside the current schema if needed. The important rule is that `Profiles` may shape current-version data for convenience, but it must not detect or migrate historical schemas. Update `lib/config.ex` and `lib/config/auth.ex` only as needed to consume the new bootstrap path cleanly.

Wire startup triggering into `lib/rr.ex`. Before dispatching a stateful command such as `login`, `list`, `alias`, `kf`, or `yo` if `yo` reads config, call the bootstrap. Do not bootstrap for `--help`, `-h`, `--version`, or `-v`. Decide explicitly whether `yo` should count as stateful by reading its implementation during execution; if it does not touch config, keep it side-effect free too. If bootstrap fails because migration is malformed or unsupported, route the error through `RR.Shell.error/1` the same way other command errors are surfaced.

Add and update tests in layers. Add focused unit tests for schema version detection and for each migration module. Add integration-style tests around the bootstrap that assert the exact before-and-after maps, that a backup is created before write, that stderr migration messages appear only when migration runs, and that malformed legacy config fails without mutating the original state. Add a command-level test proving that `rr --help` and `rr --version` skip bootstrap. Update the existing `test/rr/config/profiles_test.exs` so it stops asserting that `RR.Config.Profiles.state/0` performs legacy migration. Instead, move those expectations into new bootstrap or migrator tests. Keep the current profile behavior tests, but seed them with already-current schema config including `schema_version`.

Near the end of the implementation, re-read `docs/ARCHITECTURE.md` and update it so the config boundary description names the new bootstrap and migration modules and states that business modules operate on the latest schema only. Then move the plan through the normal lifecycle by placing it under `docs/exec-plans/active/` before implementation starts and under `docs/exec-plans/completed/` only after final validation and documentation updates pass.

## Concrete Steps

Work from `/Users/zilizhang/code/sre/rr`.

Before implementation, move this plan into the active directory:

    mv docs/exec-plans/todo/config-schema-migrations.md docs/exec-plans/active/config-schema-migrations.md

Implement the schema and bootstrap foundation first. Read `lib/rr.ex`, `lib/external/config.ex`, `lib/external/config/impl.ex`, `lib/config.ex`, and `lib/config/profiles.ex` before editing. Add the new modules under `lib/config/` and update the config boundary implementation as required for backups and safe writes. After this slice, run focused tests for the new modules and any touched config tests:

    just test-target test/rr/config/schema_test.exs
    just test-target test/rr/config/migrator_test.exs
    just test-target test/rr/config/bootstrap_test.exs

Next, refactor `lib/config/profiles.ex`, `lib/config.ex`, and any auth helpers so they rely on already-migrated current-schema config. Update the existing profile tests to use current-schema fixtures and remove migration assertions from profile-specific tests. Then run:

    just test-target test/rr/config/profiles_test.exs
    just test-target test/rr/config/auth_test.exs

After the config-layer refactor is stable, wire startup bootstrap into `lib/rr.ex` and add top-level command tests that prove help/version skip migration and stateful commands invoke it. Then run:

    just test-target test/rr/rr_test.exs

If there is no top-level dispatch test file yet, create one focused on bootstrap triggering semantics rather than command behavior internals.

Once focused tests pass, run formatting and the full verification pass:

    just format
    just check

Do a manual smoke pass in a temporary home directory so no real config is touched. First, create a legacy config and then run a stateful command:

    export RR_HOME="$(mktemp -d)"
    printf '%s\n' '{"rancher_hostname":"https://legacy.example","rancher_token":"token-legacy:abc","alias":{"prod":"production"}}' > "$RR_HOME/config.json"
    mix run --no-halt -- list

The expected outcome is that stderr includes a short migration notice, `"$RR_HOME/config.json.bak"` exists with the original bytes, and `"$RR_HOME/config.json"` now contains the current schema version and `"profiles"` layout.

Then confirm that help and version do not migrate:

    export RR_HOME="$(mktemp -d)"
    printf '%s\n' '{"rancher_hostname":"https://legacy.example"}' > "$RR_HOME/config.json"
    mix run --no-halt -- --help
    test -f "$RR_HOME/config.json.bak" && echo "unexpected backup"

The expected outcome is that help prints normally, no backup file appears, and `config.json` remains unchanged.

Before finalizing, re-read and update `docs/ARCHITECTURE.md`, then move the plan to completed:

    mv docs/exec-plans/active/config-schema-migrations.md docs/exec-plans/completed/config-schema-migrations.md

## Validation and Acceptance

Acceptance is behavior, not only compilation. A finished implementation must demonstrate the following.

When `RR_HOME/config.json` contains the current schema version, stateful commands start without printing migration notices and without rewriting the file.

When `RR_HOME/config.json` contains the current legacy root-key shape and no explicit `schema_version`, a stateful command detects legacy version `0`, prints a short stderr notice that migration is happening, creates a backup file containing the original config, rewrites `config.json` to the current schema, and then continues command execution against the migrated state.

The migrated file must include an explicit schema version key and the current canonical config layout. For the current repository state, that means the latest schema still uses the top-level `"profiles"` map introduced by the multi-cluster profile work.

If the legacy file is malformed for the detected source version, the command must fail with a clear message, must not rewrite `config.json`, and must not create a misleading migrated state. The original file and its backup behavior must remain predictable.

Running `rr --help` or `rr --version` against an old config must not trigger migration, must not create a backup file, and must not fail because the config is malformed.

Focused migration tests and config-layer tests must pass, followed by a clean `just check`.

At the end of the task, `docs/ARCHITECTURE.md` must describe the new bootstrap and migration boundary, and the plan file must have been moved from `docs/exec-plans/active/` to `docs/exec-plans/completed/`.

## Idempotence and Recovery

The bootstrap must be safe to run on every stateful command startup. If `config.json` is already on the current schema version, migration is a no-op. Re-running a command after a successful migration should not create new differences in the file beyond stable formatting choices. Re-running after a failed migration should either fail the same way against the untouched original file or succeed after the user fixes the malformed config.

Backup creation must happen before overwriting the main config file. If migration fails before the new file is written, the original file must remain intact. If writing the migrated file fails after backup creation, the original file and backup should still give the user a recoverable state. Document the exact backup filename in the implementation and tests so recovery is obvious.

Use `RR_HOME="$(mktemp -d)"` for all manual verification. Never test migration against a real `~/.rr/config.json`. If a developer accidentally runs the migration against a real home directory during development, the recovery path is to restore the original bytes from the generated backup file and rerun after fixing the code.

Because the migration is startup-triggered, a retry should be straightforward: fix the bug, keep or restore the original config, and rerun the same command. Avoid writing partial migration state that would force hand-editing between retries.

## Artifacts and Notes

Expected stderr transcript for a successful legacy migration:

    config schema 0 detected, migrating to 1
    config migration complete

Expected legacy input example:

    {
      "rancher_hostname": "https://legacy.example",
      "rancher_token": "token-legacy:abc",
      "alias": {
        "prod": "production"
      }
    }

Expected current-schema output example after migration:

    {
      "schema_version": 1,
      "profiles": {
        "default": {
          "rancher_hostname": "https://legacy.example",
          "rancher_token": "token-legacy:abc",
          "aliases": {
            "prod": "production"
          }
        }
      }
    }

Expected failure transcript for malformed legacy config:

    config migration failed: legacy config is malformed: expected rancher_hostname and rancher_token to be strings

The schema version value shown above is an example for this ExecPlan. During implementation, choose the correct current version number once the new explicit version field is introduced, then update every example, test fixture, and acceptance statement in this plan to match.

## Interfaces and Dependencies

In `lib/config/schema.ex`, define a module such as:

    defmodule RR.Config.Schema do
      @spec current_version() :: non_neg_integer()
      @spec detect_version(map()) :: {:ok, non_neg_integer()} | {:error, String.t()}
      @spec current?(map()) :: boolean()
    end

In `lib/config/migrator.ex`, define a migration runner such as:

    defmodule RR.Config.Migrator do
      @spec migrate(map(), non_neg_integer()) :: {:ok, map()} | {:error, String.t()}
    end

The migration runner should dispatch by detected source version to modules that know how to produce the current schema directly. A concrete shape could be:

    defmodule RR.Config.Migrations.V0ToCurrent do
      @spec migrate(map(), non_neg_integer()) :: {:ok, map()} | {:error, String.t()}
    end

In `lib/config/bootstrap.ex`, define a startup entrypoint such as:

    defmodule RR.Config.Bootstrap do
      @spec ensure_current() :: :ok | {:error, String.t()}
      @spec maybe_migrate(map()) :: {:ok, map()} | {:error, String.t()}
    end

This module should own stderr notices, backup orchestration, and write-on-success semantics. Keep raw file I/O behind `External.Config`.

If additional config-boundary helpers are needed, extend `lib/external/config.ex` and `lib/external/config/impl.ex` with narrow, mockable functions rather than reaching directly into the filesystem from unrelated modules. Possible helpers include:

    @callback path() :: String.t()
    @callback backup(String.t()) :: :ok | {:error, term()}
    @callback write_atomically(map()) :: :ok | {:error, term()}

Only add the helpers the final implementation truly needs. Simpler is better, but the finished boundary must support backup creation and reliable writes during migration.

`lib/config/profiles.ex` must end the work assuming only the latest schema. Any remaining normalization there should be limited to current-version conveniences such as defaulting missing alias maps inside an otherwise-current profile, not detection of historical layouts.

Revision note: created this ExecPlan on 2026-03-18 from a design discussion about replacing the implicit profile-layer migration with an explicit startup bootstrap that versions, migrates, and backs up `config.json`.
Revision note: updated on 2026-03-19 to reflect activation of the plan, the new schema/bootstrap modules, the dedicated `External.Config` migration helpers, the current-schema-only profile refactor, the CLI bootstrap wiring, and the final verification/manual smoke evidence for the completed implementation.
