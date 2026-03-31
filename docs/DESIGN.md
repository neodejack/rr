# Design Notes

This directory holds repository design guidance for changes that need more than local code context.

Start with `docs/GUIDELINES.md` for the general workflow rules and `docs/ARCHITECTURE.md` for the code map. Then read the matching design note below when your change touches a guided area.

Read the matching document before writing code in one of these areas:

- Commands: if you add a new command or materially change anything under `lib/rr/cli/commands/`, read `docs/design/commands.md` first.
- Providers: if you add, remove, rename, or modify anything under `lib/rr/providers/`, read `docs/design/providers.md` first.

If no area-specific document exists yet, follow `AGENTS.md`, `docs/GUIDELINES.md`, and the surrounding code.
