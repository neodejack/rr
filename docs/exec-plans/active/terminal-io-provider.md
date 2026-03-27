# Abstract Terminal IO Behind a Provider

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository stores ExecPlan guidance in `docs/PLAN.md`. Maintain this document in accordance with `docs/PLAN.md`.


## Purpose / Big Picture

The `rr` CLI currently hard-wires terminal side effects in two places. User-visible writes go through `RR.CLI.Output`, which calls `IO.puts/1` and `IO.puts(:stderr, ...)` directly, while interactive prompts in `RR.CLI.Commands.Login` call `Owl.IO.input/1` and `Owl.IO.confirm/1` directly. This makes command tests depend on `ExUnit.CaptureIO`, even when the behavior under test is not really about Elixir's standard IO devices. The result is extra ceremony in tests and a weaker architecture boundary: terminal IO is a side effect, but it is not isolated the same way Rancher HTTP, settings persistence, and auth caching are isolated.

After this change, all terminal interaction will live behind a single provider boundary. The production implementation will still write to `stdout` and `stderr` and still prompt through Owl, so the user-visible CLI behavior remains the same. The new test implementation will collect `stdout` and `stderr` transcripts and will replay scripted prompt answers, so unit tests can assert on collected output and input flow without using `capture_io` or `with_io` for terminal behavior. A maintainer will be able to prove the change works by running the existing CLI tests and seeing that command output, warnings, and login prompts are all asserted through the provider-backed collector instead of direct IO capture.


## Progress

- [x] (2026-03-27 10:11Z) Drafted this ExecPlan from the current repository state, the agreed design from the discussion, and the repository guidance in `docs/PLAN.md`.
- [x] (2026-03-27 04:08Z) Moved this ExecPlan from `docs/exec-plans/todo/` to `docs/exec-plans/active/`, re-read `docs/PLAN.md`, and re-inspected every direct terminal call site plus the existing provider pattern before editing code.
- [x] (2026-03-27 04:09Z) Added `RR.Providers.Terminal` and `RR.Providers.Terminal.Impl` with the shared provider selector, preserving the existing stdout ANSI formatting and Owl-backed prompt behavior. Verified with `mix format --check-formatted` and `mix compile --warnings-as-errors`.
- [x] (2026-03-27 04:14Z) Added `RR.Providers.Terminal.Mock` with process-local transcript collection plus scripted input and confirmation queues, and verified the helper API with `mix test test/rr/providers/terminal/mock_test.exs`.
- [ ] Migrate CLI and service call sites away from `RR.CLI.Output` and direct `Owl.IO.*` calls to the new provider boundary.
- [ ] Rewrite command and auth tests to use the collector instead of `ExUnit.CaptureIO`, then run formatting, compilation, focused tests, and the full suite.


## Surprises & Discoveries

- Observation: This repository stores ExecPlan guidance in `docs/PLAN.md`, not `docs/PLANS.md`.
  Evidence: `find docs -maxdepth 3 -type f | sort` lists `docs/PLAN.md` and no `docs/PLANS.md`.

- Observation: The repository already has a provider pattern with a shared `:external_bound` app-env switch, so a terminal provider can fit the existing architecture instead of introducing a new mechanism.
  Evidence: `lib/rr/providers/rancher.ex`, `lib/rr/providers/settings_store.ex`, and `lib/rr/providers/auth_cache.ex` all delegate through `Application.get_env(:rr, :external_bound, ...)`.

- Observation: The current output helper already distinguishes ANSI-formatted stdout from plain stderr writes, so the production terminal provider can preserve behavior by copying those exact write paths instead of inventing a new rendering layer.
  Evidence: `lib/rr/cli/output.ex` uses `IO.puts(IO.ANSI.format(message))` for stdout and `IO.puts(:stderr, message)` for stderr.

- Observation: The initial provider addition is safe to land independently before any caller migration because the new modules compile without changing the existing command path.
  Evidence: `mix compile --warnings-as-errors` after adding `lib/rr/providers/terminal.ex` and `lib/rr/providers/terminal/impl.ex` completed successfully on 2026-03-27.

- Observation: The command paths under test execute terminal side effects in the test process today, so a process-local collector is enough to isolate async cases without introducing a shared Agent or ETS table.
  Evidence: The command tests call `RR.CLI.run/1` or `module.execute/1` directly, and `mix test test/rr/providers/terminal/mock_test.exs` passed with `use ExUnit.Case, async: true`.

