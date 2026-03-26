# Centralize Command Parsing in RR.CLI

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository stores ExecPlan guidance in `docs/PLAN.md`. Maintain this document in accordance with `docs/PLAN.md`.


## Purpose / Big Picture

The `rr` command-line interface already separates top-level dispatch in `RR.CLI` from command-specific behavior in `lib/rr/cli/commands/`, but each command module still performs the same first step of parsing raw argv through `OptionParser`. After this change, `RR.CLI` will own that generic parsing step for every command. Command modules will stop accepting raw argv and will instead accept already-parsed `switches` and positional `rest`, then convert those trusted inputs into a typed action struct or a typed parse error.

For a maintainer, the result is easier to read because the common option-parsing pipeline exists in one place. For a contributor adding a new command, the contract becomes: declare the command's option spec, then implement how parsed inputs become an action. For a user, visible CLI behavior must remain the same. The easiest way to see the change working is to run the existing CLI parse and command tests and confirm that `rr list --help`, `rr yo`, `rr alias --list`, `rr kf dev --sh`, and `rr login extra` behave exactly as they do now.


## Progress

- [x] (2026-03-26 13:33Z) Drafted this ExecPlan from the current repository state, the agreed Approach 1 design, and the repository guidance in `docs/PLAN.md`.
- [x] (2026-03-26 14:03Z) Moved this ExecPlan from `docs/exec-plans/todo/` to `docs/exec-plans/active/` before implementation, per `docs/PLAN.md`.
- [x] (2026-03-26 14:10Z) Updated `RR.CLI.Command` to replace `parse/1` with `args_definition/0` and `build_action/2`, and added callback docs that spell out the centralized-help contract.
- [x] (2026-03-26 14:10Z) Refactored `RR.CLI.parse_command/2` to own `ArgParser.parse/3`, centralize `--help`, and normalize `build_action/2` results into `RR.CLI.Invocation` or `RR.CLI.ParseError`.
- [x] (2026-03-26 14:10Z) Converted `kf`, `alias`, `list`, `yo`, and `login` to the new behavior and removed their direct raw-argv parsing.
- [x] (2026-03-26 14:14Z) Updated dispatcher and command tests to match the new boundary, ran formatting plus compilation with warnings-as-errors, ran the focused CLI test files, and finished with `mix test` passing.


## Surprises & Discoveries

- Observation: This repository uses `docs/PLAN.md` rather than `docs/PLANS.md` as the ExecPlan source of truth.
  Evidence: `find docs -maxdepth 3 -type f | sort` lists `docs/PLAN.md`.

- Observation: The repo already contains a completed exec plan for a previous CLI parse/execute refactor, so this plan must describe only the current follow-up refactor and remain self-contained.
  Evidence: `docs/exec-plans/completed/parse-dont-validate-cli-refactor.md` exists and describes the current parse/execute split that is already present in the codebase.

- Observation: Four command modules repeat the same `ArgParser.parse(args, args_definition(), __MODULE__)` pattern, while `login` is the only remaining manual raw-argv parser.
  Evidence: `rg -n "ArgParser\\.parse\\(|def parse\\(" lib/rr/cli.ex lib/rr/cli/commands` shows the shared pattern in `kf`, `alias`, `list`, and `yo`, and a custom `parse/1` in `login`.

- Observation: Existing command tests exercise `parse/1` directly, so removing that callback will require deliberate test updates rather than a pure internal refactor.
  Evidence: `rg -n "\\.parse\\(" test/rr/cli/commands` shows direct command-level parse assertions in every command test file.

- Observation: `args_definition/0` was private in every command that already used `ArgParser`, so centralizing parsing in `RR.CLI` requires making that callback public in all five command modules.
  Evidence: `sed -n '1,240p' lib/rr/cli/commands/kf.ex` and the equivalent command-module reads showed `defp args_definition`.

- Observation: The cleanup search still finds `.parse(` calls in command tests, but only through `RR.CLI.parse/1` for centralized help assertions, which matches the intended boundary.
  Evidence: `rg -n "\\.parse\\(" test/rr/cli/commands` now returns only `CLI.parse(["<command>", "--help"])` assertions.


## Decision Log

- Decision: Use the "Approach 1" design and move the generic `ArgParser.parse/3` step into `RR.CLI.parse_command/2`.
  Rationale: The duplication being removed is not command-specific validation; it is the shared raw-argv tokenization step. Centralizing that step in `RR.CLI` makes the command pipeline explicit and keeps the dispatcher responsible for turning argv into trusted command inputs.
  Date/Author: 2026-03-26 / Codex

