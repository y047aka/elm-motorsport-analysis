---
name: distill-docs
description: "Distill documentation and comments down to what survives: find where a fact is written down twice, cut what over-documents, leave a pointer where prose was removed, and verify what remains against the code. Use when asked to distill, prune, tidy or audit documentation, when re-reading the comments and docstrings a change added, and when the same fact appears to be written down twice. This skill only takes documentation down — writing new documentation, restructuring it, or moving knowledge into a new skill is the job of the document being written."
---

# Distilling documentation

Agentic coding over-documents: every agent writes the reasoning for its
change into the file it touched, the reasoning goes stale first, and the next
agent trusts the stale prose. Distillation is the discipline of taking that
down: what to cut, what to shorten, and what a cut leaves behind as a
pointer. The
per-comment rules of what may be written at all are `AGENTS.md`'s (*Never
write / Write only what the code cannot say*), and nothing here restates
them.

## One fact, one home

The target of every pass is a fact written in prose in two places: it must
move twice, and a fact that must move twice will not.

- **Where a fact is duplicated, the copy closer to the thing it describes
  owns it** — a comment over a header, a header over a README, a README over
  `AGENTS.md`. Keep the owner's copy; leave one line pointing at it where the
  others were.
- **A pointer is a one-line mention of the thing, not of its contents.**
  "the steps are `/skill:add-circuit`'s", "`backend/README.md` holds the
  rest". Prose moves; pointers hold.
- **A cut is only a cut when the fact still lives somewhere.** Find where the
  removed sentence lives now before removing it; if nowhere does, that is a
  relocation someone else decides, not a distillation.

## What over-documents (cut on sight)

- **The change's changelog.** "now also handles …", "added for the 2026
  round" — `git log`'s voice, and the first sentence to go stale.
- **Restated structure.** "The Model holds the race and the columns" above a
  record that names the race and the columns.
- **The call-site chronicle.** "Called from X when Y, before Z" above the
  called function — every new caller must update it, and none will. The
  account of why a call is made belongs at the call site, beside the code
  that makes it.
- **A reach past the boundary.** A domain module's comment about the page or
  command that uses it — the far side changes and the comment drifts with it,
  and it reads as coupling the code does not have. Each side's story belongs
  on its own side of the seam.
- **A misplaced explanation.** A method's doc that describes one line inside
  the method — the explanation belongs above that line, or nowhere. A reader
  who meets the code first never meets the comment.
- **Unanchored vocabulary.** A comment whose nouns belong to no identifier in
  the code below it — the reader cannot find the thing it names, and a rename
  of that thing leaves no trace to follow. Say it in the words the code uses.
- **The half-truth that deepens the mystery.** "this class is no longer used
  by the screen" — and the reader asks *then where, and why is it still
  here?* A hazard comment that does not answer the next question it provokes
  is a tease: finish it or cut it.
- **A section per thought.** A README heading over one paragraph that the
  module's own header already heads.
- **Defense paragraphs.** Three sentences explaining why a short docstring is
  short. Cut the defense, keep the docstring.
- **Procedure in a comment.** "when adding X, also edit Y" next to one of the
  places X joins — the trip belongs elsewhere; cut down to the hazard that
  stays true outside it, or to nothing.
- **A skill that re-lectures.** A step that explains its *why* at length.
  Steps are imperative; the why is a clause and a pointer.
- **The same sentence on both sides of a call.** Caller and callee each
  carrying it — one home applies inside the file too: keep the copy beside
  the code that decides, cut the echo. Where the behavior is fully shown by
  a test's name, both copies are optional.
- **Counts and inventories left standing.** "the three here are tagged
  differently", "all fourteen rounds", `known are cota, le_mans, barcelona` —
  real facts with an expiry date stamped by the next change. They survive,
  but they join the audit below; code that freezes them in a test must fail
  by name when they move.

## The passes

**After a change.** Re-read every comment and doc line the change added, cut
what `AGENTS.md`'s list forbids, then ask of each survivor: *what wrong thing
would the next reader do without this line?* No answer — cut. Then read it
once as prose, not as a scan: does the sentence actually parse, is the
reference unambiguous, do its terms appear in the code beneath it? A comment
that reads as "probably fine" at a glance is exactly the failure a second,
slower reading catches.

**When distilling a tree.** Inventory the prose (`AGENTS.md`, each `README.md`,
each skill, each module header worth more than three lines); for each fact
asked to shrink, `rg` its distinctive phrase, its numbers ("three", "two
rounds"), and any frozen list it mirrors; then distill to the owner plus
pointers.

**Auditing a doc against reality — lay it against a real change.** Diff the
runbook's file list against the last merge that did the work:

```bash
git show --stat <the merge that did it>   # every file the real trip touched
```

Every file the real change touched must be *named* somewhere the runner will
read, or the runbook has a hole; every named step the real change never
touched is one to re-verify or cut.

**Before believing a long comment.** A long comment is not a wrong comment —
`AGENTS.md`'s `optional`/`oneOf` note runs sixteen lines and earns them. Test
it: what wrong thing does it stop, and is that still possible? If a type or a
fence has since made the hazard impossible, the comment is history — cut it
or rewrite it to the hazard that is left.

## Verification

Docs compile in no build; verification is reading each surviving claim
against the thing:

- A claim naming a command: run it, or its `--help`, when in doubt.
- A claim naming a file, table, or key: `rg` / `ls` it.
- A count: recompute it from what it counts; don't spot-check.
- Flix doc comments: `///` sits directly above what it documents — a module's
  doc above `pub mod`, or E6289 answers. One under `backend/src` that the
  `circuits/` project symlinks compiles in both projects: verify with
  `.#flix-build` *and* `.#geometry-test`.
- Elm docstrings: `.#test` runs elm-verify-examples over them — an example in
  a docstring is a test, and a stale example fails the build; with Flix's
  E6289, these are the few documentation failures a compiler can actually see.

## Hazards

- **Pruning a hazard is not pruning a comment.** `AGENTS.md`'s three licensed
  kinds survive any sweep; the test is the wrong thing they stop, not their
  length.
- **Frozen lists in tests are documentation the compiler reads.** Pruning the
  prose never touches them; they move only when the inventory moves, and fail
  by name when it moves unheralded.
- **A pointer must point at something that exists.** After any rename, `rg`
  the pointers to the old name — `/skill:` references, section titles, paths
  in prose.
- **Don't repeat harder.** If two documents disagree on who owns a fact,
  decide the owner; do not add a third copy.
- **A skill's description is its only reach.** The frontmatter `description`
  is what makes a skill load at all; distil bodies freely, but cutting a
  trigger phrase from a description hides a skill whose body still reads as
  maintained.
