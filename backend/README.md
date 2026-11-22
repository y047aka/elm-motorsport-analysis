# backend

Two things out of one jar: the CLI that moves CSV through SQLite into JSON/JSONL, and the server that answers `/api` out of the same rows.
The flake's commands for it are `nix run .#flix-build`, `.#flix-test`, `.#cli-run`, `.#cli-load`, `.#cli-export` and `.#serve-api`.

The timing-lines report and the probe are not commands of this jar: both are words of the `circuits/` project, which links some sources here rather than resolving them.
Editing one of those linked files is compiled and tested twice, by `nix run .#flix-test` and by `nix run .#geometry-test`, and moving or renaming one breaks both until its link moves too.
Which files the links reach, and why a link is never a directory, are `circuits/README.md`'s.

Adding a round is `/skill:add-round`'s.
What follows is what the code cannot say for itself.

## The server

`Server` is `com.sun.net.httpserver` reached through Java interop: the handler is an anonymous `HttpHandler`, and `main` blocks on a latch because returning from it would take the JVM with it.
Requests are answered on a pool of eight, and each opens a connection of its own — `java.sql.Connection` is not thread-safe. `Db.connection` puts the database in WAL mode, so those reads run beside a writing run rather than behind it.

`Server.Api` decides nothing about a round and renders none of one: `Server.Api.respond` reads alone (`\ {SqlRead, RawSql}`), runs in one transaction so it reads one state of the database, and makes the same calls `Cli.Export` makes, so what is served and what is written are the same bytes.
An answer reads only what it is made of, rather than reading a round's laps to throw them away.
The timeline's answer reads `Round.Index` too and walks every lap, and `Server.flix` computes the `ETag` off the rendered bytes, so even a request that comes back 304 pays for the walk.

A route that reads nothing is answered before connecting at all, under `Sqlitefx.DbTest.runWithRows`: the calendar is `Motorsport.Calendar` rather than a count of the rows, so a database that is down stops a round being opened and not the app being used.

A 200 carries a CRC32 `ETag` that a reload revalidates into a 304, and a body goes out gzipped where the request accepts it — Le Mans's laps are 25MB, and 3.4MB on the wire.

`Round` is one round on its way out of the tables. `Round.Summary`, `Round.Index`, `Round.Timeline`, `Round.Laps` and `Round.Cars` take an `Entry` and the `DbRead` effect and read it; `Round.Render` is pure and turns what they returned into bytes. None of them knows whether a file or a request is waiting.
Those that name a driver take a `Round.Drivers` as well, read once per round.
`Round.loaded` is what both callers ask first, and it asks `laps` and `cars`: laps without cars is a round half in the database, and answered off the laps alone it would be a race whose grid was empty.

The root is the one thing the two callers differ by, and `Server.TestApi` asserts it: it compares the served calendar against `Manifest` rendered with `Cli.Export`'s root, because the dev server's fallback and a bundle's own calendar rely on one path being the other with `/static/wec` and `/api/wec` swapped.
`Manifest.toJson` is the rendering either root goes through; `Cli.Export.urlRoot` and `Server.Api.urlRoot` are what the two sides hand it.

## The tables

Seven, dropped and rebuilt on every load.
Four hold what a round did: `laps` (one lap of one car), `cars` (one car of one round), `car_drivers` (one seat of one car) and `timeline_events` (one thing that happened).
Three hold what those name: `rounds` is the calendar written down, `drivers` the names the feed repeats over every lap, and `entries` the cars a season was contested by.
A lap carries its car's number and its seat and nothing else about either, which is also all the JSONL writes out.

`timeline_events` is the one that is not a reading of the file: its rows are the laps counted and weighed against a time limit no row carries, so the load decides it once and the readers read back what it decided.

An id means nothing outside the database a run put it in, and no reader computes one.
`Db.Drivers.add` numbers a name, carried between the rounds of a run since a driver turns up in several, and `Db.Rounds.scope` reads a round's id back inside the scope it builds, so a database written under another calendar scopes to no rows rather than to another round's.

A car number names a different entry in each season, so `entries` is keyed by season and number together; `Db.Entries` says why the number alone will not do.

