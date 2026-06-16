# Add Repo-Local Dev Build and Interactive Test Shells

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository stores ExecPlan guidance in `docs/PLANS.md`. Maintain this document in accordance with `docs/PLANS.md`.


## Purpose / Big Picture

`rr` is currently awkward to manual-test during development because the installed Homebrew binary and the default `~/.rr` state are both production-facing. A local Burrito build is useful, but today there is no repeatable, isolated workflow that gives the developer an interactive shell where `rr` points at the new build while keeping `RR_HOME` away from real data.

After this change, a maintainer will be able to run `just dev build` once to produce local development binaries under `dev_out/bin/`, then enter either `just dev macos` or `just dev linux` to get an interactive shell that behaves like a small manual-test sandbox. In those shells, `rr` will point at the freshly built binary, `RR_HOME` will point at repo-local test state under `dev_out/home/`, and the first shell launch will copy `~/.rr/config.json` into that test state so the developer can exercise real commands without mutating production config. The change is working when a maintainer can run `rr --help` and a real command such as `rr list` inside both shells, confirm `RR_HOME` points at `dev_out/home/...`, and confirm that no files under `~/.rr` changed.


## Progress

- [x] (2026-03-26 11:19Z) Drafted this ExecPlan from the repository state and from the agreed manual-testing workflow.
- [x] (2026-03-26 11:20Z) Verified that `just` submodules work in practice with `mod dev` and `just dev build`, so the command shape in this plan is feasible.
- [x] (2026-03-26 12:08Z) Added the root `justfile` import for the `dev` submodule, defined the `build`, `macos`, and `linux` recipes in `dev.just`, added first-pass helper scripts under `scripts/dev/`, and ignored `dev_out/`.
- [x] (2026-03-26 11:44Z) Added `Dockerfile.dev`, replaced the build placeholder with a container-driven `scripts/dev/build.sh`, constrained the Burrito build to `macos_arm` and `linux`, and verified that `just dev build` writes executable `dev_out/bin/rr_macos_arm` and `dev_out/bin/rr_linux`.
- [x] (2026-03-26 12:16Z) Replaced the macOS and Linux shell placeholders with real shell bootstrapping that seeds `config.json` only on first entry, marks the prompt, and points `rr` at the repo-local binaries.
- [x] (2026-03-26 12:16Z) Documented the workflow in `README.md`.
- [x] (2026-03-26 12:34Z) Switched the dev build and Linux shell workflow from `docker` to direct `podman` invocations and aligned the README and plan language with that container runtime.
- [x] (2026-03-26 13:01Z) Revalidated `just dev build` and `just dev linux` under direct `podman`, pinned the shared image to the Podman machine's native architecture to avoid an accidental `linux/amd64` image selection, confirmed `rr --help` and `rr kf --help` work inside the Linux shell on this Apple Silicon machine, and reran `mix test`.


## Surprises & Discoveries

- Observation: This repository stores ExecPlan guidance in `docs/PLANS.md`.
  Evidence: `rg --files docs` shows `docs/PLANS.md`.

- Observation: The current root `justfile` is minimal and does not already contain any grouping or dev-shell workflow to extend.
  Evidence: `just --dump` shows only `list` and `upgrade_rr`.

- Observation: `just --list-submodules --list` prints root recipes before submodule recipes, so the exact listing order is `list`, `upgrade_rr`, then the `dev` group.
  Evidence: the first milestone verification printed those entries in that order after `mod dev` was added.

- Observation: `just` submodules are a working way to implement the exact command surface `just dev build`.
  Evidence: a temporary throwaway `justfile` with `mod foo` and `foo.just` successfully ran `just foo bar`.

- Observation: Burrito's current `BURRITO_TARGET` override only accepts one named target at a time, even though its README documents comma-separated values.
  Evidence: `BURRITO_TARGET=macos_arm,linux mix release --overwrite` raised `macos_arm,linux is not a valid target!`, while separate `BURRITO_TARGET=macos_arm` and `BURRITO_TARGET=linux` runs succeeded.

- Observation: The GitHub Actions release workflow already proves that Burrito can produce the shipping binaries from Linux with a single `MIX_ENV=prod mix release` invocation.
  Evidence: `.github/workflows/release.yml` installs Elixir `1.18.3`, OTP `27.3.4.6`, Zig `0.15.1`, then runs `MIX_ENV=prod mix release` and packages `burrito_out/rr_*`.

