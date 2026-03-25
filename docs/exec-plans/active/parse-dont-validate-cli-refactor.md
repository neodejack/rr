# Refactor CLI Commands to Parse Then Execute

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository stores ExecPlan guidance in `docs/PLAN.md`. Maintain this document in accordance with `docs/PLAN.md`.


## Purpose / Big Picture

The `rr` CLI currently mixes command-line argument parsing and command execution in the same `run/1` path for each command. This makes the code hard to read because one function must handle invalid input, help text, mode selection, and business behavior all at once. After this refactor, every command will run in two explicit phases: a parse phase that converts raw argv into a typed command action, and an execution phase that only accepts already-parsed actions.

After implementation, maintainers will be able to read command behavior in isolation from input validation noise. End users will see the same command behavior and messages, but the code will be easier to reason about and safer to extend because impossible combinations of arguments are rejected before execution begins. You can see the change working by running command tests and new parser-focused tests, and by invoking local help/error scenarios such as `rr alias --help`, `rr alias --list`, and `rr list unexpected`.


## Progress

- [x] (2026-03-25 09:28Z) Drafted this ExecPlan from current repository state and aligned structure with `docs/PLAN.md` requirements.
- [x] (2026-03-25 09:31Z) Implemented command action data types and parsing boundary modules in `lib/rr/cli/`, then verified the repository still formats, compiles, and passes tests.
- [x] (2026-03-25 09:35Z) Migrated `yo` and `list` to explicit `parse/1` and `execute/1`, added parser-focused tests, and confirmed the full test suite still passes.
- [x] (2026-03-25 09:44Z) Migrated `alias` and `kf` to typed actions and pure parse functions, added new `alias` tests plus real `kf` coverage, and verified the full suite again.
- [ ] Migrate `login` and top-level `RR.CLI` dispatch/rendering to unified parse outcomes.
- [ ] Add parser-focused tests and run full validation (`mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`).
- [ ] Record completion outcomes and move this plan to `docs/exec-plans/completed/`.


## Surprises & Discoveries

- Observation: ExecPlan repository guidance uses `docs/PLAN.md` (singular) and not `docs/PLANS.md`.
  Evidence: `rg --files docs` shows `docs/PLAN.md`.

- Observation: Existing command coverage is uneven; `test/rr/cli/commands/kf_test.exs` is currently a placeholder and does not protect parse behavior.
  Evidence: the file contains an empty test body in the `describe "test response"` block.

- Observation: Several command modules currently emit help text as a side effect inside `parse_args/1`, which prevents parse logic from being pure.
  Evidence: `lib/rr/cli/commands/kf.ex`, `lib/rr/cli/commands/list.ex`, `lib/rr/cli/commands/yo.ex`, and `lib/rr/cli/commands/alias.ex` call `render_help/0` from `parse_args/1`.

- Observation: Adding the shared CLI boundary modules did not require touching existing command callers yet, so Milestone 1 could land as a compile-only structural change.
  Evidence: `mix compile --warnings-as-errors` and `mix test` both passed immediately after adding `RR.CLI.Help`, `RR.CLI.ParseError`, `RR.CLI.Invocation`, `RR.CLI.ArgParser`, and `RR.CLI.Command`.

- Observation: The existing command tests were compatible with transitional `run/1` wrappers, so parser-focused assertions could be added without rewriting current behavior tests.
  Evidence: after converting `yo` and `list`, `mix test test/rr/cli/commands/yo_test.exs`, `mix test test/rr/cli/commands/list_test.exs`, and `mix test` all passed.

- Observation: `alias` needed the help-outcome clause to be ordered before the generic success clause in its temporary `run/1` wrapper, or the compiler correctly flagged the help branch as unreachable.
  Evidence: `mix compile --warnings-as-errors` failed once with an unreachable-clause warning in `lib/rr/cli/commands/alias.ex`, then passed after reordering the case clauses.

- Observation: `kf` execution-path tests can avoid `kubectl` and live Rancher dependencies by exercising the overwrite path (`--new`) with mocked providers and a temporary `RR_HOME`.
  Evidence: `mix test test/rr/cli/commands/kf_test.exs` passed while writing a kubeconfig fixture under a temporary directory and rendering `export KUBECONFIG=...` from the real shell template.


## Decision Log

- Decision: Apply a two-phase command model for every CLI command: parse raw argv first, then execute typed actions.
  Rationale: This follows the repository goal for readability and maintainability by removing mixed responsibilities from `run/1` and making invalid states unrepresentable in execution paths.
  Date/Author: 2026-03-25 / Amp

- Decision: Keep user-visible behavior stable while changing internals, including support for existing `run/1` entrypoints during migration.
  Rationale: Incremental migration reduces risk and keeps existing tests and call sites working while command modules are converted one by one.
  Date/Author: 2026-03-25 / Amp

