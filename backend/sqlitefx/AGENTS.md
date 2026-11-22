# sqlitefx

The SQLite port of sqlfx that `backend` reaches SQLite through; `README.md` says what it is, how it differs from sqlfx, and where its boundary with `backend` runs.
The repository's `AGENTS.md` applies here too, with the one difference below.

## Comments

The sources keep sqlfx's convention, and a change continues it rather than mixing two: a comment is in Japanese, says the How in code, the What in a test, and above all the **WhyNot** — the alternative that looked as good, and why it was not taken.
Where the alternative is sqlfx's PostgreSQL behaviour, name it: that contrast is what the next reader comparing the two needs.
The Flix rules sqlfx wrote down (reserved words, comment placement, type design) are `docs/flix-conventions.md`'s.

## Commands

`nix run .#sqlitefx-test` from the repository root; `flix build` and `flix test` inside this directory with the flake's Flix.
A test that needs a database opens SQLite in memory (`file:<name>?mode=memory&cache=shared`, one name per test, since tests run in parallel) or, where locking matters, in a temporary file.
