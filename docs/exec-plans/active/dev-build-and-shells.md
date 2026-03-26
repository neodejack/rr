# Add Repo-Local Dev Build and Interactive Test Shells

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository stores ExecPlan guidance in `docs/PLAN.md`. Maintain this document in accordance with `docs/PLAN.md`.


## Purpose / Big Picture

`rr` is currently awkward to manual-test during development because the installed Homebrew binary and the default `~/.rr` state are both production-facing. A local Burrito build is useful, but today there is no repeatable, isolated workflow that gives the developer an interactive shell where `rr` points at the new build while keeping `RR_HOME` away from real data.

After this change, a maintainer will be able to run `just dev build` once to produce local development binaries under `dev_out/bin/`, then enter either `just dev macos` or `just dev linux` to get an interactive shell that behaves like a small manual-test sandbox. In those shells, `rr` will point at the freshly built binary, `RR_HOME` will point at repo-local test state under `dev_out/home/`, and the first shell launch will copy `~/.rr/config.json` into that test state so the developer can exercise real commands without mutating production config. The change is working when a maintainer can run `rr --help` and a real command such as `rr list` inside both shells, confirm `RR_HOME` points at `dev_out/home/...`, and confirm that no files under `~/.rr` changed.


## Progress

- [x] (2026-03-26 11:19Z) Drafted this ExecPlan from the repository state and from the agreed manual-testing workflow.
- [x] (2026-03-26 11:20Z) Verified that `just` submodules work in practice with `mod dev` and `just dev build`, so the command shape in this plan is feasible.
- [x] (2026-03-26 12:08Z) Added the root `justfile` import for the `dev` submodule, defined the `build`, `macos`, and `linux` recipes in `dev.just`, added first-pass helper scripts under `scripts/dev/`, and ignored `dev_out/`.
- [ ] Add a single shared `Dockerfile.dev` that provides the Linux toolchain used by both `just dev build` and `just dev linux`.
- [ ] Add helper scripts that keep `dev.just` readable and implement the binary export, one-time config seeding, and interactive shell bootstrapping.
- [ ] Document the new workflow in `README.md`.
- [ ] Validate `just dev build`, `just dev macos`, and `just dev linux`, then update this plan with evidence and move it to `docs/exec-plans/completed/`.


## Surprises & Discoveries

- Observation: This repository stores ExecPlan guidance in `docs/PLAN.md` (singular), not `docs/PLANS.md`.
  Evidence: `rg --files docs` shows `docs/PLAN.md`.

- Observation: The current root `justfile` is minimal and does not already contain any grouping or dev-shell workflow to extend.
  Evidence: `just --dump` shows only `list` and `upgrade_rr`.

- Observation: `just --list-submodules --list` prints root recipes before submodule recipes, so the exact listing order is `list`, `upgrade_rr`, then the `dev` group.
  Evidence: the first milestone verification printed those entries in that order after `mod dev` was added.

- Observation: `just` submodules are a working way to implement the exact command surface `just dev build`.
  Evidence: a temporary throwaway `justfile` with `mod foo` and `foo.just` successfully ran `just foo bar`.

- Observation: The GitHub Actions release workflow already proves that Burrito can produce the shipping binaries from Linux with a single `MIX_ENV=prod mix release` invocation.
  Evidence: `.github/workflows/release.yml` installs Elixir `1.18.3`, OTP `27.3.4.6`, Zig `0.15.1`, then runs `MIX_ENV=prod mix release` and packages `burrito_out/rr_*`.

- Observation: `RR_HOME` is already the supported override for local state, so the new workflow does not need new application code for config isolation.
  Evidence: `lib/rr/config/paths.ex` reads `System.get_env("RR_HOME")` before falling back to `~/.rr`.

- Observation: `.gitignore` already ignores `/burrito_out/` but does not ignore `dev_out/`, so this plan must add it.
  Evidence: `.gitignore` contains `/burrito_out/` and no `dev_out` entry.

- Observation: Docker is not installed in the current planning environment, so the Docker commands in this plan were designed from repository context and tool behavior, not by executing them here.
  Evidence: `docker version` returned `command not found`.


## Decision Log

- Decision: Store all developer-facing build outputs and isolated manual-test state under repo-local `dev_out/`.
  Rationale: The user explicitly rejected a hidden `.dev-state` directory and wants a single visible place for binaries and test homes. `dev_out/` also makes cleanup simple and keeps the workflow self-explanatory for a novice.
  Date/Author: 2026-03-26 / Codex

