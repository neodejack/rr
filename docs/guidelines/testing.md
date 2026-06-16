# Testing

The test framework is ExUnit.

- Run `mix test` before finishing a behavior change.
- Use focused runs such as `mix test test/rr/cli/commands/kf_test.exs` while iterating.
- Add or update tests for CLI behavior changes and config/auth edge cases.

Mocks follow the provider boundary.

- Define callbacks in the provider module.
- Keep runtime code calling the provider facade, which dispatches through `impl()`.
- In tests, use the matching `*.Mock` module with `expect/3`.
- Use `setup :verify_on_exit!` when expectations should be enforced for the test process.

When a change touches packaging or dev-shell behavior, command-level unit tests are not sufficient on their own. Validate with the relevant `just dev ...` workflow.