`cars` holds no fact the other tables do not: its rows are `DISTINCT round_id, car_number` over `laps`, and its `entry_id` follows from the round's season and the number. It is a join the tables keep, knowingly not in BCNF.
`car_drivers` looks the same and is not: its `driver_id` is nowhere in `laps`.

**A file that describes one car two ways, or names one seat two ways, loses the second silently.**
Each table keeps the first mention, so `Db.CarRow.disagreements` and `Db.CarDrivers.disagreements` are read before the insert and `Cli.Load` prints what they found — no query over the tables can find it afterwards.
A seat's disagreement changes what the rows mean: the second name's laps are credited to the first, in the grid and in the records alike.
Within a round the archive has none; between rounds it has: 2026's Le Mans file spells cars 61 and 79 `Mercedes-AMG` where that season's other rounds spell them `Mercedes`. `Db.Entries.add` keeps the first round's description and reports the later one's.

A column takes the type its Flix value already has — a `Duration` is its milliseconds, `kph` and `topSpeed` stay the feed's text — so the load parses nothing the decoder did not.
`flag_at_fl` is checked against `Motorsport.Wec.flags`, and `car_group` is nullable because the feed spells a car with no sub-class as an empty group.
`hour_offset_ms` is `(hour - elapsed) mod 24h`, a `VIRTUAL` column the database makes; that is what `Db.Schema.Computed` is, and why it is not a `Column` and never reaches a table's `all`.

Where a table's rows are stored is declared beside its keys.
A table keyed by more than a number takes `Sql.Storage.WithoutRowid`; one keyed by a number declares the column with `Db.Schema.identity`, which spells it `integer` — the one spelling SQLite reads as an alias for the row id, so no second tree is built. The DDL does not show this; `Db.TestJdbc` asks a database that took it.

`source_row` is the position the file listed the lap in, which nothing else recovers: the validator's baseline is the file's first row, and a car's drivers and the grid are in the order the file first showed them.
The reader numbers it one to n per round, so nothing is keyed by it; a unique index asserting that cost 1.88MB and bought nothing.

`car_drivers` carries the one declared index, over `driver_id`: its key leads with the round, and without the index the seats one driver sat in are a scan of every lap.

No foreign key is declared and `PRAGMA foreign_keys` is off; the load's own numbering fails a missing round, car or seat by name.
Turning them on costs two rewrites: with the pragma on, `DROP TABLE` runs an implicit `DELETE FROM`, so the drops must run children first; and the pragma is a silent no-op inside a transaction, so it belongs in `Db.connection`'s pragmas. `Round.TestSupport.onLapsAlone` — laps with no cars — is the fixture a `laps`→`cars` key would make unbuildable.

Le Mans's mini-sectors are two JSON array columns rather than thirty more, since one round in the archive has them.
They hold the fifteen of `Motorsport.MiniSector.all()` in track order, a null being a marker the feed left blank. `json_each` reads one back keyed from zero, where `Motorsport.MiniSector.positionOf` counts from one.

## Counting in SQL, deciding in Flix

`Motorsport.Metadata` and `Motorsport.Track` choose the grid's basis, break its ties and divide the lap; they take the readings rather than the laps, and neither imports `Motorsport.Wec`.