- Decision: Expose the workflow through a `just` submodule so the public interface is exactly `just dev build`, `just dev macos`, and `just dev linux`.
  Rationale: This matches the agreed command shape and keeps the root `justfile` concise.
  Date/Author: 2026-03-26 / Codex

- Decision: Use one shared `Dockerfile.dev` for both the build environment and the Linux interactive shell.
  Rationale: The build and Linux shell need the same Linux distribution and developer tooling. A single image reduces duplication and keeps the workflow easier to understand. There is no need for a second smaller runtime image at this scope.
  Date/Author: 2026-03-26 / Codex

- Decision: Make `just dev build` produce exactly two copied artifacts, `dev_out/bin/rr_macos_arm` and `dev_out/bin/rr_linux`.
  Rationale: Those are the only binaries needed for the agreed manual-test workflow. Copying only the needed artifacts avoids unnecessary churn in `dev_out/`.
  Date/Author: 2026-03-26 / Codex

- Decision: Seed the isolated homes by copying only `~/.rr/config.json`, and do so only if the destination config does not already exist.
  Rationale: This gives the developer a usable starting point while preserving changes made during manual testing. It also avoids copying production kubeconfigs or other production state into the sandbox.
  Date/Author: 2026-03-26 / Codex

- Decision: Keep separate test homes for macOS and Linux at `dev_out/home/macos` and `dev_out/home/linux`.
  Rationale: The two shells should feel similar, but their generated files and experiments should not interfere with each other.
  Date/Author: 2026-03-26 / Codex

- Decision: Keep the first milestone helper scripts as explicit placeholders that fail fast until the Docker build flow and interactive shell setup are implemented.
  Rationale: This preserves the final `just dev ...` command surface immediately, keeps the recipes readable, and avoids pretending the later milestones already work.
  Date/Author: 2026-03-26 / Codex


## Outcomes & Retrospective

Milestone 1 is complete. The repository now exposes `just dev build`, `just dev macos`, and `just dev linux` through a `just` submodule, the helper script layout exists under `scripts/dev/`, and `dev_out/` is ignored. The commands are intentionally not functional yet: they fail with direct milestone-progress messages until the Docker image and interactive shell work lands in the next milestones.


## Context and Orientation

`rr` is an Elixir command-line application. The CLI entrypoint is `lib/rr.ex`. The packaged binaries are built by Burrito through Mix release configuration in `mix.exs`. The release workflow in `.github/workflows/release.yml` is important because it already contains the known-good Linux build toolchain for all Burrito targets: Elixir `1.18.3`, Erlang/OTP `27.3.4.6`, and Zig `0.15.1`.

The current root automation file is `justfile`, and it currently contains only two recipes. This plan will add a `just` submodule file named `dev.just` and import it from the root `justfile` using `mod dev`. In `just`, a submodule is a second recipe file that lets the user run commands such as `just dev build`.

The application already supports state isolation. `lib/rr/config/paths.ex` resolves the application home directory by first reading the environment variable `RR_HOME`, then falling back to `~/.rr`. That means the manual-test shells in this plan do not need any application-level feature work to redirect config and kubeconfig files. They only need to set `RR_HOME` before launching the shell.

The output directory defined by this plan is `dev_out/`. It will have three subtrees:

    dev_out/bin/rr_macos_arm
    dev_out/bin/rr_linux
    dev_out/home/macos/
    dev_out/home/linux/

The developer will continue to build and run the normal project with Mix exactly as before. The new workflow is additive. It creates a safe manual-test sandbox without changing how the real installed `rr` behaves.


## Plan of Work

Implement this change in three milestones so each step leaves the repository in a usable, testable state.

The first milestone introduces the automation scaffolding. Update the root `justfile` to add `mod dev`, then create `dev.just` with three public recipes named `build`, `macos`, and `linux`. These recipes should not contain large blocks of shell logic. Instead, create a small helper directory `scripts/dev/` with focused scripts so a novice can read the control flow without wading through quoting rules. Add `scripts/dev/build.sh` to perform the release build inside the Linux container, and add `scripts/dev/macos-shell.sh` and `scripts/dev/linux-shell.sh` to prepare the isolated homes and launch the appropriate shell. Add `/dev_out/` to `.gitignore` in the same milestone so repeated local runs do not dirty the repository.