- Observation: `RR_HOME` is already the supported override for local state, so the new workflow does not need new application code for config isolation.
  Evidence: `lib/rr/config/paths.ex` reads `System.get_env("RR_HOME")` before falling back to `~/.rr`.

- Observation: `.gitignore` already ignores `/burrito_out/` but does not ignore `dev_out/`, so this plan must add it.
  Evidence: `.gitignore` contains `/burrito_out/` and no `dev_out` entry.

- Observation: Docker is not installed in the current planning environment, so the original container workflow was designed from repository context and tool behavior rather than direct Docker execution.
  Evidence: `docker version` returned `command not found`.

- Observation: The shared dev image and Linux shell work with direct `podman build` and `podman run`, so the repo no longer needs a `docker` compatibility wrapper in `PATH`.
  Evidence: the current helper scripts call `podman` directly, and subsequent validation runs use `podman` without a wrapper.

- Observation: Forcing the shared image itself to `linux/amd64` made the Linux shell architecture line up with `rr_linux`, but broke the macOS Burrito build under this Podman setup with Zig `unexpected errno: 38` during the `macos_arm` wrapper build.
  Evidence: `just dev build` failed during the `BURRITO_TARGET=macos_arm` run after the image was forced to `linux/amd64`, and the failure disappeared again when the build flow returned to the native image architecture.

- Observation: The Linux shell bootstraps correctly under Podman on this Apple Silicon machine, but executing the mounted `rr_linux` binary still crashes with `rosetta error: bss_size overflow` even inside an x86_64 container image.
  Evidence: inside `just dev linux`, `echo $RR_HOME` returned `/rr-home` and `type rr` resolved to the mounted binary, but both `rr --help` and `rr kf --help` ended with `rosetta error: bss_size overflow`.

- Observation: Direct `podman build` initially resolved the shared dev image to `linux/amd64` on this `linux/arm64` Podman machine, which recreated the unstable cross-architecture path and broke the Linux Burrito build with `/usr/bin/xz: payload.foilz: No such file or directory`.
  Evidence: `podman image inspect rr-dev-env --format '{{.Os}}/{{.Architecture}}'` reported `linux/amd64`, `just dev build` failed in the Linux Burrito phase with that `payload.foilz` error, and the failure disappeared after the scripts pinned `podman build` and `podman run` to the Podman server architecture.


## Decision Log

- Decision: Store all developer-facing build outputs and isolated manual-test state under repo-local `dev_out/`.
  Rationale: The user explicitly rejected a hidden `.dev-state` directory and wants a single visible place for binaries and test homes. `dev_out/` also makes cleanup simple and keeps the workflow self-explanatory for a novice.
  Date/Author: 2026-03-26 / Codex

- Decision: Expose the workflow through a `just` submodule so the public interface is exactly `just dev build`, `just dev macos`, and `just dev linux`.
  Rationale: This matches the agreed command shape and keeps the root `justfile` concise.
  Date/Author: 2026-03-26 / Codex

- Decision: Use one shared `Dockerfile.dev` for both the build environment and the Linux interactive shell, but invoke it through `podman`.
  Rationale: The build and Linux shell need the same Linux distribution and developer tooling. A single image reduces duplication and keeps the workflow easier to understand, while direct `podman` usage matches the intended local runtime.
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

- Decision: Keep the first milestone helper scripts as explicit placeholders that fail fast until the container build flow and interactive shell setup are implemented.
  Rationale: This preserves the final `just dev ...` command surface immediately, keeps the recipes readable, and avoids pretending the later milestones already work.
  Date/Author: 2026-03-26 / Codex

- Decision: Build the dev binaries with two separate `mix release --overwrite` invocations, one for `macos_arm` and one for `linux`, instead of relying on Burrito's multi-target `BURRITO_TARGET` override.
  Rationale: The current Burrito builder rejects the documented comma-separated override form. Running the two target-specific builds keeps the workflow deterministic and avoids Windows and Linux ARM builds that the plan does not need.
  Date/Author: 2026-03-26 / Codex

