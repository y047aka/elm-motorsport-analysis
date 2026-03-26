---
name: update-deps
description: Audit and update all project dependencies (npm, Elm, Rust/Cargo, Nix flake).
argument-hint: "[npm|elm|elm-pages|rust|nix]"
disable-model-invocation: true
allowed-tools:
  - Bash(npm outdated *)
  - Bash(npm update *)
  - Bash(npm install *)
  - Bash(elm-json *)
  - Bash(cargo update *)
  - Bash(nix flake update *)
  - Bash(nix run *)
  - Bash(git diff *)
  - Bash(git status *)
  - Bash(git add *)
  - Bash(git commit *)
  - Bash(which *)
  - Bash(cat flake.lock *)
  - Bash(cat node_modules/*)
  - Bash(npm view *)
  - Bash(node -e *)
  - Bash(find ~/.elm *)
  - Read
  - Edit
  - Write
  - Grep
  - Glob
---

# Update Dependencies

Audit and update project dependencies across all ecosystems in this monorepo.

## Ecosystem references

Each ecosystem's audit, update, and verify procedures are documented in:

- npm: `references/npm.md`
- Elm: `references/elm.md`
- elm-pages: `references/elm-pages.md`
- Rust: `references/rust.md`
- Nix: `references/nix.md`

Read the relevant reference file(s) before executing each phase.

## Instructions

### Phase 0: Pre-flight

Run `git status --short`. If there are uncommitted changes, warn the user and suggest committing or stashing first.

If `$ARGUMENTS` specifies an ecosystem (`npm`, `elm`, `elm-pages`, `rust`, or `nix`), only process that one. Otherwise, process all except `elm-pages` (elm-pages is only processed when explicitly specified).

### Phase 1: Audit

Run **Audit** steps from each target ecosystem's reference file. Do NOT make any changes yet.

Present the results as a consolidated report.

### Phase 2: Update

- **Single ecosystem** (`$ARGUMENTS` given) — ask yes/no confirmation.
- **All ecosystems** (no argument) — ask which to update. Accept: `all`, comma-separated list, or `skip`.

Run **Update** steps from each confirmed ecosystem's reference file.

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
- **No python3**: `python3` is not available in this Nix environment. Use `node -e` for scripting.
