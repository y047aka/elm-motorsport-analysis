---
name: docs-hygiene
description: "Keep documentation and comments lean and true: decide which layer owns a fact (code comment, AGENTS.md, a README, a skill), prune what duplicates, and audit what remains against the code. Use when writing or reviewing comments and docstrings, when asked to prune, tidy or audit documentation, when a change adds docs along with code, and when the same fact appears to be written down twice."
---

# Documentation hygiene

Agentic coding over-documents: every agent writes the reasoning for its change
into the file it touched, the reasoning goes stale first, and the next agent
trusts the stale prose. The per-comment rules are `AGENTS.md`'s — *Never
write / Write only what the code cannot say* — and this skill does not restate
them. What lives here is the management layer: **which layer owns a fact, how
to prune, and how to audit.**

## Placement: one fact, one home

Decide the owner before writing anything, narrowest layer that can hold it:

| Layer | Holds | Never holds |
| --- | --- | --- |
| Names, types, signatures | what a call site can see | the change's story |
| A code comment | the constraint, hazard, or equal-alternatives decision at that call site — `AGENTS.md`'s list | procedure; the case for the code; history |
| A module's header / a README | why the thing is shaped so; fences and what they answer | the steps to change it |
| `AGENTS.md` | repository facts unreadable off the code: checkout state, command behaviour, seams no compiler reaches | the same fact a README already says |
| A skill (`.pi/skills/`) | the steps: what to run and edit, in order, and which frozen lists a new name joins | facts the READMEs hold |

**One fact rests in one place; every other mention is at most a one-line
pointer to it.** A fact restated in prose in two places must move twice, and a
fact that must move twice will not. The pointer is the mechanism that lets the
rest be pruned — `AGENTS.md`'s skills line, `backend/README.md`'s "adding a
round is `/skill:add-round`'s", a config header's "the steps are the skill's"
— prose moves, pointers hold.

The commonest misplacement is **procedure in a code comment or a README**:
"when adding X, also edit Y" next to one of the places X is added. The place X
is added is not the owner of the trip; the skill that walks the trip is. Cut
the comment down to the hazard that stays true outside adding, if one is there,
or point.

## Over-documentation's shapes (cut on sight)

- **The change's changelog.** A comment that reads "now also handles …" or
  "added for the 2026 round" — that is `git log`'s voice, and it is the first
  sentence to go stale.
- **A section per thought.** A README heading that contains one paragraph
  about one module which the module's own header already heads.
- **Restated structure.** "The Model holds the race and the columns" above a
  record that names the race and the columns — `AGENTS.md`'s second cut, at
  document scale.
- **Defense paragraphs.** Three sentences explaining why a short docstring is
  short. Cut the defense, keep the docstring.
- **A skill that re-lectures.** A step that explains the *why* at length
  instead of pointing to the README that holds it. Steps are imperative; the
  why is a clause and a pointer.
- **Counts and inventories left standing.** "the three here are tagged
  differently", "all fourteen rounds", `known are cota, le_mans` — these are
  facts with an expiry date stamped by the next change. They are allowed (they
  are real facts) but they join the audit below, and code that freezes them in
  a test must fail by name when they move.

## The passes

**After finishing a change** (this is also `AGENTS.md`'s Committing pass):
re-read every line of comment and doc the change added, against the list
above, and cut what it forbids. Then ask of each survivor: *what wrong thing
would the next reader do without this line?* No answer — cut.

**When pruning a tree:**

1. Find the prose's inventory: `AGENTS.md`, each `README.md`, each skill, each
   module header docstring worth more than three lines.
2. For each fact asked to move, find its other homes:
   `rg` the distinctive phrase, and the numbers ("three", "two rounds"), and
   any frozen list the prose mirrors.
3. Move procedure into the skill, keep state and *why* where they stand, and
   leave a one-line pointer at each pruned site.
4. Make the skill point back at the fact it stopped restating, so the skill
   does not become the second home.

**Auditing a doc against reality — lay it against a real change.** The way to
tell whether a runbook covers the actual work is to diff its file list against
the last merge that did the work:

```bash
git show --stat <the merge that did it>   # every file the real trip touched
```

Every file that change touched is a step, a frozen list, or a fact. Each one
must be *named* somewhere the runner will read, or the runbook has a hole; each
named step that the real change never touched is a step to re-verify or cut.

**Reading a surviving comment fairly before believing it.** A long comment is
not a wrong comment — `AGENTS.md`'s `optional`/`oneOf` note runs sixteen lines
and earns them. Test a long one by its alternatives: what wrong thing does it
stop, and is that wrong thing still possible? If the hazard it names has been
made impossible by a type or a fence since, the comment is history now — cut it
or rewrite it to the new hazard.

## Verification

Docs compile in no build, so verification is reading the claim against the
thing:

- A claim naming a command: run it, or run its `--help`, when in doubt.
- A claim naming a file, table, or key: `rg` / `ls` it.
- A count: recompute it from the thing counted (a list length, a directory
  count), don't spot-check.
- Flix doc comments: `///` goes directly above the declaration it documents —
  a module's doc sits above `pub mod`, or the compiler answers E6289. A comment
  added to a source the `circuits/` project symlinks compiles in both
  projects: verify with `.#flix-build` *and* `.#geometry-test`.
- Elm docstrings: `.#test` runs elm-verify-examples over them — an example in
  a docstring is a test, and a stale docstring example fails the build, which
  is the one documentation failure this repository can actually see.

## Hazards

- **Pruning a hazard is not pruning a comment.** `AGENTS.md`'s three licensed
  kinds survive any sweep even when they read as excess; the test is the wrong
  thing they stop, not their length.
- **Frozen lists in tests are documentation the compiler reads.** Pruning the
  prose never touches them — they move only when the inventory moves, and they
  fail by name when it moves unheralded.
- **A pointer must point at something that exists.** After any rename of a
  skill, section, or file, `rg` the pointers to the old name —
  `/skill:` references, section titles, file paths in prose.
- **Don't repeat harder.** If `AGENTS.md` says it and a README repeats it,
  decide which owns it.
