---
name: commit-push
description: "Commit the requested changes and push the current branch — and nothing else. Use when the user asks to commit, push, or commit and push. This skill never creates a pull request, never force-pushes, and never invents a commit the user did not ask for."
---

# Commit and push

The user's "コミット、pushしてください" means exactly two acts: a commit and
a push. A pull request is not the third. The remote answers every push in this
repository with a URL offering to create one — that is output text addressed
to the human, not a step to run. Never open it, never run `gh pr create`,
never offer one as a next step when reporting.

## Before staging

- `git status --short` — the task's files are what gets committed. A file in
  the scope the task never touched: ask, do not commit it quietly. A small
  factual fix found *while verifying the task* (a stale count, a dead
  pointer) rides along only when the subject says so.
- The obligations the change carries were verified in their own documents —
  the `.#test` / `.#flix-build` / `.#geometry-test` fences, the VRT baseline
  route the `vrt` skill owns. If nothing in this session has compiled or run
  what the change can break, say that in the report rather than committing
  silently.
- `AGENTS.md`'s Committing section asks for its comment re-read once the code
  is finished. A commit request arriving before that pass triggers the pass,
  not a skip.

## The message

Read `git log --oneline -5` first and join its voice: `<type>: <prose
subject>`, lowercase after the colon, one line, saying what the change *is*
in the repository's own words. The log names the types in use — take the one
whose history the change belongs to. No body unless the user asks; the
subject earns its length, not the other way around.

## Staging and committing

- Stage by path; a `git mv` already staged the rename, and `git commit` shows
  it as `rename old => new` — stage the content change on a renamed file
  together with the rename so the pair is one commit.
- Never `git add -f` an ignored file. The un-kept rounds' export files are
  ignored because they are bytes the rows already say — `AGENTS.md` says
  which are kept.
- An empty `git status` means there is nothing to commit: say so; an empty or
  `--allow-empty` commit is noise.

## Pushing

```bash
git push origin HEAD
```

Push the branch you are on. A non-fast-forward rejection is never answered
with `--force` or `--force-with-lease` from this skill: fetch, look at what
moved, and report — whose commit moved it and what would be overwritten is a
human's decision. An already-pushed commit is never amended or rebased after
the fact unless the user asks for it by name.

## Reporting

The report is the commit hash, the message, the files and count from the
commit output, and the branch pushed. When the remote printed the PR URL,
the report says no PR was created — one clause, no ceremony, no offer.
