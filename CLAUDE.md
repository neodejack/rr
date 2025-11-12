# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RR is a CLI tool for managing Rancher-generated Kubernetes kubeconfigs. Built in Elixir, it's compiled to standalone binaries using Burrito for cross-platform distribution (macOS, Linux, Windows).

## Core Architecture

### Command Routing
- Entry point: `lib/rr.ex` - parses command-line arguments and routes to command modules
- Two main commands:
  - `login`: Manages Rancher authentication (stores hostname and bearer token)
  - `kf`: Fetches, caches, and manages kubeconfigs from Rancher API

### Configuration System
- `lib/config.ex`: JSON-based config store at `~/.rr/config.json` (overridable via `RR_HOME` env var)
- `lib/config/auth.ex`: Handles Rancher authentication (hostname + bearer token), validates auth by calling Rancher API `/v3/clusters` endpoint
- Kubeconfigs are cached locally at `~/.rr/kubeconfigs/<cluster_name>`

### KubeConfig Management Logic
`lib/cmds/kf.ex` implements complex state-based execution:
- Checks local kubeconfig validity by running `kubectl get pods`
- Four execution modes based on flags:
  - `--new`: Force download fresh kubeconfig (overwrite existing)
  - `--sh`: Output shell command `export KUBECONFIG=...` instead of just the path
  - Combination of validity check + flags determines whether to download or use cached config
- Cluster selection: Substring matching on cluster names (must match exactly one cluster)

### HTTP Communication
- Uses `Req` library for Rancher API calls
- Base URL constructed from stored auth config
- Key endpoints:
  - `GET /v3/clusters` - List all clusters
  - `POST /v3/clusters/:id?action=generateKubeconfig` - Generate kubeconfig

### User Interface
- `lib/rr/shell.ex`: Handles stdout/stderr output with ANSI colors
- Uses `Owl` library for interactive prompts (login credentials, confirmations)
- Error handling: Most errors call `Shell.raise/1` which prints to stderr and exits with status 1

## Development Commands

### Build & Compile
```bash
# Install dependencies
mix deps.get

# Compile project
mix compile

# Run in development mode (not typical for CLI tools)
iex -S mix
```

### Testing
```bash
# Run all tests
mix test

# Run specific test file
mix test test/login_test.exs
```

### Release & Distribution
```bash
# Build release with Burrito (creates cross-platform binaries)
MIX_ENV=prod mix release

# Binaries will be in burrito_out/ directory:
# - rr_macos, rr_macos_arm
# - rr_linux, rr_linux_arm
# - rr_windows
```

### Code Formatting
```bash
# Check formatting
mix format --check-formatted

# Apply formatting
mix format
```

## Key Dependencies
- **Burrito**: Compiles Elixir app to standalone binaries (uses Zig internally)
- **Owl**: Interactive CLI prompts and UI components
- **Req**: Modern HTTP client for Rancher API communication
- **Breeze**: Custom fork for keyboard input handling

## Environment Variables
- `RR_HOME`: Override default config directory (`~/.rr`)

## Release Process
- GitHub Actions workflow (`.github/workflows/release.yml`) triggers on version tags `v*.*.*`
- Builds binaries for all platforms, packages as `.tar.gz`, publishes to GitHub Releases
- Requires Erlang 27.3, Elixir 1.18.3, and Zig 0.15.1

## Implementation Notes
- When modifying `RR.KubeConfig.execute/4`: Be aware this function has 6 clauses covering all combinations of (existing_kf_valid?, overwrite_existing_kf, generate_sh_template?). See backlog.md §1 for planned refactoring.
- Template rendering: Uses EEx templates from `priv/templates/` (currently only `sh.eex` for shell export command)
- Config file is plain JSON, uses `Jason` for encoding/decoding
