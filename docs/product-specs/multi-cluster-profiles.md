# Multi-Cluster Profiles

## Summary

Add named auth profiles to `rr` so a user can store multiple Rancher credentials, including multiple accounts against the same Rancher environment, and choose which profile a command runs against with `-p` / `--profile`.

When no profile is specified, commands should follow command-specific behavior instead of assuming a single global auth. Alias creation should become interactive, but alias names must remain globally unique across all profiles so any alias always resolves to exactly one cluster in exactly one profile.

## Problem

`rr` currently assumes one Rancher auth for the entire CLI. That breaks down for users who:

- access multiple Rancher clusters or Rancher environments
- switch between multiple accounts against the same environment, such as read-only and full-access accounts
- need aliases that only make sense within a particular auth context

Without profile support, users must overwrite their only saved auth, cannot safely keep multiple contexts, and cannot reliably disambiguate cluster names that appear in more than one auth context.

## Goals

- Let a user save multiple named Rancher auth profiles in local `rr` state.
- Let a user target a specific profile with `-p` / `--profile` on supported commands.
- Make profile selection predictable when `-p` is omitted.
- Make alias creation interactive so users do not need to pass both alias text and full cluster name on the command line.
- Ensure every alias string is globally unique across all profiles so an alias always resolves to one cluster in one profile.
- Make ambiguous cross-profile cluster matches understandable and easy to resolve.

## Non-Goals

- Adding separate CRUD commands for profile management beyond `rr login`.
- Introducing a persistent "current profile" concept.
- Changing the behavior of commands that do not interact with Rancher auth, such as `rr yo`, help, or version output.
- Merging or deduplicating cluster records that happen to have the same name across profiles.

## Target Users

- Engineers who access more than one Rancher environment.
- Engineers who use multiple accounts for the same Rancher environment.
- Existing `rr` users who rely on aliases and cluster substring matching but want less error-prone alias creation.

## User Journey

A user runs `rr login` to manage auth profiles. If they pass `-p`, `rr` uses that profile name directly. If they do not pass `-p`, `rr` first asks whether they want to update an existing profile or create a new profile.

If the user chooses to update an existing profile, `rr` shows the existing profiles and asks the user to pick one. If the user chooses to create a new profile, `rr` prompts for a new profile name. After the profile is chosen or created, `rr` prompts for the Rancher hostname and token and stores that auth under the selected profile.

Later, the user can run `rr list`, `rr kf`, or `rr alias` with `-p profile_name` to operate inside a single auth profile. If they omit `-p`, the command follows its command-specific behavior. `rr list` shows clusters across all profiles with a profile column. `rr kf` searches across all profiles and asks the user to narrow the result when the search is ambiguous. `rr alias` prompts the user to choose a profile before creating or updating an alias when `-p` is omitted.

For alias creation, the user runs `rr alias -p profile_name` or `rr alias`. After the profile is fixed, `rr` prompts for the alias text, then shows the clusters available in that profile and requires the user to choose one full cluster name interactively. If the alias already exists in that same profile, `rr` shows the current mapping and asks for overwrite confirmation before saving the new target. If the alias text already exists anywhere under a different profile, `rr` must reject the operation and explain that aliases are unique across profiles.

## Functional Requirements

1. `rr` must support storing multiple named auth profiles in local config instead of a single global auth record.
2. A profile must represent one complete Rancher auth set, including the Rancher hostname and token.
3. Multiple profiles may point to the same Rancher environment or to different Rancher environments.
4. Supported commands must accept `-p` and `--profile` to target a named profile.
5. If a user passes `-p` with a profile name that does not exist, the command must exit immediately with an error and must not continue to prompts, network calls, alias resolution, cluster listing, or kubeconfig generation.
6. `rr login` must be the only in-scope entry point for creating or updating profiles.
7. `rr login -p <profile>` must use that profile name directly and proceed to credential entry for that profile.
8. `rr login` without `-p` must first ask: update existing profile or create new profile.
9. If the user chooses update existing profile, `rr login` must show existing profiles and require the user to select one before credential entry.
10. If the user chooses create new profile, `rr login` must prompt for the new profile name before credential entry.
11. If no profiles exist yet, `rr login` must still support the create-new flow cleanly.
12. `rr list -p <profile>` must list only the clusters reachable through that profile.
13. `rr list` without `-p` must list clusters from all saved profiles in one view and include an extra column that shows which profile each cluster belongs to.
14. `rr kf -p <profile> <cluster_name_substring>` must search only inside the specified profile.
15. `rr kf` without `-p` must search across clusters from all saved profiles.
16. If `rr kf` without `-p` finds exactly one matching cluster across all profiles, it must proceed with that cluster.
17. If `rr kf` without `-p` finds multiple matches across profiles, the error must show which cluster names matched under which profiles and must instruct the user to tighten the cluster name, use `-p` to narrow the profile, or use `rr alias`.
18. When the same full cluster name appears in more than one profile, the guidance must remain concise and include the message `please use -p auth_name to specify the cluster`.
19. Alias records must store both the owning profile and the target full cluster name so alias resolution also narrows the auth context.
20. `rr alias` creation and update flows must no longer require positional `<cluster_alias> <cluster_full_name>` arguments.
21. `rr alias -p <profile>` must start an interactive alias flow inside the specified profile.
22. `rr alias` without `-p` must prompt the user to choose a profile before continuing.
23. After the profile is selected, `rr alias` must prompt for the alias text before asking the user to choose a target cluster.
24. After alias text entry, `rr alias` must show the clusters available in the selected profile and require the user to choose one full cluster name interactively.
25. Alias text must be unique across all profiles. One alias string may map to only one full cluster name in one profile.
26. When creating or updating an alias, `rr` must check for an existing alias with the same text in every profile before saving.
27. If the same alias text already exists under a different profile, `rr alias` must fail the save and show an error that the alias is already claimed by another profile.
28. If the same alias text already exists in the selected profile, `rr alias` may update it only after explicit overwrite confirmation from the user.
29. If the user declines overwrite confirmation, `rr alias` must leave the existing alias unchanged.
30. When `rr kf` receives an alias, alias resolution must also narrow the profile scope so the alias lookup does not search unrelated profiles.
31. `rr alias --list` must show aliases grouped by profile.
32. The product terminology in user-facing flows should consistently use "profile" for the named auth selection concept.