- Observation: Output-related test friction is real today. The current suite uses `ExUnit.CaptureIO` in the dispatcher tests and in the `alias`, `kf`, `list`, `login`, and `yo` command tests.
  Evidence: `rg -n "capture_io|with_io" test` returns matches in `test/rr/cli_test.exs` and all command test files except `test/rr/services/auth_test.exs`.

- Observation: The service layer already writes warnings and informational messages directly through the CLI output helper, so the terminal boundary is not limited to command modules.
  Evidence: `lib/rr/services/auth.ex`, `lib/rr/services/kubeconfigs.ex`, and `lib/rr/services/aliases.ex` all alias `RR.CLI.Output`.

- Observation: The baseline test suite passes before the refactor, so the migration can use the current 37-test suite as a safety net.
  Evidence: `mix test` on 2026-03-27 finished with `37 tests, 0 failures`.


## Decision Log

- Decision: Treat terminal IO as a provider boundary and not as a special-case helper that stays in the CLI layer.
  Rationale: Writing to `stdout` and `stderr` and reading interactive input are side effects, and this repository already isolates other side effects behind provider behaviours. Making terminal IO follow the same rule improves testability and keeps the architecture internally consistent.
  Date/Author: 2026-03-27 / User + Codex

- Decision: Cover full CLI terminal interaction, not just output writes.
  Rationale: Refactoring only `RR.CLI.Output` would remove some `capture_io` usage, but `RR.CLI.Commands.Login` would still depend on `with_io` because it prompts through `Owl.IO`. A single terminal boundary for writes, input, and confirmation makes the contract coherent and eliminates the main remaining direct-terminal dependency in tests.
  Date/Author: 2026-03-27 / User + Codex

- Decision: Use a real collector-backed `RR.Providers.Terminal.Mock` implementation instead of a `Mox` mock for terminal IO tests.
  Rationale: The command tests mostly need to assert on the resulting transcript and on scripted prompt responses, not on the exact number of provider calls. A collector keeps tests readable, avoids repetitive `expect/3` setups, and still fits the repository's `Impl` versus `Mock` provider naming convention.
  Date/Author: 2026-03-27 / User + Codex

- Decision: Keep the shared provider selector `:external_bound` unchanged.
  Rationale: This refactor is about adding one more provider boundary, not reworking repository-wide provider configuration. The existing `Impl` and `Mock` suffix convention is already in use and should remain the single switch for environment-specific provider implementations.
  Date/Author: 2026-03-27 / Codex

- Decision: Retire `RR.CLI.Output` as an active boundary and have callers use `RR.Providers.Terminal` directly.
  Rationale: Keeping both `RR.CLI.Output` and a new provider would create two terminal abstractions with overlapping responsibilities. The cleaner end state is one terminal provider boundary used by both CLI modules and services.
  Date/Author: 2026-03-27 / Codex

- Decision: Keep the terminal prompt callbacks thin and Owl-shaped by accepting keyword options directly in the provider contract.
  Rationale: The only current prompt caller already passes Owl keyword options, and preserving that surface keeps the first migration mechanical while still isolating the side effect behind the provider boundary.
  Date/Author: 2026-03-27 / Codex

- Decision: Implement the collector mock with process-local state and rendered transcripts instead of a shared server.
  Rationale: The terminal side effects under test run synchronously in the current test process, so `Process.put/2` keeps async tests isolated with less setup and no global cleanup race. The collector still records user-visible transcript strings, which matches the testing goal better than recording raw callback arguments.
  Date/Author: 2026-03-27 / Codex


## Outcomes & Retrospective

Implementation is now underway. The first two milestones are complete: the repository now has a real `RR.Providers.Terminal` boundary, a production implementation, and a deterministic collector-backed test implementation with a small helper API. That removed the architecture risk around introducing the new provider and established a concrete testing seam before any caller rewiring. The next risk is migration accuracy: every `RR.CLI.Output` and direct `Owl.IO.*` call site now needs to move over without changing user-visible behavior.


## Context and Orientation

The top-level executable entry point is `lib/rr.ex`. It calls `RR.CLI.run/1`, converts `:ok` into exit code `0`, converts `{:error, message}` into exit code `1`, and writes errors through `RR.CLI.Output.error/1`. That means the main program path already has one choke point for terminal writes, but it is only a thin wrapper over raw `IO`.

The dispatcher is `lib/rr/cli.ex`. It parses argv, renders help and version output, and returns either `:ok` or `{:error, message}`. It currently renders help and version by calling `RR.CLI.Output.info_stdout/1`.

The output helper is `lib/rr/cli/output.ex`. Today it is not a behaviour and has no test seam. `info_stdout/1` calls `IO.puts(IO.ANSI.format(message))`, while `info_stderr/1` and `error/1` call `IO.puts(:stderr, message)`. The helper centralizes write formatting, but it does not isolate side effects.