The second milestone builds the shared Docker environment. Create `Dockerfile.dev` at the repository root. This file should install the same Elixir, OTP, and Zig versions used in `.github/workflows/release.yml`. Treat this image as a reusable developer environment rather than an image that bakes the repository source into itself. The `just dev build` recipe should first build this image with a stable local tag such as `rr-dev-env`, then run a container from it with the repository mounted at `/workspace`. Inside that container, `scripts/dev/build.sh` should run from `/workspace`, execute `mix deps.get --only prod`, `mix compile`, and `MIX_ENV=prod mix release`, then copy `burrito_out/rr_macos_arm` to `dev_out/bin/rr_macos_arm` and `burrito_out/rr_linux` to `dev_out/bin/rr_linux`. The copy destination should be a host-mounted `dev_out/bin/` directory so the container can exit cleanly without any later `docker cp` step.

The third milestone adds the interactive manual-test shells. `scripts/dev/macos-shell.sh` should ensure `dev_out/home/macos` exists, copy `~/.rr/config.json` into `dev_out/home/macos/config.json` if that file does not already exist, then launch an interactive `zsh` in the current terminal with `RR_HOME` exported to that macOS home and `rr` aliased to the absolute path of `dev_out/bin/rr_macos_arm`. The shell should remain obviously separate from the user’s normal shell session. The safest way to do that is to generate a small temporary Zsh startup file inside `dev_out/` that first sources the user’s normal `~/.zshrc`, then exports `RR_HOME`, defines the `rr` alias, and prepends a short prompt marker such as `(rr-dev-macos) `. Launch Zsh with `ZDOTDIR` pointing at that temporary startup directory so the user keeps their normal shell customizations plus the dev-specific overrides.

For Linux, `scripts/dev/linux-shell.sh` should build or reuse the same `rr-dev-env` image, then run an interactive container from it. Mount the repository at `/workspace`, mount `dev_out/bin/rr_linux` read-only into the container, mount `dev_out/home/linux` to a stable path such as `/rr-home`, and mount the host config source read-only so the first shell launch can seed `config.json`. Inside the container, prepare `RR_HOME=/rr-home`, copy the seed config only if `/rr-home/config.json` is missing, define `rr` to point at the mounted Linux binary, and then exec into an interactive shell in the current terminal. Use Bash for the Linux shell because it is present in the planned Debian-based image and easy to launch with a custom rcfile. As with macOS, generate a short rcfile that marks the shell with a prompt prefix such as `(rr-dev-linux) `.

After the automation works, update `README.md` with a short “development manual testing” section. Explain the three new commands, the meaning of `dev_out/bin` and `dev_out/home`, the fact that `RR_HOME` is isolated from production state, and the recovery step for macOS Burrito caching: if a same-version rebuild appears stale, run `rr maintenance uninstall` inside the macOS dev shell and re-enter the shell.


## Concrete Steps

Run all commands from the repository root `/Users/zili/code/rr`.

Start by creating the `just` module and helper script layout, then add `Dockerfile.dev`, then wire the shell recipes. Use these commands during implementation:

    just --list-submodules --list

Observed result after milestone 1:

    Available recipes:
        list
        upgrade_rr
        dev:
            build
            linux
            macos

Build the dev binaries with:

    just dev build

Expected observable results:

    dev_out/bin/rr_macos_arm exists and is executable
    dev_out/bin/rr_linux exists and is executable

Enter the host macOS shell with:

    just dev macos

Once inside that shell, verify:

    echo $RR_HOME
    type rr
    rr --help

Expected observable results:

    $RR_HOME ends with /dev_out/home/macos
    type rr reports an alias pointing at dev_out/bin/rr_macos_arm
    rr --help prints the CLI help from the newly built binary

Enter the Linux shell with:

    just dev linux

Once inside that shell, verify:

    echo $RR_HOME
    type rr
    rr --help

Expected observable results:

    $RR_HOME is /rr-home or the chosen mounted Linux home path
    type rr reports an alias or executable path pointing at the mounted rr_linux binary
    rr --help prints the CLI help from the Linux binary

Run the repository test suite after the automation files are added:

    mix test

This change should not alter application code, so the existing suite should continue to pass unchanged.


## Validation and Acceptance

Acceptance is behavior-first.

