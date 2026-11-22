# sqlitefx

A SQLite database library for Flix: [sqlfx](https://github.com/ababup1192/sqlfx) 0.7.0 with its PostgreSQL parts rewritten for SQLite 3, built on Flix 0.79 and `org.xerial:sqlite-jdbc`.
Where it came from, and its licence, are `NOTICE`'s and `LICENSE`'s.

It is not published: it lives in this repository, and `backend` is what it is for.
`nix run .#sqlitefx-test` runs its tests, against SQLite databases in memory and in temporary files; nothing has to be started first.

## How to use it

The API is sqlfx's, and [sqlfx 0.7.0's README](https://github.com/ababup1192/sqlfx/blob/v0.7.0/README.md) is its guide: the effects, `Decoder`, `Sql`, `Fragment`, `Tx`, `Pool`, `Migrate` and `DbTest` read as it says, with every `Sqlfx` read as `Sqlitefx`.
The differences below are what that guide says that is not true here.

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
| A statement refused | the driver's sentence | for `SchemaMismatch` and `Other`, the sentence and the statement's head and tail, since SQLite names what it could not resolve and never where |

Two things are still sqlfx's and still PostgreSQL's:

- **The `.q` generator** — `Sqlitefx/Q/` and `Main.flix`'s `gen`. Its parser and its DDL reader are PostgreSQL's dialect, and refuse `WITH RECURSIVE` and a `WITH` inside a CTE, so it does not read this repository's hardest statements either way.
- **The pool's fault-injection suites** (`TestPoolFatal`, `TestPoolLeaks`, `TestPoolAbortedTx`, `TestEvictProcedure`), which wrapped pgjdbc's DataSource. The paths they covered are the code sqlfx shipped, unchanged except for the DataSource, and untested against SQLite.

## The boundary with `backend`

`backend` reaches SQLite through this library, and the line between the two is:

- **sqlitefx** reaches a database and knows nothing about what is in one: the effects and their aliases, the failure kinds, values and rows, connections, transactions, savepoints, the pool, migrations, and the handlers tests run under. No module names a table or a column.
- **`backend`** keeps `Sql` (its query builder), `Db.Schema`, the `Db.*` tables and rows, and everything above them. `Db` is the whole of what the application tells the library about itself.

What `backend` names is the effects, `DbError`, `SqlValue`, `Row`, `Sql`'s statement functions, `Tx`, `Jdbc.withConnection`, and `DbTest`. `JdbcConvert`, `SqlState`, `Jdbc`'s other functions and `Db`'s guards are the library's own.

`backend/src/Sqlitefx/` is a symlink per file into `src/Sqlitefx/`, since Flix has no local path dependency, and only what `backend` reads is linked: a module that starts importing one not yet linked fails `backend`'s build by name until the link is added. `backend/README.md` holds which modules those are, and what `backend` decided where it uses this library differently from how sqlfx's README does.

A change here is checked by both suites: `nix run .#sqlitefx-test`, and `nix run .#flix-test`, which compiles the linked files against `backend`.