Interactive input currently lives only in `lib/rr/cli/commands/login.ex`. The `prompt/0` function calls `Owl.IO.input/1` twice to read the Rancher hostname and token. The `execute/1` function also calls `Owl.IO.confirm/1` when the user already has a valid saved token and the command asks whether to overwrite it.

The service layer also performs terminal writes. `lib/rr/services/auth.ex` prints token-expiry warnings to stderr. `lib/rr/services/kubeconfigs.ex` prints informational stderr messages when an existing kubeconfig is reused or overwritten and when a new kubeconfig is saved. `lib/rr/services/aliases.ex` prints an alias-resolution notice to stderr. These writes show that the terminal boundary is used for orchestration and not only for top-level command rendering.

The provider pattern used elsewhere in the repo is important because the terminal provider must match it. `lib/rr/providers/rancher.ex`, `lib/rr/providers/settings_store.ex`, and `lib/rr/providers/auth_cache.ex` define callbacks, public delegating functions, and private `impl/0` helpers that resolve to `Impl` or `Mock` module suffixes according to `Application.get_env(:rr, :external_bound, ...)`. `config/dev.exs` and `config/prod.exs` set `:external_bound` to `Impl`; `config/test.exs` sets it to `Mock`. `test/test_helper.exs` currently defines `Mox` mocks for the other provider behaviours.

The current command tests rely on `ExUnit.CaptureIO`. `test/rr/cli_test.exs` captures help and version output from `RR.CLI.run/1`. `test/rr/cli/commands/list_test.exs`, `alias_test.exs`, `kf_test.exs`, and `yo_test.exs` capture stdout to assert on rendered command output. `test/rr/cli/commands/login_test.exs` uses `capture_io` and `with_io` to drive prompts and to assert on warnings. After this refactor, those tests should instead drive the terminal provider mock directly and inspect collected transcripts.


## Plan of Work

Begin by adding a new provider behaviour at `lib/rr/providers/terminal.ex`. This module should follow the same repository-local pattern as the existing provider modules. Define callbacks and public delegating functions for five operations: `info_stdout/1`, `info_stderr/1`, `error/1`, `input/1`, and `confirm/1`. The write functions should return `:ok`. The `input/1` function should accept the same keyword options currently passed to `Owl.IO.input/1` and should return the entered string. The `confirm/1` function should accept the same keyword options currently passed to `Owl.IO.confirm/1` and should return a boolean.

Then add the production implementation at `lib/rr/providers/terminal/impl.ex`. Preserve the existing rendering semantics exactly. `info_stdout/1` must continue to use `IO.ANSI.format/1` before writing with `IO.puts/1`. `info_stderr/1` and `error/1` must continue to write plain messages to stderr through `IO.puts(:stderr, ...)`. `input/1` and `confirm/1` should be thin wrappers over `Owl.IO.input/1` and `Owl.IO.confirm/1`. The goal is that the real CLI remains behaviorally unchanged after all call sites are rewired.

Add a test implementation at `lib/rr/providers/terminal/mock.ex`. This module should be a real collector, not a `Mox` mock. Use process-local state so async tests do not interfere with one another. The simplest acceptable design is a small set of helper functions backed by the process dictionary because the current command code runs synchronously in the test process and does not spawn worker processes to perform terminal IO. The mock should append writes to separate `stdout` and `stderr` transcripts and should include the newline that `IO.puts` would append. It should normalize stdout messages the same way the production implementation does, meaning ANSI-formatted iodata must become a binary before storage. For prompt-related functions, the mock should consume preloaded answers from a queue. It should also record a deterministic human-readable prompt transcript to stdout so tests can still assert that a prompt was shown, but it should not try to reproduce Owl control sequences or terminal cursor behavior.

Expose the collector control surface through a small, stable API on `RR.Providers.Terminal.Mock`. At minimum, define a reset function that clears process-local state, functions to preload input answers and confirmation answers, and functions to read the accumulated stdout and stderr transcripts as binaries. The tests should call this API directly; do not add a separate helper module unless the mock itself becomes too crowded. The provider-facing callbacks should stay exactly the same as the production implementation so `config/test.exs` can continue to switch the entire provider layer through `:external_bound`.

