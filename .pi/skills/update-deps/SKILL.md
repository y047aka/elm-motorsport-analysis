---
name: update-deps
description: Audit and update all project dependencies (npm, Elm, Rust/Cargo, Nix flake). Takes an area (npm, elm, rust, nix) and optionally minor or major.
disable-model-invocation: true
---

# Update Dependencies

One reference per ecosystem. Read it before touching that ecosystem:

| Ecosystem | Reference |
|---|---|
| npm | `references/npm.md` |
| Rust | `references/rust.md` |
| Nix | `references/nix.md` |
| Elm | `references/elm.md` |

Arguments name an ecosystem, optionally with a scope (`npm minor`, `rust
major`). No arguments means every ecosystem audited at minor scope; a bare
ecosystem is audited at both scopes and the user picks one to apply — one
scope per run. Elm has no scopes.

Rules the references do not repeat:

- Start from `git status --short`; suggest committing or stashing before
  anything is updated.
- Audit everything asked for before changing anything, and present one
  consolidated report. Where two audits share a command, run it once and read
  it twice.
- After updating, run the Verify commands of every updated ecosystem —
  deduplicated across ecosystems — then show `git diff --stat`. Commit only
  when asked, following the repository's conventions (`git log --oneline`).
- A network error in one audit: report it and continue with the rest.
- `python3` is not available in this Nix environment.
