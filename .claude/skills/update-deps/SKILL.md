---
name: update-deps
description: Audit and update all project dependencies (npm, Elm, Rust/Cargo, Nix flake).
argument-hint: "[npm|elm|elm-pages|rust|nix] [minor|major]"
disable-model-invocation: true
allowed-tools:
  - Bash(pnpm audit *)
  - Bash(pnpm outdated *)
  - Bash(pnpm update *)
  - Bash(pnpm install *)
  - Bash(pnpm add *)
  - Bash(elm-json *)
  - Bash(cargo update *)
  - Bash(cargo search *)
  - Bash(nix flake update *)
  - Bash(nix run *)
  - Bash(git diff *)
  - Bash(git status *)
  - Bash(git add *)
  - Bash(git commit *)
  - Bash(which *)
  - Bash(cat node_modules/*)
  - Bash(pnpm view *)
  - Bash(cargo run --manifest-path .claude/skills/update-deps/scripts/Cargo.toml -- **)
  - Bash(*| cargo run --manifest-path .claude/skills/update-deps/scripts/Cargo.toml -- **)
  - Read
  - Edit
  - Write
  - Grep
  - Glob
---

# Update Dependencies

Audit and update project dependencies across all ecosystems in this monorepo.

## Ecosystem references

Each ecosystem's audit, update, and verify procedures are documented in `references/`.

| Ecosystem | minor | major |
|---|---|---|
| npm | `references/npm-minor.md` | `references/npm-major.md` |
| Rust | `references/rust-minor.md` | `references/rust-major.md` |
| Nix | `references/nix-minor.md` | `references/nix-major.md` |
| Elm | `references/elm.md` | — |
| elm-pages | `references/elm-pages.md` | — |

Read the relevant reference file(s) before executing each phase.

## Instructions

### Phase 0: Pre-flight

Run `git status --short`. If there are uncommitted changes, warn the user and suggest committing or stashing first.

Parse `$ARGUMENTS`:
- **No arguments**: Process all ecosystems except elm-pages. Only minor scope (major requires explicit specification).
- **Ecosystem only** (e.g., `npm`): Process that ecosystem. For npm/rust/nix, audit both minor and major, then ask the user which to apply.
- **Ecosystem + scope** (e.g., `npm minor` or `rust major`): Process only that specific scope. Read only the corresponding reference file.
- `elm` and `elm-pages` ignore the minor/major qualifier (they have a single reference file each).

### Phase 1: Audit

For each target ecosystem:
- **Scope specified** (`minor` or `major`): Read only the corresponding reference file and run its Audit steps.
- **Ecosystem only** (no scope, npm/rust/nix): Read both minor and major reference files and run both Audit steps.
- **No arguments**: Read only the minor reference files and run their Audit steps.
- **Elm / elm-pages**: Read the single reference file and run its Audit steps.

If multiple reference files share the same audit command (e.g., `npm outdated`), run it once and interpret the output from both perspectives.

Do NOT make any changes yet. Present the results as a consolidated report.

### Phase 2: Update

- **Scope specified**: Ask confirmation, then run the Update steps from the corresponding reference file.
- **Ecosystem only** (no scope): Based on the audit results, ask the user whether to apply minor updates or major updates. Only one can be chosen per run.
- **No arguments**: Ask which ecosystems to update. Accept: `all`, comma-separated list, or `skip`. Run the minor Update steps from each confirmed ecosystem's reference file.

### Phase 3: Verify

Collect **Verify** commands from each updated ecosystem's reference file and deduplicate before running. Reference table:

| Command | npm | Elm | elm-pages | Rust | Nix |
|---|:---:|:---:|:---:|:---:|:---:|
| `nix run .#test` | x | x | x | | x |
| `nix run .#build` | x | x | x | | x |
| `nix run .#cli-test` | | | | x | x |

Show `git diff --stat` so the user can see what changed.

### Phase 4: Commit (optional)

Ask the user if they want to commit. If yes, follow the repository's commit message conventions (check `git log --oneline`).

## General notes

- **Network errors**: If any audit command fails, report the error and continue with the remaining ecosystems.
- **No python3**: `python3` is not available in this Nix environment.