`Cli.Load.Validation` runs its five rules as SQL over the round just loaded, leaving only the messages in Flix.
`Round.Index` reads the two indices a race is read at a moment through — when the lap counter went up (a `GROUP BY`), and when each of the nineteen records changed hands (one window over every record's readings stacked into a column). They ride in the summary.

`Round.Timeline` is the third walk, and is written to a file of its own, a line at a time.
`Round.Timeline.fromLaps` is the load's; `Round.Timeline.read` sorts the rows by `elapsed_ms` with `seq` only as the tie, not by their key, which stops agreeing once a row is corrected in SQL.
`Round.Timeline.detailed` reads each event beside its lap and is handed the `Round.Index` the answer already has; the car's own best of each time is nineteen running minima per car, read off `laps`.

A class's lead is `ROW_NUMBER` picking the class's first crossing of each lap with `LAG` asking who held the one before — two queries, since SQLite settles a `WHERE` before either window.
The top class's lead is the field's in every round loaded, so the field's is not counted beside it.
An overtake is about whoever crossed the next lap first, a leader in the pits about the car that led; a boundary the leader's stop settled is no overtake.
A stop is counted at its out-lap and timed at its in-lap (`Db.Laps.pitOutLap`). The field's stops are not events: the app counts them off the laps in `Motorsport.Race.Stint`.

`Motorsport.Timeline` weighs each car's last crossing against the time limit, `Metadata`'s estimate, so `Round.Summary.particulars` is read first.
It also fixes the order events sharing an instant come back in: `List.sortBy` is not stable, so the gathering order rides in the sort key and lands in `seq`.
`Motorsport.Timeline.parts` is where the line written out and the row meet; a row that spells no event is `DbErrorKind.Other`.

`Round.Laps` reads where the car stood in the field as it crossed the line with a window beside the lap.
`Round.Cars` and `Round.Drivers` say when a round is loaded by halves: a car with laps and no `cars` row, or a seat with none in `car_drivers`, is reported rather than written out as a car with no name.

## Two stages, one database, and the jar

`Cli` runs in two stages: the load reads each round's CSV — of every round `Motorsport.Calendar` lists, under `--csv` — and rebuilds every table off it, and the export writes out of the rows alone, under `--out`, a round's summary `.json`, its laps `_laps.jsonl` one lap per line, its timeline `_timeline.jsonl` one event per line, and `index.json` beside them, in the same season directories.
`--load` and `--export` are those stages singly, and `--export-only <season>/<id>` narrows the writing stage alone, repeated to name more than one; a name no round on the calendar answers to fails the run before anything is written.

The writing stage reads no CSV: the files are an image of the rows, a row corrected in SQL is exported, and re-exporting after a renderer change costs no decoding.
A round no run has loaded fails the export rather than being written out as a race that never ran, the files it would have replaced are left alone, and `/api` answers it with a 404.

Both stages and the server compute in one SQLite database: `--database <jdbc url>` names it, `DATABASE_URL` says the same to every run in a shell, and the flake's commands name `backend/.db/motorsport.sqlite` when neither does.
One that reaches none does nothing rather than opening an empty database of its own.
The file is in the working copy so it can be queried after a run, and the flag is reached as `nix run .#cli-run -- --database ...`.

The server runs as the jar: `flix run` takes the JVM down with `main`, and the server's `main` does not return.
`flix build-jar` leaves the Maven dependencies out, so the JDBC driver is named on the class path beside the jar.
`.#serve-api` answers `/api/health`, `/api/wec/index.json`, and a round's `/api/wec/<season>/<id>.json`, `_laps.jsonl` and `_timeline.jsonl`.

## Why SQLite

The database is a cache derived from the CSV, not a system of record: every table is dropped each run, so durability, replication and migration are out of the question.
What is left is one writer and reads that are whole-round scans, `GROUP BY`, window functions and `json_each`.
DuckDB is the near miss — its `LIST` types fit the mini-sectors better — but its files lock per process, and `.#serve-api` stays up across a `.#cli-run`.
Twenty seasons of the WEC are on the order of 1.5 million laps and 150MB.

## `Sqlitefx`, the database library

The database is reached through `backend/sqlitefx`, a SQLite port of [sqlfx](https://github.com/ababup1192/sqlfx) with a README of its own: what it is, where it differs from sqlfx, and where its line with this project runs.
`src/Sqlitefx/` is a symlink per file into it, the way `circuits/` reaches this `src` (`circuits/README.md` says why a link is never a directory), so `.#flix-test` compiles the library and `.#sqlitefx-test` tests it.
Only what this project reads is linked, and what that reads: not the pool, migrations, retry, fragments or the `.q` generator. A module the library starts importing is linked by hand, and a link left out fails as an undefined name.

- No `Pool`: the CLI opens one connection per run and the server one per request, which WAL mode makes work.
- No migrations: the `DROP TABLE`s are the migration.
- No `.q` generator: most statements are built with `Sql`, and the written ones are checked by running every one against the in-memory database `Round.TestSupport` builds (`Round.TestReadersResolve` makes every reader answer with a row, so its projection runs). The generator's parser is PostgreSQL's and refuses `WITH RECURSIVE` and a `WITH` inside a CTE, which is where the hardest statements here live.

`Db` is the seam: its table modules and row types are the whole of what the application tells `Sqlitefx` about itself, and `Db.connection` the whole of how it opens one.

The JDBC driver arrives through `[mvn-dependencies]`, resolved into the gitignored `lib/` by `flix build`, and is named twice: in this `flix.toml` and in `sqlitefx/flix.toml`. **The two versions move together** — this project runs the library's code on whichever driver its own `flix.toml` resolves, and the library's tests ran on the other.
`/skill:update-deps` does not reach it, so it is raised by hand against `org.xerial:sqlite-jdbc`'s `maven-metadata.xml`. Its version is the SQLite it carries plus a build number: `3.53.4.0` is SQLite 3.53.4.

## The database effects

Reaching a database is an effect, so what a round would send can be read back without one: `Sqlitefx.DbTest.runRecording` keeps the statements and answers a write with the count it is handed, and `runWithRows` answers every read with the rows the caller named.
`java.sql` is imported by `Sqlitefx.Jdbc` and `Sqlitefx.JdbcConvert`; this project names `java.sql.Connection` only to hand the one `Jdbc.withConnection` opened to `Tx.withTx`, and no effect names a table or a column.

Reading and writing are two effects: `Round`'s readers, `Server.Api` and `Cli.Export` would not compile with a statement that changes the database.

`DbErr` and `TransientDbErr` are what a reader does not carry a `Result` for: their one operation does not return, so `Round.Summary.read` answers with a `Metadata` and the failure travels to the boundary that asked.
`Sqlitefx.DbError.runWithKind` is where a raised failure comes back as a value, and `runWithFailure` the same with the transient ones folded into `DbError.Failure`.
Which of the two a failure travels by is read off its `DbErrorKind` constructor (`DbError.raise` routes it), so a new kind meets a pattern that has to say which.

`\ DbRead` is `{SqlRead, TransientDbErr, DbErr, RawSql}`, `\ DbWrite` is `{SqlWrite, TransientDbErr, DbErr, RawSql}`, and `\ Db.DbAll` is both with `SqlSavepoint`: `Db`'s own, since sqlfx's leave `RawSql` out and `Db.flix` says why these do not.
Flix has no subeffecting here — a `\ DbRead` function is not a `\ Db.DbAll` one — so a caller taking a reading as an argument names the half it uses (`Cli.Load.loadRound`: `DbRead + SqlWrite`) or the whole it hands over (`Main.onDirectories`, `Round.TestSupport.onRound`: `Db.DbAll`).

The statement effects still answer with a `Result`; the `SqlRead` header in `sqlitefx/src/Sqlitefx.flix` says why. `Sql.orRaise` turns a reading's into a raised failure, so nothing outside the library calls an operation: the wrappers of `Sqlitefx.Sql` are what `Sql` and `Db.Schema` reach.
`Sqlitefx.Jdbc.withConnection` opens, works in and closes a database for a run, a test and the server alike, and the connection is in autocommit outside a transaction.

A failure is a `DbErrorKind`, and the sentence is `DbError.describe`'s.
The transient ones are `ConnectionLost` (no database reached) and `Timeout` (a lock SQLite waited out rather than got); `sqlitefx/README.md` holds the table of result codes.
Constraint violations name what SQLite names: `UNIQUE constraint failed: laps.round_id` becomes `UniqueViolation("laps.round_id")`.
`SchemaMismatch` is a table or column the database has not got, `DecodeError` a cell the reading could not read, and `Other` the rest — what the JVM threw, a query that had to answer with a row and did not, and rows that came back whole and describe no round.

`Server.Api` answers a transient failure with 503 and everything else with 500.
A failure names tables and files in its own words, so those ride in the response's `cause`, which `Server.send` logs and does not send.

A row is `Sqlitefx.Row.Row`: the labels the driver reported and the cells as `SqlValue`. SQLite types a value rather than a column, so a cell is what the driver found, not what the schema declared.
`Sql.decode` puts a row's cells in the order its projection names them, so a clause and a reading that disagree fail by naming the column rather than by answering with the cell beside it. Two projections under one label — a join naming both sides' `elapsed_ms` — are answered in the order the clause writes them.

`Tx.withTx` in `Cli.Load.runAll` is the one commit of a load, and rolls a raised failure back before raising it again, so the rebuild of every table is a single transaction: a run killed partway leaves the rounds it was rebuilding from.
`Tx.withSavepoint` is a part of one; its name is checked against `Sqlitefx.Savepoint`'s rule, since it goes into a statement as text.
`Cli.Load` marks one per round, so a round the database refuses is reported without taking the run with it, and frees the names it numbered — advancing past it would leave a name numbered and unwritten for every later round to reference.
A table's rows go out a thousand to a statement (`Db.Schema.insertRows`), and SQLite takes or refuses each statement whole.

## `Db.Schema`, and the two declarations

`Db.Schema` is a table declared as its columns, and `Db.Laps` and `Db.Cars` are each one declaration: a column's name, type, binding and reading are one record, and a table's `all`, DDL, insert and projection are views of it.
A `Column` carries the row type it binds, so a column of one table cannot be bound from a row of the other, and a query reads `Db.Laps.table` rather than spelling it.

**`all` and `selection` name the same columns twice, in an order no compiler checks**: `Db.TestLapRow` and `Db.TestCarRow` assert it, and both are declared in one file so the two orderings are read together.
Flix cannot read a record's fields, so `all` restates each name; only the `bind` is checked against the row type.
`Db.LapRow` and `Db.CarRow` are the feed's side and name neither `Db` nor `Sql`.
A query reading from a common table expression cannot use a declared column, since the expression's `SELECT` is text and would not follow a rename.

## `Sql`, the query language

`Sql` is the repository's query builder over this database. A `Sql.Sel` is one projection and its reading held in the same value, so the clause is rendered from the readings and a column is named once.
A `Sql.Project` is a column, a reading or a tuple of them; `Sql.map` takes the columns and hands back what to read, and `Sql.reading` turns the tuple into the caller's type.

A row read as a record is `Sql.record` extended a field at a time with `Sql.field`, as `Db.Laps.selection` is: a field left out is not a `LapRow`, and one named twice does not typecheck.
It is also the only form past eight columns, and the cheaper one for the type checker — two dozen curried readings need a 2m stack where the record needs 512k.

A value is bound, never written in: a `Sql.Frag` is SQL and the values its `?` placeholders take, so concatenating two pieces carries both.

`filter` takes a `Sql.Expr[Bool]` of the columns the source declared, so a column of another source cannot scope this query.
**The round is applied where the rows come from**: `Db.Laps.rows` and `Db.Cars.rows` take the round and hand back rows already filtered by it, so a reader cannot forget the scope. A reader ANDs its own onto them.
A written statement is the one place the scope can be left out and still be well formed, so `Sql.statement` refuses one that binds no value. That catches a statement naming no round; it does not prove the value is the round's (`Sql.refuseUnscoped`).
Two sides of a join both carry a `round_id`, but their records do not unify, so a scope built from the wrong one does not compile.
`Db.Laps.scope` is the same predicate as a piece for a `WHERE` the caller wrote, and `Db.Rounds.scope` takes the column under the name its source gives it, as `Round.Summary.carBuilds` hands its `c`.
Nullability is in the type: `Sql.isNotNull` asks for an `Expr[Option[_]]`.

A built query is `Sql.rows` (or `Sql.access`, where the caller says what columns the source has) with `filter`, `groupBy`, `orderBy`, `limit` and `using` in any order, `map`, and `selectAll` or `selectOne`. Clauses come out in SQL's order, an empty one is left out, and `filter` twice asks both. `Sql.toStatement` is pure.

An aggregate or a window reads back as its projection does, so `min(c#s1Ms)` is an `Option[Int32]` because `s1_ms` is one, and `lag(l#carNumber, w)` is an `Option` because a window's first row has no predecessor. `opt` is the same from the other side: an aggregate over an empty group answers null.
A named `Sql.Window` is spelled once in the `WINDOW` clause, which is how nineteen running minima are one clause.
`Sql.unionAllTagged` stacks the arms of a `UNION ALL` under numbers it picks; `Round.Index` is the caller, and nothing in it names a number.

**Some queries are written rather than built**: a `WITH`, a window or a correlated subquery is past the builder's reach, which takes the projection and the four outer clauses.
`Sql.statement` takes such a statement one clause per line — Flix has no multi-line string literal — with `{{name}}` for each piece it cannot write itself and `%%` for the `SELECT` clause, which `columnsOf` renders from the projection that reads it back. Values bind in the order their `?`s stand. `Sql.spliced` is the same for a piece: a CTE, a `UNION ALL` arm, a scalar subquery.
`${l#carNumber}` interpolates a declared column's name, and `Sql.sqlOf` an aggregate's or a window's text.
Which statements are written is told by the call sites of `Sql.statement`; a `GROUP BY` or a plain scan stays built.
What stays text is a column no declaration reaches — the fifteen `b0`..`b14` a mini-sector best is gathered out of, the `m.key` and `m.value` of a `json_each`, and the window clauses themselves.

**A written statement is checked by the database, not the build**: SQLite resolves names when it prepares a statement, so a missed rename is a refusal at run time.
`Sqlitefx.Jdbc.raiseRefusal` carries the statement into `SchemaMismatch` and `Other` (a mistyped keyword is `Other`), whose messages otherwise say nowhere to look.

A column a CTE makes up is `Schema.derived`; `Round.Timeline.crossings` declares them, and `Schema.qualified` reads a column under each name a source gives it (`l`, `led`, `stop`, `between_`, `c`, `l1`). `Sql.column` is a column no declaration reaches, typed by the caller's word.
What a `LEFT JOIN` does to the far side is `Sql.orNull`, needed for a column the table has on every row, not for one nullable in its own right.

`Sql.access`'s columns are the caller's word that the source text has them, and a wrong word fails where the query runs. `Db.Laps.rows` and `Db.Laps.rowsBeside` (the table beside a `json_each` of its own) are the two that cannot be wrong.

The load's statements are `Sql.createTable`, `Sql.dropTableIfExists` and `Sql.insertRows`, which binds each row in the order the statement names its columns, both read off one list.
A `Sql.Key` is declared columns, so a key over an undeclared column does not typecheck; that its columns are in `all` is `Db.TestLapRow`'s.

`Sql` is one file: splitting it means submodules, and Flix has no wildcard `use`, so every call would grow a segment or every caller a `use` line per name.

## Testing

- **Where a test lives** — `test/Motorsport/` drives the domain's decisions given the readings they are made from and needs no database; `test/Round/` and `test/Server/TestApi.flix` drive the reading and need one. A subject with both has a file in each, named for the module it drives.
- **A reading with no database** — a CSV feed, an Overpass answer, a circuit's published timing lines — is driven under `circuits/` by `nix run .#geometry-test`, which compiles its links to this `src` and tests nothing else of it. The circuit words the summary sends are the one list both projects hold; `circuits/test/check-sources.mjs` lays the two copies together.
- **A clean build** — `flix build` and `flix test` are incremental and CI is not: a compile that only fails from cold passes locally until `backend/build` is removed. `rm -rf backend/build` before believing a green run.
- **The type checker's stack** — it recurses once per expression, and Linux gives its thread a smaller stack than macOS, so a deep enough chain compiles here and overflows in CI. Check with `java -Xss704k -jar <flix.jar> build` from `backend/`: 704k builds the tree as it stands and 672k does not, so a change that raises that number is the one to look at. What sets it is `Motorsport.Wec.decoder`, whose sixteen fields are a curried lambda, a record literal and a pipeline apiece; stubbing it out takes the build under 576k.
- **The database** — a test drives JDBC against the in-memory database `Round.TestSupport.url` names, a connection of its own per test. A test that reaches no database fails rather than skipping. `Db.TestJdbc` drives a file database too, under a directory that does not exist yet: the directory `connect` makes, the journal mode `Db.connection` sets, and two connections at once are reached no other way.
  What a caller does about a failure is decided off the kind, so it is tested without a database: `Server.TestApi` is where a `Timeout` becomes a 503 and a `SchemaMismatch` a 500 with the driver's words kept out of the body; how a result code becomes a kind is `sqlitefx`'s tests'.
