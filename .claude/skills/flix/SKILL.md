---
name: flix
description: "Diagnose Flix compile errors and write Flix the way this repository does. Use when a `nix run .#flix-build` / `.#flix-test` fails, when an error code appears (E6217 unused effect, E6218 mismatched effects, E6289 misplaced doc-comment, E6629 expected, E2136 undefined name, E0237 not accessible, E6794 unable to unify, E6469 effect formulas, E7685 unexpected argument), when a parse error has no obvious cause, when adding or changing an effect, handler or signature under /flix, and before believing a green build."
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(nix run .#flix-build*)
  - Bash(nix run .#flix-test*)
  - Bash(nix shell nixpkgs#jdk21_headless*)
  - Bash(rm -rf flix/build*)
  - Bash(mkdir -p flix/build*)
  - Bash(ls *)
  - Bash(cat /nix/store/*)
  - Bash(find /nix/store*)
---

# Flix in this repository

Flix 0.75.1, via the flake. `flix/README.md` says what the code under `/flix`
*is*; this says what the compiler does when you change it.

## Checking

```bash
nix run .#flix-build     # compile src/ and test/
nix run .#flix-test      # compile and run the tests
```

Both are incremental and CI is not, so **`rm -rf flix/build` before believing a
green run** — a compile that only fails from cold passes locally otherwise.

The type checker recurses once per expression, and the thread it runs on gets a
smaller stack on Linux than on macOS: a chain deep enough compiles here and
overflows in CI. Check a change that adds depth by running the compiler with the
stack cut down. `references/verifying.md` has the recipe, including how to find
the compiler jar (the obvious `find` finds the wrong one).

## When a build fails

1. Read the **first** error, not the last. One parse error inside a module makes
   every later declaration in that file look missing, and the resolution errors
   it produces name other files (see `references/syntax.md`, "a parse error
   travels").
2. Match the symptom against the two reference files below.
3. Only then read the code.

| Symptom | Where |
|---|---|
| Anything about effects, handlers, `\ ef`, `ef - {...}` | `references/effects.md` |
| Parse errors, names, modules, records, Java interop | `references/syntax.md` |

Both files separate what has been **seen in this repository** — with the file
that carries the workaround — from what is **reported elsewhere** and has not
been hit here. Add to the first list when you hit something new, and say where.

## Writing

- The effect belongs in the signature; do not `run` it early. A handler is
  installed at the boundary that owns it — for the database, that is
  `Db.Jdbc.withConnection`, `Db.runRecording` and `Db.runWithError`, and
  nothing else installs one.
- Aliases are what signatures say (`\ DbRead`, not `\ {SqlRead, DbErr}`).
- Comments follow the repository's rule in `AGENTS.md`: an outside constraint, a
  hazard, or a decision whose alternatives looked equal. Nothing else.
