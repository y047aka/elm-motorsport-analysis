# sqlitefx

A SQLite database library for Flix: [sqlfx](https://github.com/ababup1192/sqlfx) 0.7.0 with its PostgreSQL parts rewritten for SQLite 3, built on Flix 0.79 and `org.xerial:sqlite-jdbc`.
Where it came from, and its licence, are `NOTICE`'s and `LICENSE`'s.

It is not published: it lives in this repository, and `backend` is what it is for.
`nix run .#sqlitefx-test` runs its tests, against SQLite databases in memory and in temporary files; nothing has to be started first.

## How to use it

The API is sqlfx's, and [sqlfx 0.7.0's README](https://github.com/ababup1192/sqlfx/blob/v0.7.0/README.md) is its guide: the effects, `Decoder`, `Sql`, `Fragment`, `Tx`, `Pool`, `Migrate` and `DbTest` read as it says, with every `Sqlfx` read as `Sqlitefx`.
The differences below are what that guide says that is not true here.
`docs/` is sqlfx's design notes as released, and speaks of PostgreSQL throughout.

## What differs from sqlfx

| Where | sqlfx | sqlitefx |
|---|---|---|
| `Jdbc.ConnectionConfig` | `{ url, user, password }` | `{ url, pragmas }`; `Jdbc.config(url)` sends `foreign_keys = ON` and `busy_timeout = 5000` |
| A value on the wire | the column's type | one SQLite storage class per `SqlValue` case; the table is `JdbcConvert`'s header |
| A value read back | by the column's declared type | by the class SQLite kept it in; `SqlValue.as*` turn the class back into the type |
| `= ANY($1)` | a PostgreSQL array | `IN (SELECT value FROM json_each($1))`: an array is sent as a JSON array |
| A failure | SQLSTATE | the result code; the table is `SqlState.classify`'s |
| Lock waited out | `55P03` → `Timeout` | `SQLITE_BUSY` / `SQLITE_LOCKED` → `Timeout`; `Deadlock` is never raised |
| Constraint name | the constraint's | what SQLite names: `users.email` for UNIQUE and NOT NULL, the name of a named CHECK, nothing for a foreign key |
| A failed statement in a transaction | aborts it | rolls back that statement alone, so `Tx.commit` asks nothing first |
| Pool | pgjdbc's DataSource | sqlite-jdbc's, and the pragmas are sent on every borrow |
| Concurrent `Migrate.apply` | one advisory lock over the run | `BEGIN IMMEDIATE` per file, the record read again under it |
| Migration record | `sqlfx_migrations`, `applied_by` | `sqlitefx_migrations`, `applied_at` in epoch microseconds, no `applied_by` |
| Placeholders | `$n` | `$n`, or positional `?` when a statement has no `$n`; never both |
| A statement refused | the driver's sentence | for `SchemaMismatch` and `Other`, the sentence and the statement's head and tail, since SQLite names what it could not resolve and never where |

Three things are still sqlfx's and still PostgreSQL's:

- **The `.q` generator** — `Sqlitefx/Q/` and `Main.flix`'s `gen`. Its parser and its DDL reader are PostgreSQL's dialect, and refuse `WITH RECURSIVE` and a `WITH` inside a CTE, so it does not read this repository's hardest statements either way.
- **`examples/blog`** — the generator's snapshot: `test/Q/TestGen.flix` regenerates it and compares. Its own `Makefile` and `test/Pg/` are sqlfx's and are not run here.
- **The pool's fault-injection suites** (`TestPoolFatal`, `TestPoolLeaks`, `TestPoolAbortedTx`, `TestEvictProcedure`), which wrapped pgjdbc's DataSource. The paths they covered are the code sqlfx shipped, unchanged except for the DataSource, and untested against SQLite.

## The boundary with `backend`

`backend` reaches SQLite today through `Lite3fx` (`backend/src/Lite3fx/`), which `backend/README.md` describes. sqlitefx is to replace it, and the line between the two is where `Lite3fx`'s already is:

- **sqlitefx** reaches a database and knows nothing about what is in one: the effects and their aliases, the failure kinds, values and rows, connections, transactions, savepoints, the pool, migrations, and the handlers tests run under. No module names a table or a column.
- **`backend`** keeps `Sql` (its query builder), `Db.Schema`, the `Db.*` tables and rows, and everything above them. `Db` is the whole of what the application tells the library about itself.

What `backend` may name is the effects (`Sqlitefx.DbRead`, `DbWrite`, `Db`, `RawSql`), `DbError`, `SqlValue`, `Row`, `Sql`'s statement functions, `Tx`, `Jdbc.withConnection`, and `DbTest`. `JdbcConvert`, `SqlState`, `Jdbc`'s other functions and `Db`'s guards are the library's own.

Flix has no local path dependency, so `backend` compiles sqlitefx the way `circuits/` compiles `backend`: a symlink per file, never per directory (`circuits/README.md` says why), from `backend/src/Sqlitefx/` into `src/Sqlitefx/`. Only what `backend` reads is linked: not `Q/`, not `Main.flix`.

## Switching `backend` from Lite3fx

Each of these is a decision the switch has to make, since Lite3fx and sqlfx answer it differently:

- **`insertMany`.** Lite3fx's `SqlWrite` has it, since laps arrive a thousand at a time; sqlfx's does not. Either the op is added here, or the load writes multi-row `INSERT`s through `execute`.
- **`commit` and `rollback`.** They are `SqlWrite` operations in Lite3fx, so a recording handler sees a commit go by (`Cli.Load.runAll` is its one caller); sqlfx's `Tx.withTx` commits on the connection it is handed.
- **Recording.** `Lite3fx.Recording.statements` answers the server's statement-free routes; `DbTest.runRecording` is the nearest here, and is handed the rows to answer with.
- **Failure names.** Lite3fx's `Busy` and `Unreachable` are `Timeout` and `ConnectionLost` here; `Server.Api` turns both into a 503.
- **Pragmas.** `backend` runs with `journal_mode = WAL` and with `foreign_keys` off (`backend/README.md`), so it passes its own list rather than `Jdbc.config`'s.
- **Autocommit.** Lite3fx turns it off on every connection; sqlitefx leaves it on outside `Tx`.