- Decision: Use small explicit structs for parsed command actions instead of introducing a macro-based command DSL.
  Rationale: The current command count is small, and explicit structs keep the refactor clear for novice contributors while still enforcing parse-time guarantees.
  Date/Author: 2026-03-25 / Amp

- Decision: Keep each migrated command’s compatibility `run/1` wrapper responsible for rendering help and returning parse-error messages until `RR.CLI` takes over that work in Milestone 4.
  Rationale: This preserves current user-visible behavior while allowing command-local parse functions to become side-effect free immediately.
  Date/Author: 2026-03-25 / Codex

- Decision: Model `alias` actions with separate `%ListAction{}` and `%SetAction{}` structs instead of one struct with mode flags.
  Rationale: The command has two mutually exclusive behaviors, and separate action types let `execute/1` pattern match each mode without runtime branching on options or missing fields.
  Date/Author: 2026-03-25 / Codex


## Outcomes & Retrospective

Milestone 1 is complete. The repository now has explicit shared types for help, parse errors, and parsed invocations, plus a command behavior and shared option parser wrapper. User-visible behavior is unchanged so far, which is the intended outcome for this first milestone because it reduces structural risk before migrating individual commands.

Milestone 2 is also complete. `yo` and `list` now expose pure `parse/1` functions and action-only `execute/1` functions, while their legacy `run/1` entrypoints still preserve current help and error rendering. Parser-specific tests now cover help requests and invalid positional arguments for these commands.

Milestone 3 is complete. `alias` now parses into distinct list and set actions, and `kf` now parses its cluster and flags into a single trusted action struct before any side effects begin. Tests now cover invalid `alias`/`kf` argument combinations at parse time plus one real `kf` execution path that exercises kubeconfig output generation without external connectivity.


## Context and Orientation

`rr` is an Elixir CLI application. The process entrypoint is `lib/rr.ex`, which calls `RR.CLI.run/1` in `lib/rr/cli.ex`. Command modules live under `lib/rr/cli/commands/` and currently expose `run/1` functions that both parse argv and execute behavior.

The command files in scope are:

`lib/rr/cli/commands/yo.ex`, `lib/rr/cli/commands/list.ex`, `lib/rr/cli/commands/alias.ex`, `lib/rr/cli/commands/kf.ex`, and `lib/rr/cli/commands/login.ex`.

The main problem is not that validation is missing; it is that validation is intermixed with runtime logic. In this plan, “parse” means converting untrusted argv values into trusted Elixir data that can only represent valid command actions. “Execute” means performing side effects (service calls, file writes, output rendering) from those trusted values. Any invalid user input must be handled before execution starts.

`RR.CLI.Output` in `lib/rr/cli/output.ex` is the centralized output helper and should remain the single place where user-facing stdout/stderr printing functions are defined.

Tests currently live under `test/rr/cli/commands/` and should be expanded so that each migrated command has parse behavior coverage in addition to existing execution behavior coverage.


## Plan of Work

The implementation is split into five milestones so each step is independently verifiable and safe to repeat. Each milestone keeps the test suite passing and preserves current behavior.


### Milestone 1: Add Parse Boundary Types and Shared Parser Helper

This milestone introduces common data structures for parse outcomes and a shared OptionParser wrapper, without changing command behavior yet. By the end of this step, there will be a consistent way to express three parse outcomes: successful parsed action, help request, and parse error.

Create `lib/rr/cli/help.ex` with `%RR.CLI.Help{module: module | nil}`. A `nil` module means root help; a command module means command-specific help.

Create `lib/rr/cli/parse_error.ex` with `%RR.CLI.ParseError{message: String.t(), module: module | nil, exit_code: integer}` and set `@enforce_keys [:message]`.

Create `lib/rr/cli/invocation.ex` with `%RR.CLI.Invocation{module: module, action: struct}` as a parsed dispatch unit.

Create `lib/rr/cli/arg_parser.ex` with `parse(argv, option_spec, command_module)` that wraps `OptionParser.parse/2` and converts invalid option tuples into `%RR.CLI.ParseError{}`.

Create `lib/rr/cli/command.ex` as a behavior that defines `parse/1`, `execute/1`, `summary/0`, and `help/0` callbacks.

Acceptance for this milestone: project compiles with new modules, and no existing tests fail.


### Milestone 2: Convert `yo` and `list` to Parse/Execute Split

This milestone migrates the two simplest commands (`yo` and `list`) first so the pattern is validated on low-risk modules before touching the more complex ones.

Update `lib/rr/cli/commands/yo.ex` so `parse/1` returns either `%RR.CLI.Commands.Yo{}` (empty action struct), `%RR.CLI.Help{}`, or `%RR.CLI.ParseError{}`. Keep help text and command summary inside the module, but stop printing during parse.