- Decision: Remove `parse/1` from `RR.CLI.Command` and from command modules rather than keeping a compatibility wrapper.
  Rationale: A wrapper would preserve two parsing contracts at once and weaken the new architecture. The codebase is small, and updating tests now is cheaper than carrying a transitional API.
  Date/Author: 2026-03-26 / User + Codex

- Decision: Name the new command callback `build_action/2`.
  Rationale: The callback no longer parses raw argv and it does not dispatch anything. Its job is to turn already-parsed switches and positional arguments into a typed action or parse error, and `build_action/2` states that role directly.
  Date/Author: 2026-03-26 / User + Codex

- Decision: Centralize command help handling in `RR.CLI.parse_command/2` and keep `build_action/2` focused on non-help semantics.
  Rationale: Help is uniform across commands and should not be re-implemented in five places. A command callback should only need to interpret real command inputs.
  Date/Author: 2026-03-26 / Codex

- Decision: Add callback documentation in `lib/rr/cli/command.ex` explaining what each callback is responsible for and what it must not do.
  Rationale: This refactor changes the command authoring model. Future developers need guidance at the behavior definition site, not only in tests or in an exec plan.
  Date/Author: 2026-03-26 / User + Codex

- Decision: Keep `normalize_command_result/2` strict by raising on any non-conforming `build_action/2` return value.
  Rationale: The new interface is small enough that silent coercion would hide contract regressions. Failing fast preserves the boundary between central parsing and command semantics.
  Date/Author: 2026-03-26 / Codex


## Outcomes & Retrospective

The refactor is complete. `RR.CLI` now owns raw argv parsing for every command, central help handling is uniform, and each command module implements only its option specification plus semantic action building. The visible CLI behavior remained stable across the paths called out in the plan: command help still renders, invalid positional args still surface the same command-specific parse errors, and the same action structs reach `execute/1`.

The final shape is smaller and easier to follow. A contributor adding a command now has one clear contract in `lib/rr/cli/command.ex`: declare `args_definition/0`, interpret parsed inputs in `build_action/2`, and keep side effects in `execute/1`. No command-specific edge case required relaxing the central-help decision or reintroducing a compatibility wrapper.

The main risk is interface churn in tests and command modules. That risk is acceptable because the repository is small, the commands are few, and the behavior change is mechanical once the central pipeline is in place. When implementation is complete, this section should record whether the new callback naming and documentation made command modules easier to follow, and whether any command-specific edge case required relaxing the central-help or no-wrapper decisions.


## Context and Orientation

The top-level CLI entrypoint is `lib/rr/cli.ex`. The `parse/1` function there handles root-level empty argv, root help, version flags, command lookup, and delegation into `parse_command/2`. Today `parse_command/2` does not parse raw args itself; it simply calls `module.parse(args)` and wraps the result into `RR.CLI.Invocation`.

The shared parser wrapper is `lib/rr/cli/arg_parser.ex`. It wraps Elixir's `OptionParser.parse/2` and converts invalid switches into `RR.CLI.ParseError` values that include the command module for help rendering. That module should remain the one place that translates `OptionParser` output into repository-specific parse errors.

The command behavior is `lib/rr/cli/command.ex`. Today it defines `parse/1`, `execute/1`, `summary/0`, and `help/0`. This file is where the new callback docs must live, because it is the first place a contributor will inspect to learn the command contract.

The command implementations are `lib/rr/cli/commands/kf.ex`, `lib/rr/cli/commands/alias.ex`, `lib/rr/cli/commands/list.ex`, `lib/rr/cli/commands/yo.ex`, and `lib/rr/cli/commands/login.ex`. `kf`, `alias`, `list`, and `yo` all call `ArgParser.parse/3` directly inside `parse/1`, and `login` manually pattern matches on raw argv. After this refactor, none of these modules should accept raw argv. They should only accept already-parsed `switches` and positional `rest`.

The command tests live in `test/rr/cli/commands/`. They currently assert against command `parse/1` functions directly. The top-level dispatcher tests live in `test/rr/cli_test.exs`. After implementation, the dispatcher tests should still prove that `RR.CLI.parse/1` produces the correct root help, invocation, and parse error outcomes, while command tests should prove that `build_action/2` interprets parsed inputs correctly.


## Plan of Work

Begin in `lib/rr/cli/command.ex`. Replace the `parse/1` callback with two callbacks: `args_definition/0` and `build_action/2`. Keep the existing `parse_result/1` type, because commands should still return either `{:ok, action}`, `{:ok, %RR.CLI.Help{}}`, or `{:error, %RR.CLI.ParseError{}}`. Add `@doc` text above each callback that explains the intent in plain language. `args_definition/0` should say that it returns the `OptionParser` definition used by `RR.CLI` to parse raw argv for the command, and that command authors should include the `help` switch if the command supports standard help flags. `build_action/2` should say that it receives already-parsed switches and remaining positional arguments, must convert them into a typed action or parse error, and should not perform side effects or raw argv parsing. `execute/1`, `summary/0`, and `help/0` should also keep short docs describing their responsibilities.