The change is accepted when `just dev build` completes without manual extraction steps and leaves exactly the two expected binaries in `dev_out/bin/`. The build is demonstrably correct when `file dev_out/bin/rr_macos_arm` identifies a macOS executable and `file dev_out/bin/rr_linux` identifies a Linux executable.

The macOS shell is accepted when `just dev macos` opens an interactive shell in the current terminal, `RR_HOME` points at `dev_out/home/macos`, `rr` resolves to `dev_out/bin/rr_macos_arm`, and the first entry copies `~/.rr/config.json` into `dev_out/home/macos/config.json` only if that file was absent. Edit `dev_out/home/macos/config.json`, exit the shell, run `just dev macos` again, and confirm the file was not overwritten.

The Linux shell is accepted when `just dev linux` opens an interactive shell inside Docker, `RR_HOME` points at the mounted Linux test home, `rr` resolves to the mounted Linux binary, and the first entry copies the host config into `dev_out/home/linux/config.json` only if that file was absent. Edit `dev_out/home/linux/config.json`, exit, run `just dev linux` again, and confirm the file was not overwritten.

Finally, run one real command in each shell, such as `rr list` or `rr kf --help`, and confirm no files under `~/.rr` changed during the session. That is the proof that the workflow is both usable and isolated.


## Idempotence and Recovery

This plan is intended to be safe to repeat. `just dev build` can be run any number of times; it should overwrite the binaries in `dev_out/bin/` with the latest build. `just dev macos` and `just dev linux` should be safe to enter repeatedly; they only seed the config on first use and reuse the existing home directory thereafter.

If the developer wants a completely fresh manual-test environment, delete `dev_out/home/macos/` or `dev_out/home/linux/` and run the corresponding shell command again. The seed config will be copied again on the next launch.

If the macOS Burrito runtime appears stale after rebuilding the same version, run `rr maintenance uninstall` inside the macOS dev shell, exit, then re-enter with `just dev macos`. This clears Burrito’s extracted runtime cache so the local binary can unpack the new build.

If `just dev build` fails after partially writing binaries, it is safe to rerun it. The implementation should create `dev_out/bin/` up front and perform final copies atomically where practical, for example by copying to a temporary name then moving into place.


## Artifacts and Notes

Keep the helper scripts small and single-purpose. The important files at the end of implementation should be:

    justfile
    dev.just
    Dockerfile.dev
    scripts/dev/build.sh
    scripts/dev/macos-shell.sh
    scripts/dev/linux-shell.sh
    README.md

The shell bootstrapping scripts should print one short banner when they start so the developer can immediately see which environment they are in. For example:

    rr dev shell: macos
    binary: /Users/zili/code/rr/dev_out/bin/rr_macos_arm
    RR_HOME: /Users/zili/code/rr/dev_out/home/macos

and:

    rr dev shell: linux
    binary: /workspace/dev_out/bin/rr_linux
    RR_HOME: /rr-home

Milestone 1 verification transcript:

    $ just --list-submodules --list
    Available recipes:
        list
        upgrade_rr
        dev:
            build
            linux
            macos


## Interfaces and Dependencies

The public automation interface at the end of this plan is:

    just dev build
    just dev macos
    just dev linux

In the root `justfile`, define:

    mod dev

and place the submodule recipes in `dev.just`.

`Dockerfile.dev` must provide a Debian-based Linux environment with Elixir `1.18.3`, Erlang/OTP `27.3.4.6`, Zig `0.15.1`, Bash, Git, and the basic system packages needed to run `mix deps.get`, `mix compile`, and `mix release`.

The helper scripts must rely on `RR_HOME` rather than introducing any new application environment variable. The current application contract in `lib/rr/config/paths.ex` is sufficient and should remain unchanged.

The build script should copy artifacts from `burrito_out/rr_macos_arm` and `burrito_out/rr_linux`. If Burrito emits an extension unexpectedly, fail with a direct error message instead of guessing.

The shell scripts should fail fast with a clear instruction if the expected binary is missing. The message should tell the user to run `just dev build` first.


Plan update note: created on 2026-03-26 from the agreed manual-testing workflow. The initial version fixes the command surface, file layout, state location, and single-Dockerfile approach so implementation can proceed without additional design decisions.

Plan update note: revised on 2026-03-26 after milestone 1 implementation to record the shipped `just` submodule wiring, placeholder helper scripts, `.gitignore` change, and the observed `just --list-submodules --list` output.