Add `execute/1` to `RR.CLI.Commands.Yo` that accepts only `%RR.CLI.Commands.Yo{}` and performs template rendering. Keep a compatibility `run/1` wrapper that calls `parse/1` and `execute/1` until all commands are migrated.

Apply the same shape to `lib/rr/cli/commands/list.ex` with `%RR.CLI.Commands.List{}` as parsed action.

Add tests in `test/rr/cli/commands/yo_test.exs` and `test/rr/cli/commands/list_test.exs` for parse outcomes, including help and unexpected positional args.

Acceptance for this milestone: existing command behavior tests still pass, and new parser tests for `yo` and `list` pass.


### Milestone 3: Convert `alias` and `kf` with Mode-Specific Actions

This milestone handles the commands with the most branching and therefore the highest readability payoff.

In `lib/rr/cli/commands/alias.ex`, define nested action structs:

    defmodule RR.CLI.Commands.Alias.ListAction do
      defstruct []
    end

    defmodule RR.CLI.Commands.Alias.SetAction do
      @enforce_keys [:alias_name, :full_name]
      defstruct [:alias_name, :full_name]
    end

Then make `parse/1` return `%ListAction{}` or `%SetAction{}` for valid inputs and never allow mixed states such as `--list` with positional args. `execute/1` must pattern match on action struct type and avoid runtime mode checks.

In `lib/rr/cli/commands/kf.ex`, define `%RR.CLI.Commands.Kf{cluster: String.t(), sh?: boolean(), new?: boolean()}` and move all positional/flag shape checks into parse phase. `execute/1` should only orchestrate service call and output formatting.

Expand tests by replacing placeholder `test/rr/cli/commands/kf_test.exs` with meaningful parse and execution-path coverage, and add `alias` tests in a new file `test/rr/cli/commands/alias_test.exs`.

Acceptance for this milestone: `alias` and `kf` no longer contain parsing side effects, and tests demonstrate that invalid combinations are rejected at parse time.


### Milestone 4: Convert `login` and Centralize Top-Level Parse Rendering

This milestone completes command conversion and simplifies `RR.CLI` to be a parser/dispatcher.

Update `lib/rr/cli/commands/login.ex` to expose `%RR.CLI.Commands.Login{}` parse action. Reject extra args in parse phase only; keep interactive prompting and auth flow in `execute/1`.

Update `lib/rr/cli.ex` so top-level `run/1` parses argv into one of these outcomes:

`{:ok, %RR.CLI.Help{}}`, `{:ok, %RR.CLI.Invocation{}}`, or `{:error, %RR.CLI.ParseError{}}`.

Keep root-level flags (`--help`, `-h`, `--version`, `-v`) as top-level parser outcomes. For unknown commands, return `%RR.CLI.ParseError{module: nil}` instead of ad hoc tuples.

Add rendering functions in `RR.CLI` for help and parse errors so command parsers are side-effect free.

Acceptance for this milestone: command modules no longer print help or errors during parse, and top-level dispatch behavior remains unchanged for end users.


### Milestone 5: Remove Transitional Noise, Verify, and Archive

This milestone removes temporary compatibility wrappers if they are no longer needed, tightens tests, and confirms the refactor is complete and stable.

Delete dead parse helpers or duplicate option definitions left over during migration. Keep naming and module structure consistent with command files under `lib/rr/cli/commands/`.

Run formatting, compile, and test commands. Confirm there are no references to old `parse_args/1` patterns in command modules except where explicitly retained for compatibility with a clear comment.

Update this ExecPlan sections (`Progress`, `Surprises & Discoveries`, `Decision Log`, `Outcomes & Retrospective`) with implementation evidence, then move file to `docs/exec-plans/completed/parse-dont-validate-cli-refactor.md`.

Acceptance for this milestone: complete test suite passes, behavior remains stable, and this plan records final outcomes.


## Concrete Steps

Run all commands from repository root `/Users/zili/code/rr`.

Begin by creating the new boundary modules and command changes milestone by milestone, then run these commands after each milestone:

    mix format
    mix compile --warnings-as-errors
    mix test

During migration, use this search to confirm command modules are moving away from mixed parsing logic:

    rg -n "defp parse_args|render_help\(\)" lib/rr/cli/commands

Expected direction of results over time: fewer `parse_args` matches, and eventually no `render_help()` calls from parse functions.

To verify command parse behavior without Rancher connectivity, run targeted tests:

    mix test test/rr/cli/commands/yo_test.exs
    mix test test/rr/cli/commands/list_test.exs
    mix test test/rr/cli/commands/kf_test.exs
    mix test test/rr/cli/commands/alias_test.exs
    mix test test/rr/cli/commands/login_test.exs