Next update `lib/rr/cli.ex`. Change `parse_command/2` so it no longer calls `module.parse(args)`. Instead, have it call `ArgParser.parse(args, module.args_definition(), module)`. When parsing succeeds, inspect the returned `switches`. If the `:help` key is present, return `{:ok, %Help{module: module}}` immediately without calling the command. Otherwise call `module.build_action(switches, rest)` and normalize the result into either `{:ok, %Invocation{module: module, action: action}}`, `{:ok, %Help{}}`, or `{:error, %ParseError{}}`. Keep the normalization logic strict so command modules cannot bypass the expected parse result shapes.

Then convert each command module. In `kf`, `alias`, `list`, `yo`, and `login`, remove the `ArgParser` alias and delete `parse/1`. Make `args_definition/0` public and mark it `@impl true`. For `kf`, move the body of the current `with {:ok, switches, rest} <- ...` block into `build_action/2` almost unchanged, but remove the help branch because `RR.CLI` now handles it. For `alias`, move the current semantic checks into `build_action/2` and keep the `--list` mode semantics exactly the same. For `list` and `yo`, `build_action/2` should reject any non-empty `rest` and otherwise return the empty action struct. For `login`, add `args_definition/0` with a `help: :boolean` switch and alias `h: :help`, then convert the raw-argv checks into `build_action/2` so it returns `%Login{}` only when `rest` is empty. None of these callbacks should print help or errors.

After the code changes, update tests. In `test/rr/cli_test.exs`, keep coverage for root help, version, unknown command, and command invocation through `CLI.parse/1` and `CLI.run/1`. In the command test files, replace `Command.parse([...])` assertions with one of two styles. For invalid switches or centralized help, assert through `RR.CLI.parse/1`, because those paths now belong to the dispatcher. For command-specific semantics, call `build_action/2` directly with parsed values such as `build_action([list: true], [])` or `build_action([], ["dev"])`. This split matches the new architecture and avoids reintroducing hidden raw-argv parsing in tests.

Finish with verification and cleanup. Run formatting, compilation with warnings as errors, and the full test suite. Search the tree to confirm there are no remaining command `parse/1` callbacks or stale `ArgParser` aliases in the command modules. If any command still contains a help branch inside `build_action/2`, remove it and keep the central-help rule intact.


## Concrete Steps

Run all commands from the repository root `/Users/zili/code/rr`.

First inspect the current interface and usage sites before editing so the migration stays consistent:

    rg -n "def parse\\(|ArgParser\\.parse\\(|@callback parse\\(" lib test
    sed -n '1,220p' lib/rr/cli/command.ex
    sed -n '1,220p' lib/rr/cli.ex

After implementing the behavior and dispatcher changes, verify the tree compiles cleanly:

    mix format --check-formatted
    mix compile --warnings-as-errors

Observed on 2026-03-26:

    $ mix format --check-formatted
    <no output; exit 0>

    $ mix compile --warnings-as-errors
    Compiling 7 files (.ex)
    Generated rr app

Then run the CLI and command tests that are most likely to fail if the contract is wrong:

    mix test test/rr/cli_test.exs
    mix test test/rr/cli/commands/list_test.exs
    mix test test/rr/cli/commands/yo_test.exs
    mix test test/rr/cli/commands/alias_test.exs
    mix test test/rr/cli/commands/kf_test.exs
    mix test test/rr/cli/commands/login_test.exs

Finally run the full suite:

    mix test

Observed on 2026-03-26:

    $ mix test test/rr/cli_test.exs
    7 tests, 0 failures

    $ mix test test/rr/cli/commands/list_test.exs
    5 tests, 0 failures

    $ mix test test/rr/cli/commands/yo_test.exs
    4 tests, 0 failures

    $ mix test test/rr/cli/commands/alias_test.exs
    6 tests, 0 failures

    $ mix test test/rr/cli/commands/kf_test.exs
    5 tests, 0 failures

    $ mix test test/rr/cli/commands/login_test.exs
    8 tests, 0 failures

    $ mix test
    37 tests, 0 failures

When searching for cleanup leftovers, the following commands should return only the non-command parser in `RR.CLI` and no `ArgParser` imports in command modules:

    rg -n "def parse\\(" lib/rr/cli lib/rr/cli/commands test
    rg -n "alias RR\\.CLI\\.ArgParser" lib/rr/cli/commands