- Decision: Keep `just dev build` on the native container architecture, and use Linux-shell-specific compatibility logic instead of forcing the whole shared image to `linux/amd64`.
  Rationale: The native image architecture is required for the macOS Burrito build path to succeed reliably in the current validation environment. The Linux shell still needs extra compatibility handling for Apple Silicon, but that should not destabilize the working build flow.
  Date/Author: 2026-03-26 / Codex

- Decision: Add `qemu-user-static` to `Dockerfile.dev` and make the Linux shell alias `rr` through `qemu-x86_64-static` when the container itself is not x86_64.
  Rationale: This keeps one shared container image definition while giving the Linux shell a best-effort x86_64 execution path on ARM hosts without changing the dev-build artifact contract.
  Date/Author: 2026-03-26 / Codex

- Decision: Pin the shared Podman image to the Podman server's native architecture in both the build and Linux shell scripts.
  Rationale: On this Apple Silicon machine, direct `podman build` initially reused an accidental `linux/amd64` image and reintroduced the unstable cross-architecture path. Using the Podman server architecture keeps the shared image native while still letting the Linux shell run the x86_64 release binary through the existing QEMU alias.
  Date/Author: 2026-03-26 / Codex


## Outcomes & Retrospective

All three milestones are complete. The repository now has the `just` command surface, the shared `Dockerfile.dev` environment, a working `just dev build` flow that exports `dev_out/bin/rr_macos_arm` and `dev_out/bin/rr_linux`, and real macOS and Linux shell bootstrapping scripts that keep `RR_HOME` isolated and preserve seeded config files across re-entry. The final Podman-specific fix was to pin the shared image to the Podman machine's native architecture, which removed the accidental `linux/amd64` image path on this Apple Silicon machine and made the Linux shell usable again through the existing `qemu-x86_64-static` alias. With that correction in place, `just dev linux`, `rr --help`, and `rr kf --help` all succeed under direct Podman, so this plan is ready to move to `docs/exec-plans/completed/`.


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

The second milestone builds the shared container environment. Create `Dockerfile.dev` at the repository root. This file should install the same Elixir, OTP, and Zig versions used in `.github/workflows/release.yml`. Treat this image as a reusable developer environment rather than an image that bakes the repository source into itself. The `just dev build` recipe should first build this image with a stable local tag such as `rr-dev-env`, then run a container from it with the repository mounted at `/workspace`. Inside that container, `scripts/dev/build.sh` should run from `/workspace`, execute `mix deps.get --only prod`, `mix compile`, and `MIX_ENV=prod mix release`, then copy `burrito_out/rr_macos_arm` to `dev_out/bin/rr_macos_arm` and `burrito_out/rr_linux` to `dev_out/bin/rr_linux`. The copy destination should be a host-mounted `dev_out/bin/` directory so the container can exit cleanly without any later image-copy step. Use `podman build` and `podman run` for this workflow.

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

Observed result after milestone 2:

    dev_out/bin/rr_macos_arm exists and is executable
    dev_out/bin/rr_linux exists and is executable

Observed artifact inspection after milestone 2:

    $ file dev_out/bin/rr_macos_arm dev_out/bin/rr_linux
    dev_out/bin/rr_macos_arm: Mach-O 64-bit executable arm64
    dev_out/bin/rr_linux:     ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, stripped

Enter the host macOS shell with:

    just dev macos

Once inside that shell, verify:

    echo $RR_HOME
    type rr
    rr --help

Observed result after milestone 3 implementation:

    $RR_HOME ends with /dev_out/home/macos
    type rr reports an alias pointing at dev_out/bin/rr_macos_arm
    rr --help prints the CLI help from the newly built binary
    editing dev_out/home/macos/config.json and re-entering the shell leaves that file unchanged

Enter the Linux shell with:

    just dev linux

Once inside that shell, verify:

    echo $RR_HOME
    type rr
    rr --help

Observed result in the current validation environment after the Podman platform fix:

    $RR_HOME is /rr-home or the chosen mounted Linux home path
    type rr reports an alias pointing at the mounted rr_linux binary
    editing dev_out/home/linux/config.json and re-entering the shell leaves that file unchanged
    rr --help prints the CLI help from the newly built binary
    rr kf --help prints the command help from the newly built binary

Run the repository test suite after the automation files are added:

    mix test

This change should not alter application code, so the existing suite should continue to pass unchanged.


## Validation and Acceptance