For quick manual checks of parse boundary behavior after Milestone 4, run the compiled CLI through Mix when practical and compare outputs:

    iex -S mix
    RR.CLI.run(["list", "unexpected"])
    RR.CLI.run(["alias", "--list"])
    RR.CLI.run(["alias", "short", "production"])
    RR.CLI.run(["yo", "--help"])

Expected behavior: invalid argv returns error result and prints one parse error path; help requests print help text without invoking business logic.


## Validation and Acceptance

Acceptance is behavior-focused and must be verifiable by a human and by tests.

Run `mix test` and confirm all command tests pass, including new parse-specific cases that prove invalid arguments are rejected before execution logic runs.

Run `mix compile --warnings-as-errors` and confirm there are no compiler warnings introduced by new modules or behavior callbacks.

Manually verify these scenarios in `iex -S mix` by calling `RR.CLI.run/1`:

1. `RR.CLI.run(["alias", "--list"])` uses list action and returns `:ok`.
2. `RR.CLI.run(["alias", "--list", "extra"])` returns an error without mutating aliases.
3. `RR.CLI.run(["kf"])` returns a parse error indicating missing cluster input.
4. `RR.CLI.run(["list", "--help"])` renders list help.
5. `RR.CLI.run(["unknown"])` returns unknown-command parse error from top-level parser.

The key proof is that command execution functions no longer contain argument-shape branching, and parse functions no longer perform command business side effects.


## Idempotence and Recovery

This refactor is structural and can be applied incrementally. Every milestone ends with a full compile/test run, so failures are isolated to the most recent edits.

All steps are safe to rerun: formatting, compile, and tests are idempotent. If a migration step fails midway, re-run `mix format`, then `mix compile --warnings-as-errors`, then `mix test` to re-establish a known state.

When introducing transitional wrappers (legacy `run/1` delegating to `parse/1` and `execute/1`), keep them until the corresponding top-level dispatch path is migrated, then remove them in Milestone 5 to avoid dead compatibility code.


## Artifacts and Notes

Expected command module shape after migration:

    defmodule RR.CLI.Commands.List do
      @behaviour RR.CLI.Command
      defstruct []

      def parse(argv), do: ...
      def execute(%__MODULE__{}), do: ...

      # Temporary while migrating callers:
      def run(argv) do
        with {:ok, action} <- parse(argv) do
          execute(action)
        end
      end
    end

Expected parse-outcome flow in `RR.CLI.run/1`:

    case parse(argv) do
      {:ok, %RR.CLI.Help{} = help} -> render_help(help)
      {:ok, %RR.CLI.Invocation{module: mod, action: action}} -> mod.execute(action)
      {:error, %RR.CLI.ParseError{} = err} -> render_parse_error(err)
    end


## Interfaces and Dependencies

In `lib/rr/cli/command.ex`, define:

    defmodule RR.CLI.Command do
      @type parse_result(action) ::
              {:ok, action}
              | {:ok, RR.CLI.Help.t()}
              | {:error, RR.CLI.ParseError.t()}

      @callback parse([String.t()]) :: parse_result(term())
      @callback execute(term()) :: :ok | {:error, String.t()}
      @callback summary() :: String.t()
      @callback help() :: String.t()
    end

In `lib/rr/cli/arg_parser.ex`, define:

    @spec parse([String.t()], keyword(), module()) ::
            {:ok, keyword(), [String.t()]} | {:error, RR.CLI.ParseError.t()}

`RR.CLI.ArgParser.parse/3` must be the only place where raw `OptionParser.parse/2` invalid option tuples are normalized into command parse errors.

In each command module under `lib/rr/cli/commands/`, execution functions must accept parsed action structs only. Direct execution signatures should not accept raw argv once the migration is complete.

This refactor must continue using existing service modules (`RR.Services.Auth`, `RR.Services.Clusters`, `RR.Services.Kubeconfigs`, `RR.Services.Aliases`) and existing output module (`RR.CLI.Output`) to avoid expanding scope beyond command-boundary design.


Revision note (2026-03-25): Created this plan to guide a full “parse then execute” refactor for CLI commands, because command modules currently mix argument parsing, help/error rendering, and execution logic. The plan resolves that ambiguity with milestone-by-milestone implementation and verifiable acceptance criteria.

Revision note (2026-03-25): Updated the plan after completing Milestone 1 so progress, discoveries, and outcomes reflect the new shared CLI boundary modules and successful verification runs.

Revision note (2026-03-25): Updated the plan after completing Milestone 2 to document the `yo` and `list` migration, the temporary wrapper strategy, and the parser-focused verification coverage now in place.

Revision note (2026-03-25): Updated the plan after completing Milestone 3 to record the typed `alias` and `kf` action design, the temporary wrapper warning fix, and the new execution-path testing strategy for kubeconfig output.