## Edge Cases and Failure Handling

- If a user runs a profile-aware command with `-p` pointing to a missing profile, the command must fail immediately before doing any other work.
- If `rr login` is run without `-p` and there are no existing profiles, the update-existing branch should not strand the user; the flow should still make it clear how to create a new profile.
- If `rr list` is run without `-p` and no profiles are configured, the command should return a clear no-profiles or no-clusters state rather than acting like a single default auth exists.
- If `rr kf` without `-p` finds no matches across all profiles, the error should make clear that no matching cluster was found in any profile.
- If `rr kf` without `-p` finds multiple matches with the same cluster name under different profiles, the ambiguity message must identify both the cluster name and the owning profile for each match.
- If a user enters an alias that is already used by another profile, `rr alias` must reject the save before changing any local config.
- If a user enters an alias that already exists in the selected profile, `rr alias` should show the current mapping and ask for confirmation before overwriting it.
- If a profile-scoped alias points to a cluster name that also exists in another profile, `rr kf` should still stay inside the alias's profile scope instead of becoming ambiguous again.
- If the selected profile has no clusters available when `rr alias` starts, the command should fail with a clear message instead of prompting for an unusable cluster selection.

## Acceptance Criteria

- A user can save two or more named Rancher auth profiles and keep them side by side in local `rr` state.
- A user can update an existing profile or create a new one through `rr login`.
- `rr list -p profile_a` only shows clusters from `profile_a`.
- `rr list` without `-p` shows clusters from multiple profiles and includes a profile column for each row.
- `rr kf -p profile_a cluster-x` only searches within `profile_a`.
- `rr kf cluster-x` without `-p` searches across all profiles and succeeds only when exactly one cluster match exists overall.
- When `rr kf` without `-p` is ambiguous, the error output identifies the matching cluster and profile combinations and tells the user to narrow the cluster name, use `-p`, or use `rr alias`.
- A user can run `rr alias -p profile_a` or `rr alias` and complete alias creation entirely through prompts instead of passing positional alias arguments.
- During alias creation, the user enters the alias text first and then selects the target cluster from the chosen profile.
- If alias `prod` already exists under `profile_b`, attempting to create or move alias `prod` under `profile_a` fails with a clear uniqueness error and does not change config.
- If alias `prod` already exists under `profile_a`, `rr alias` asks for overwrite confirmation before changing its target cluster.
- `rr kf prod` uses the alias's profile scope and does not search across unrelated profiles.
- `rr alias --list` displays aliases grouped by profile.
- Passing `-p does-not-exist` to a profile-aware command fails immediately and performs no further action.

## Success Signals

- Users no longer need to overwrite their only saved Rancher auth to switch contexts.
- Users can move between profiles with explicit command targeting instead of editing config by hand.
- Ambiguous cluster-name failures become actionable because they show both the profile and cluster context.
- Alias creation becomes safer because the CLI guides the user through profile selection and cluster selection interactively.
- Alias resolution stays deterministic because one alias string can only exist once across all profiles.

## Constraints

- The feature must fit the current CLI command set and keep profile management limited to `rr login`.
- The design should preserve simple CLI usage for single-profile users while making multi-profile behavior explicit.
- User-facing behavior should not rely on a hidden or sticky default profile.
- The spec assumes aliases and profile data are stored in local `rr` config under `RR_HOME` or the default home directory.
- The spec may assume there are no released-user configs that already violate the cross-profile alias uniqueness rule.

## Open Questions

- Exact prompt wording and visual formatting for interactive profile selection and interactive alias creation are not defined here.
- Exact error-string wording is intentionally flexible except for the required concise guidance line `please use -p auth_name to specify the cluster`.