Observed on 2026-03-26:

    $ rg -n "def parse\\(" lib/rr/cli lib/rr/cli/commands test
    lib/rr/cli/arg_parser.ex:8:  def parse(argv, option_spec, command_module) do

    $ rg -n "alias RR\\.CLI\\.ArgParser" lib/rr/cli/commands
    <no matches>


## Validation and Acceptance

Acceptance is behavioral. The user-visible CLI behavior must remain stable while the internal parsing contract changes.

Run `mix test` and expect the suite to pass. The command tests should prove that command semantics still reject bad positional arguments and still build the same action structs for valid inputs. The dispatcher tests should prove that `RR.CLI` still returns root help on `[]`, returns `%Invocation{module: List, action: %List{}}` on `["list"]`, returns command help on `["list", "--help"]`, and returns a `%ParseError{module: nil}` for an unknown command.

Manually exercise a few end-to-end paths through `RR.CLI.run/1` in `iex -S mix` if needed. `RR.CLI.run(["list", "--help"])` should print the `list` help text and return `:ok`. `RR.CLI.run(["list", "unexpected"])` should print the `list` help text and return an error tuple containing the same invalid-subcommand message as before. `RR.CLI.run(["login", "extra"])` should still reject the extra positional argument. `RR.CLI.run(["kf", "dev", "--sh"])` should still dispatch into the `kf` command if the test environment stubs allow it.

The contract change is successful only if command modules no longer parse raw argv, `RR.CLI` owns `ArgParser.parse/3`, help is handled centrally, and all tests remain green.


## Idempotence and Recovery

This refactor is safe to perform incrementally, but the behavior change should land in one branch as a coherent set because `RR.CLI` and the command modules must agree on the new callbacks. If compilation fails midway with missing callback errors, finish migrating all five commands before retrying the compile.

The edit sequence is idempotent. Re-running formatting and tests is safe. If a test update accidentally preserves assumptions from the old `parse/1` API, recover by moving that assertion either to `RR.CLI.parse/1` for dispatcher-owned behavior or to `build_action/2` for command-owned behavior. Do not reintroduce raw-argv wrappers merely to preserve old test shape.


## Artifacts and Notes

The key interface that must exist at the end of the change is:

    defmodule RR.CLI.Command do
      @type parse_result(action) ::
              {:ok, action}
              | {:ok, RR.CLI.Help.t()}
              | {:error, RR.CLI.ParseError.t()}

      @callback args_definition() :: keyword()
      @callback build_action(keyword(), [String.t()]) :: parse_result(term())
      @callback execute(term()) :: :ok | {:error, String.t()}
      @callback summary() :: String.t()
      @callback help() :: String.t()
    end

The most important behavior rule is that `build_action/2` is not a second parser for raw argv. It is a semantic interpreter for already-parsed data. If a future contributor feels the need to inspect raw `["--flag", "value"]` strings inside a command module, that is a sign the boundary has regressed.


## Interfaces and Dependencies

`RR.CLI.Command` in `lib/rr/cli/command.ex` must define the following callbacks and docs:

    @callback args_definition() :: keyword()
    @callback build_action(keyword(), [String.t()]) :: parse_result(term())
    @callback execute(term()) :: :ok | {:error, String.t()}
    @callback summary() :: String.t()
    @callback help() :: String.t()

`RR.CLI.parse_command/2` in `lib/rr/cli.ex` must depend on `RR.CLI.ArgParser.parse/3` for raw argv parsing. It must own central `:help` handling and must wrap non-help command actions into `%RR.CLI.Invocation{module: module, action: action}`.

Each command module under `lib/rr/cli/commands/` must expose `args_definition/0`, `build_action/2`, `execute/1`, `summary/0`, and `help/0`. The command-specific action structs such as `%RR.CLI.Commands.Kf{}` and `%RR.CLI.Commands.Alias.ListAction{}` remain in the command modules and are still the inputs to `execute/1`.

`RR.CLI.ArgParser` remains a thin wrapper over Elixir `OptionParser`. This plan does not introduce a command DSL, a macro-based parser generator, or new shared validation helpers beyond the existing `ArgParser.parse/3`.


Plan revision note: initial draft created because the repo lacks a `docs/product-specs/` source document for this refactor, so the plan was authored directly from the agreed design and current codebase state instead of being generated from a product spec.

Plan revision note: 2026-03-26 14:10Z. Moved the plan to `active/`, recorded the repo-level discovery that `args_definition/0` had to become public, and updated progress plus outcomes to reflect that the behavior, dispatcher, and command-module refactor is now implemented while test migration and validation remain.

Plan revision note: 2026-03-26 14:14Z. Recorded the completed test migration, added the actual verification transcripts, noted that remaining `.parse(` uses in command tests are now only centralized `CLI.parse/1` help assertions, and updated the retrospective to reflect the finished refactor before archiving.
