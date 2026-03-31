# Development Commands

These are the repository's canonical commands.

- `mix deps.get` installs dependencies.
- `mix compile` is the baseline compile and project health check.
- `mix test` runs the full ExUnit suite.
- `mix test path/to/test_file.exs` runs a focused test file while iterating.
- `mix format --check-formatted` verifies formatting.
- `mix format` applies formatting.
- `iex -S mix` starts the CLI in an interactive Elixir shell for local debugging.
- `just dev build` builds the local development binaries into `dev_out/bin/`.
- `just dev macos` opens the isolated macOS shell that aliases `rr` to the local macOS binary.
- `just dev linux` opens the isolated Linux shell that runs the Linux binary inside the shared Podman-based container environment.
- `MIX_ENV=prod BURRITO_TARGET=macos_arm mix release --overwrite` builds the local macOS arm64 release binary.
- `rr maintenance uninstall` clears Burrito's cached runtime when a same-version rebuild needs to be re-extracted.

`dev_out/home/macos` and `dev_out/home/linux` are disposable dev homes. They let you validate packaged behavior without mutating the real `~/.rr` directory.

The repo does not currently define a separate canonical typecheck step beyond `mix compile`. Treat compile, formatting, and tests as the minimum verification path unless a future change adds stricter automation.