Once the provider exists, remove `lib/rr/cli/output.ex` as an active dependency. Update `lib/rr.ex`, `lib/rr/cli.ex`, `lib/rr/services/auth.ex`, `lib/rr/services/kubeconfigs.ex`, `lib/rr/services/aliases.ex`, and the command modules that currently alias `RR.CLI.Output` so they alias `RR.Providers.Terminal` instead. Keep the call shapes the same for writes so the migration is mostly mechanical.

Update `lib/rr/cli/commands/login.ex` more carefully because it currently uses both output and input side effects. Replace direct `Owl.IO.confirm/1` and `Owl.IO.input/1` calls with `RR.Providers.Terminal.confirm/1` and `RR.Providers.Terminal.input/1`. Preserve the current prompt labels and confirmation message text. The command's control flow should not change: an existing valid token still triggers a confirmation prompt, a false confirmation still returns `:ok`, and login still saves auth only after successful validation.

After the code path migration, update tests. In `test/test_helper.exs`, do not define a `Mox` mock for the new terminal provider because the mock is a real module. Leave the existing `Mox` setup for the other providers unchanged. Rewrite `test/rr/cli_test.exs` and the command tests to reset the collector in setup, preload answers when needed, execute the command or dispatcher, then assert on `RR.Providers.Terminal.Mock.stdout()` and `.stderr()` instead of `ExUnit.CaptureIO`. The login tests should preload both prompt answers and confirmation responses as needed, then assert on the collector transcripts and on side effects such as persisted settings or auth-cache writes. Remove `ExUnit.CaptureIO` usage from these test files entirely if the new provider covers all terminal interaction. If any test still needs IO capture for a reason unrelated to rr's own terminal boundary, document that reason in the plan before accepting the change as complete.

Finish by cleaning up any stale references to `RR.CLI.Output` and any stale imports of `ExUnit.CaptureIO` in the migrated tests. The repository should end with one terminal side-effect boundary, one real production implementation, and one deterministic collector implementation used automatically in test mode.


## Concrete Steps

Run all commands from the repository root `/Users/zili/code/rr`.

Before editing, inspect the current terminal side-effect usage:

    rg -n "RR\\.CLI\\.Output|Owl\\.IO\\.(input|confirm)|capture_io|with_io" lib test
    sed -n '1,220p' lib/rr/cli/output.ex
    sed -n '1,220p' lib/rr/cli/commands/login.ex

Implement the provider behaviour and both implementations, then migrate callers from `RR.CLI.Output` and `Owl.IO.*` to `RR.Providers.Terminal`.

After the migration, run formatting and compilation:

    mix format --check-formatted
    mix compile --warnings-as-errors

Then run the focused tests that prove the terminal boundary works:

    mix test test/rr/cli_test.exs
    mix test test/rr/cli/commands/alias_test.exs
    mix test test/rr/cli/commands/kf_test.exs
    mix test test/rr/cli/commands/list_test.exs
    mix test test/rr/cli/commands/login_test.exs
    mix test test/rr/cli/commands/yo_test.exs

Finish with the full suite:

    mix test

At the time this draft was written, the baseline suite output was:

    Running ExUnit with seed: 47632, max_cases: 20
    37 tests, 0 failures

Use a cleanup search before closing the work:

    rg -n "RR\\.CLI\\.Output|ExUnit\\.CaptureIO|Owl\\.IO\\.(input|confirm)" lib test

The expected end state is that `RR.CLI.Output` no longer appears in active code, command tests no longer depend on `ExUnit.CaptureIO`, and direct `Owl.IO.input/1` or `Owl.IO.confirm/1` calls no longer appear in `lib/`.


## Validation and Acceptance

Acceptance is behavioral, not architectural. The user-facing CLI must still print the same help, version, alias, list, kubeconfig, and login messages, and `rr login` must still prompt for hostname and token and still ask for overwrite confirmation when a valid token already exists.

Run the focused CLI tests and then `mix test`. The full suite must pass. The tests that currently use `capture_io` should instead assert through the terminal collector. In particular:

`test/rr/cli_test.exs` must still prove that `RR.CLI.run(["list", "--help"])` renders list help, `RR.CLI.run(["list", "unexpected"])` renders help before returning an error tuple, and `RR.CLI.run(["--version"])` writes the application version.

`test/rr/cli/commands/list_test.exs`, `alias_test.exs`, `kf_test.exs`, and `yo_test.exs` must still prove the same visible output as before, but they should now read from the collected stdout transcript. The `kf` path must still create the kubeconfig file on disk and the test should continue checking that side effect directly.

`test/rr/cli/commands/login_test.exs` must prove more than output. It must show that scripted prompt answers and confirmation answers drive the same control flow as before, that expiry warnings are still emitted to stderr, that successful login still persists auth, and that transient validation failures still do not save settings or auth-cache state.

