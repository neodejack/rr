# Providers

## What providers are

Providers are the boundary layer between the core CLI logic and side effects. They hide storage, terminal I/O, network calls, and similar integrations behind small behavior modules.

In this repository, provider entry modules live in `lib/rr/providers/*.ex`. Examples:

- `RR.Providers.Terminal` wraps terminal I/O.
- `RR.Providers.Rancher` wraps Rancher API calls.
- `RR.Providers.SettingsStore` wraps settings persistence.
- `RR.Providers.AuthCache` wraps auth validity caching.

Code outside the provider layer should call the provider module, not a concrete backend module.

## How providers are used

Each provider entry module defines:

- A behaviour with callbacks for the operations the rest of the app needs.
- Public functions that dispatch to a concrete backend module.

This dispatch follows the existing convention:

- The entry module builds the backend module name with `Module.concat([__MODULE__, suffix])`.
- The `suffix` comes from `Application.get_env(:rr, :external_bound, default_suffix)`.
- In `config/dev.exs` and `config/prod.exs`, `:external_bound` is set to `Impl`.
- In `config/test.exs`, `:external_bound` is set to `Mock`.

That means a provider must expose backend modules whose names match the configured suffixes that can be selected at runtime.

## Conventions for writing provider code

When adding or changing a provider, follow these rules.

### 1. Keep the provider entry module small

The top-level provider module in `lib/rr/providers/<name>.ex` should only contain:

- The behaviour definition.
- Thin public functions that delegate to `impl()`.
- A private `impl/0` that resolves the backend module.

Do not put real file, network, ETS, or terminal logic in the entry module.

### 2. Put concrete logic in backend modules

Production code belongs in a concrete backend module under `lib/rr/providers/<name>/impl.ex`.

Examples:

- `lib/rr/providers/rancher/impl.ex`
- `lib/rr/providers/terminal/impl.ex`
- `lib/rr/providers/settings_store/impl.ex`
- `lib/rr/providers/auth_cache/impl.ex`

### 3. Match the runtime suffix convention

Because `dev` and `prod` set `:external_bound` to `Impl`, a provider used in normal runtime must expose `<Provider>.Impl`.

Examples:

- `RR.Providers.Rancher.Impl`
- `RR.Providers.Terminal.Impl`
- `RR.Providers.SettingsStore.Impl`
- `RR.Providers.AuthCache.Impl`

If you also want a descriptive backend name such as `File` or `ETS`, keep it as a thin compatibility wrapper that delegates to `Impl`. Do not rely on a descriptive module name alone when the provider is selected through the shared `:external_bound` setting.

### 4. Keep mocks aligned with the same contract

Tests switch provider dispatch to `Mock`, so the provider must also have a test backend that satisfies the same behaviour.

Typical patterns in this repository:

- Mox-generated modules such as `RR.Providers.Rancher.Mock`.
- Hand-written mocks such as `RR.Providers.Terminal.Mock`.

The important point is that the provider entry module, production backend, and mock backend all satisfy the same callbacks.

### 5. Keep provider contracts narrow

Provider callbacks should expose the smallest interface the rest of the app needs. Avoid leaking backend-specific details into callers. If the rest of the app only needs `read/0` and `write/1`, do not expose extra file-specific helpers through the provider contract.

### 6. Keep naming and file layout predictable

Use a predictable file layout so agents and humans can find the implementation quickly:

- Entry module: `lib/rr/providers/<name>.ex`
- Production backend: `lib/rr/providers/<name>/impl.ex`, which defines `<Provider>.Impl`
- Optional compatibility backend: a descriptive module such as `<Provider>.File` or `<Provider>.ETS`
- Test mock: `<Provider>.Mock`

## Checklist for a new provider

When adding a new provider:

1. Define the behaviour and public delegators in `lib/rr/providers/<name>.ex`.
2. Add `lib/rr/providers/<name>/impl.ex` and define the production backend module `<Provider>.Impl` there.
3. Add or update the test mock backend named `<Provider>.Mock`.
4. Keep any legacy or descriptive backend names as wrappers only.
5. Update tests to exercise the provider through the entry module, not by calling the backend directly.

## Rule of thumb

If code outside `lib/rr/providers/` needs to know whether a provider is backed by HTTP, ETS, files, or a mock, the provider boundary is too leaky.