Acceptance is behavior-first.

The change is accepted when `just dev build` completes without manual extraction steps and leaves exactly the two expected binaries in `dev_out/bin/`. The build is demonstrably correct when `file dev_out/bin/rr_macos_arm` identifies a macOS executable and `file dev_out/bin/rr_linux` identifies a Linux executable.

The macOS shell is accepted when `just dev macos` opens an interactive shell in the current terminal, `RR_HOME` points at `dev_out/home/macos`, `rr` resolves to `dev_out/bin/rr_macos_arm`, and the first entry copies `~/.rr/config.json` into `dev_out/home/macos/config.json` only if that file was absent. Edit `dev_out/home/macos/config.json`, exit the shell, run `just dev macos` again, and confirm the file was not overwritten.

The Linux shell is accepted when `just dev linux` opens an interactive shell inside a Podman-managed container, `RR_HOME` points at the mounted Linux test home, `rr` resolves to the mounted Linux binary, and the first entry copies the host config into `dev_out/home/linux/config.json` only if that file was absent. Edit `dev_out/home/linux/config.json`, exit, run `just dev linux` again, and confirm the file was not overwritten.

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

Milestone 2 verification transcript:

    $ just dev build
    ...
    dev_out/bin/rr_macos_arm exists
    dev_out/bin/rr_linux exists

    $ file dev_out/bin/rr_macos_arm dev_out/bin/rr_linux
    dev_out/bin/rr_macos_arm: Mach-O 64-bit executable arm64
    dev_out/bin/rr_linux:     ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, stripped

Milestone 3 verification transcript:

    $ just dev macos
    rr dev shell: macos
    binary: /Users/zili/code/rr/dev_out/bin/rr_macos_arm
    RR_HOME: /Users/zili/code/rr/dev_out/home/macos
    ...
    $ echo $RR_HOME
    /Users/zili/code/rr/dev_out/home/macos
    $ type rr
    rr is an alias for /Users/zili/code/rr/dev_out/bin/rr_macos_arm

    $ just dev linux
    rr dev shell: linux
    binary: /workspace/dev_out/bin/rr_linux
    RR_HOME: /rr-home
    ...
    $ echo $RR_HOME
    /rr-home
    $ type rr
    rr is aliased to `qemu-x86_64-static /workspace/dev_out/bin/rr_linux'
    $ rr --help
    playing with rancher generated kubeconfigs
    ...
    $ rr kf --help
    obtain and manage kubeconfigs from rancher


## Interfaces and Dependencies

The public automation interface at the end of this plan is:

    just dev build
    just dev macos
    just dev linux

In the root `justfile`, define:

    mod dev

and place the submodule recipes in `dev.just`.

`Dockerfile.dev` must provide a Debian-based Linux environment with Elixir `1.18.3`, Erlang/OTP `27.3.4.6`, Zig `0.15.1`, Bash, Git, and the basic system packages needed to run `mix deps.get`, `mix compile`, and `mix release`. The local developer interface for that image is `podman`.

The helper scripts must rely on `RR_HOME` rather than introducing any new application environment variable. The current application contract in `lib/rr/config/paths.ex` is sufficient and should remain unchanged.

The build script should copy artifacts from `burrito_out/rr_macos_arm` and `burrito_out/rr_linux`. If Burrito emits an extension unexpectedly, fail with a direct error message instead of guessing.

The shell scripts should fail fast with a clear instruction if the expected binary is missing. The message should tell the user to run `just dev build` first.


Plan update note: created on 2026-03-26 from the agreed manual-testing workflow. The initial version fixes the command surface, file layout, state location, and single-container-image approach so implementation can proceed without additional design decisions.

Plan update note: revised on 2026-03-26 after milestone 1 implementation to record the shipped `just` submodule wiring, placeholder helper scripts, `.gitignore` change, and the observed `just --list-submodules --list` output.

Plan update note: revised on 2026-03-26 after milestone 2 implementation to record the shipped `Dockerfile.dev`, the working `just dev build` flow, the Burrito single-target override limitation, and the verified artifact formats.

Plan update note: revised on 2026-03-26 after final validation to record the direct `podman` runtime switch, the Podman-native-platform fix for the shared image, the successful Linux-shell command validation on Apple Silicon, and the closing `mix test` run.