The change is complete only if the real CLI behavior remains stable while terminal tests stop depending on Elixir's global IO capture.


## Idempotence and Recovery

This refactor is safe to perform incrementally, but the provider behaviour, implementations, and caller rewiring must land together before compilation will pass. If a partial migration produces undefined-function or missing-module errors, finish moving the remaining `RR.CLI.Output` or `Owl.IO.*` call sites before debugging deeper.

The collector mock should be safe for repeated use across test cases. Each migrated test file should reset collector state during setup so rerunning tests does not leak transcript or scripted answers from a prior example. If async tests begin interfering with one another, treat that as a design bug in the collector and fix the process-local storage before accepting the refactor.

If the attempt to mimic Owl prompt rendering becomes brittle, simplify the prompt transcript rather than reproducing terminal control codes. The contract that matters is stable, human-readable evidence that a prompt or confirmation happened and what answer was returned, not byte-for-byte fidelity to Owl's interactive terminal presentation.


## Artifacts and Notes

The terminal provider interface that must exist at the end of the refactor is:

    defmodule RR.Providers.Terminal do
      @callback info_stdout(IO.ANSI.ansidata() | iodata()) :: :ok
      @callback info_stderr(iodata()) :: :ok
      @callback error(iodata()) :: :ok
      @callback input(keyword()) :: String.t()
      @callback confirm(keyword()) :: boolean()

      def info_stdout(message), do: impl().info_stdout(message)
      def info_stderr(message), do: impl().info_stderr(message)
      def error(message), do: impl().error(message)
      def input(opts), do: impl().input(opts)
      def confirm(opts), do: impl().confirm(opts)
    end

The collector API that tests should use can remain small and explicit:

    RR.Providers.Terminal.Mock.reset()
    RR.Providers.Terminal.Mock.push_inputs(["https://rancher.example", "token-valid:abc"])
    RR.Providers.Terminal.Mock.push_confirms([false, true])
    RR.Providers.Terminal.Mock.stdout()
    RR.Providers.Terminal.Mock.stderr()

The important behavioral rule is that the collector stores rendered transcripts, not raw callback arguments. That keeps test assertions close to what a user actually sees.


## Interfaces and Dependencies

`lib/rr/providers/terminal.ex` must define the provider behaviour and public delegating functions. It must use the same `impl/0` pattern as the existing provider modules and must resolve `RR.Providers.Terminal.Impl` in dev and prod and `RR.Providers.Terminal.Mock` in test through the shared `:external_bound` setting.

`lib/rr/providers/terminal/impl.ex` must depend only on Elixir IO and Owl. It is the only place in the repository that should call `IO.puts/1`, `IO.puts(:stderr, ...)`, `Owl.IO.input/1`, or `Owl.IO.confirm/1` after this refactor is complete.

`lib/rr/providers/terminal/mock.ex` must be deterministic and must not depend on `Mox`. It is a real implementation selected by test config, not a generated expectation module. Its public helper API is part of the test contract and should stay stable once introduced.

`lib/rr.ex`, `lib/rr/cli.ex`, `lib/rr/cli/commands/login.ex`, `lib/rr/cli/commands/alias.ex`, `lib/rr/cli/commands/kf.ex`, `lib/rr/cli/commands/list.ex`, `lib/rr/cli/commands/yo.ex`, `lib/rr/services/auth.ex`, `lib/rr/services/kubeconfigs.ex`, and `lib/rr/services/aliases.ex` must call `RR.Providers.Terminal` for terminal side effects instead of any direct or helper-based terminal dependency.

This plan does not add new external dependencies. It continues using the existing `owl` package for production prompts and the existing provider-selection mechanism already present in the repo.


Plan revision note: 2026-03-27 10:11Z. Created this ExecPlan directly from the current codebase and the user-approved design discussion because the repository does not contain a matching `docs/product-specs/` source document for this refactor.
Plan revision note: 2026-03-27 04:08Z. Moved the ExecPlan into `docs/exec-plans/active/`, refreshed the repository guidance and current call-site inventory, and recorded the first implementation decisions so the document stays restartable while code changes begin.
Plan revision note: 2026-03-27 04:09Z. Marked the provider-behaviour milestone complete after adding the new terminal provider modules and verifying formatting plus compilation, so the plan reflects the exact landed baseline for the next migration step.
Plan revision note: 2026-03-27 04:14Z. Marked the collector milestone complete after adding `RR.Providers.Terminal.Mock`, validating the helper API in a dedicated test file, and recording the process-local state decision that keeps async tests isolated.
