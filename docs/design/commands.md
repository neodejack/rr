# Commands

## What commands are

Commands are the user-facing entrypoints of the `rr` CLI. They turn parsed argv into a typed action and then execute that action.

In this repository, command modules live in `lib/rr/cli/commands/*.ex`. Examples:

- `RR.CLI.Commands.Login`
- `RR.CLI.Commands.List`
- `RR.CLI.Commands.Kf`
- `RR.CLI.Commands.Alias`
- `RR.CLI.Commands.Yo`

Each command module owns one command name, its help text, its parsing rules after dispatch, and the execution of its typed action.

## How commands work

The command flow in this repository is:

1. `RR.CLI.parse/1` handles top-level cases such as empty argv, `--help`, `-h`, `--version`, and `-v`.
2. `RR.CLI` looks up the command module in its `@commands` map.
3. `RR.CLI.ArgParser.parse/3` parses switches using the command's `args_definition/0`.
4. The command module's `build_action/2` turns parsed switches and positional args into either:
   - `{:ok, action_struct}`
   - `{:error, %RR.CLI.ParseError{}}`
5. `RR.CLI.run/1` executes the returned action by calling `module.execute(action)`.

That means command modules do not receive raw argv. They receive already-parsed switches and positional args, then translate them into a typed action that the rest of the command can execute.

## The command contract

Commands implement the `RR.CLI.Command` behaviour in `lib/rr/cli/command.ex`.

Each command must provide:

- `args_definition/0`: the `OptionParser` spec used by `RR.CLI.ArgParser`
- `build_action/2`: pure translation from parsed input to a typed action or parse error
- `execute/1`: runtime behavior for the typed action
- `summary/0`: the one-line description shown in top-level help
- `help/0`: the full help text for the command

When adding a new command, also register it in the `@commands` map in `lib/rr/cli.ex`.

## Conventions for writing command code

When adding or changing a command, follow these rules.

### 1. Keep each command module focused on one CLI surface

A command module should represent one command name and live at:

- `lib/rr/cli/commands/<name>.ex`

If the command needs multiple behaviors, model them as distinct action structs inside the same module, as `RR.CLI.Commands.Alias` does with `ListAction` and `SetAction`.

### 2. Use typed action structs

`build_action/2` should return a struct that captures the parsed intent of the command.

Examples in the current codebase:

- `%RR.CLI.Commands.Login{}`
- `%RR.CLI.Commands.List{}`
- `%RR.CLI.Commands.Kf{cluster: ..., sh?: ..., new?: ...}`
- `%RR.CLI.Commands.Alias.ListAction{}`
- `%RR.CLI.Commands.Alias.SetAction{}`

Do not pass raw argv deeper into the system once parsing is complete.

### 3. Keep `build_action/2` pure

`build_action/2` should only validate parsed switches and positional args, then return either a typed action or `%RR.CLI.ParseError{}`.

Do not perform side effects in `build_action/2`.

In particular, do not:

- call providers
- read or write files
- prompt the terminal
- call network APIs

That work belongs in `execute/1` or deeper service/provider layers.

### 4. Let `RR.CLI` own raw argv parsing and help dispatch

Top-level parsing behavior is centralized in `RR.CLI` and `RR.CLI.ArgParser`.

Follow the existing pattern:

- define switch parsing in `args_definition/0`
- include the standard `help: :boolean` switch when the command supports `--help`
- add `alias: [h: :help]` for `-h`
- rely on `RR.CLI.parse/1` to turn `--help` into `%RR.CLI.HelpAction{}`

Do not special-case raw `--help` handling inside `build_action/2` unless the command design truly requires something different.

### 5. Keep `execute/1` thin and service-oriented

Commands are the boundary between parsed CLI input and the application logic. Keep domain logic in services and side effects behind providers.

Typical command responsibilities:

- call one or more service modules
- translate a typed action into service inputs
- render final user-visible output through `RR.Providers.Terminal`

Avoid putting reusable business rules directly in command modules when that logic belongs in `lib/rr/services/`.

### 6. Route user-visible output through the terminal provider

Commands should render output through `RR.Providers.Terminal`, not direct `IO` calls.

Current examples include:

- `Terminal.info_stdout/1`
- `Terminal.input/1`
- `Terminal.confirm/1`

This keeps terminal interaction mockable in tests and consistent with the rest of the repository.

### 7. Return repository-standard results

Follow the current command return shape:

- `:ok` for success
- `{:error, message}` for user-visible failures

For argument errors, return `%RR.CLI.ParseError{}` from `build_action/2` rather than ad-hoc tuples or raised exceptions.

### 8. Keep help text and summaries accurate

Every command should have:

- a short `summary/0` for `rr --help`
- a `help/0` string that shows usage and flags

When adding or changing flags, positional args, or sub-actions, update `help/0` at the same time.

### 9. Keep registration and file layout predictable

When creating a new command, update all of the expected places:

1. Add the command module under `lib/rr/cli/commands/`.
2. Add the command to the `@commands` map in `lib/rr/cli.ex`.
3. Add mirrored tests under `test/rr/cli/commands/`.

Agents should treat those three steps as part of the command change, not as optional follow-up cleanup.

## Checklist for a new command

When adding a new command:

1. Create `lib/rr/cli/commands/<name>.ex`.
2. Implement the `RR.CLI.Command` callbacks.
3. Add a typed action struct, or multiple action structs if the command has multiple modes.
4. Define `args_definition/0` using the existing `OptionParser` pattern, including `--help` and `-h` when supported.
5. Keep `build_action/2` pure and return `%RR.CLI.ParseError{}` for invalid input.
6. Keep `execute/1` focused on orchestration, service calls, and terminal rendering.
7. Register the command in `lib/rr/cli.ex`.
8. Add tests in `test/rr/cli/commands/<name>_test.exs`.
9. Verify `summary/0` and `help/0` reflect the actual command behavior.

## Testing conventions for commands

Command tests live under `test/rr/cli/commands/` and should usually cover both parsing and execution behavior.

Typical expectations in this repository:

- `build_action/2` returns the expected typed action
- invalid input returns `%RR.CLI.ParseError{}`
- `RR.CLI.parse/1` centralizes `--help` handling for the command
- `execute/1` delegates correctly and renders terminal output through mocks

Prefer testing commands through their public surface rather than calling private helpers.

## Rule of thumb

If a command module starts owning raw argv parsing, complex domain rules, or direct side effects that bypass providers and services, the command layer has become too heavy.
