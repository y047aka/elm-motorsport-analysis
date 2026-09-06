# flix

Two things rather than one: the CLI that moves CSV through SQLite into
JSON/JSONL, and the server that answers `/api` out of the same rows, both out
of the same jar. They are run through the repository's Nix flake, which the
root `CLAUDE.md` lists in full: `nix run .#flix-build`, `.#flix-test`,
`.#cli-run`, `.#cli-load`, `.#cli-export`, `.#serve-api`.

What follows is what the code cannot say for itself.

## The server

`Server` is `com.sun.net.httpserver` reached through Java interop: the
handler is an anonymous `HttpHandler`, and `main` blocks on a latch because
returning from it would take the JVM with it. Requests are answered on a pool
of eight, and each one opens a connection of its own —
`java.sql.Connection` is not thread-safe. `Db.Jdbc.connect` puts the database
in WAL mode, so those reads run beside a writing run rather than behind it.

A Flix effect handler runs inside a request, which is why the endpoints reuse
`Round`'s readers rather than restating them: `Server.Api.respond` runs under
`Db.Jdbc.runWith` and calls `Round.Summary.read` unchanged. A route that reads
nothing is answered before connecting at all, through `Db.runRecording`: the
calendar is `Motorsport.Calendar` rather than a count of the rows, so a
database that is down stops a round being opened and not the app being used.

An answer is tagged and compressed: a round is the same bytes until a run
loads it again, so a 200 carries a CRC32 `ETag` that a reload revalidates into
a 304, and a body goes out gzipped where the request accepts it — Le Mans's
laps are 24MB, and 3.4MB on the wire.

`Round` is one round on its way out of the tables, both halves of the trip:
`Round.Summary`, `Round.Index`, `Round.Laps` and `Round.Cars` take an `Entry`
and the `Db` effect and read it; `Round.Render` takes what they returned, is
pure, and turns it into the bytes that go out. None of the five knows whether a
file or a request is waiting at the other end. `Round.loaded` is what both
callers ask first, and it asks both tables: laps without cars is a round half
in the database, and answered off the laps alone it would be a race whose grid
was empty.

`Server.Api` decides nothing about a round, then, and renders none of one
either: it makes the same calls `Cli.Export` makes, so what is served and what
is written are the same bytes rather than two renderings that agree. An answer
carrying the summary alone stops at `Round.Render.renderSummary` rather than
reading a round's laps to throw them away, which is the one thing the two
callers do differently.

The root is the one thing that differs, and it is asserted rather than
assumed: `Server.TestApi` compares the served calendar against `Manifest`
rendered with `Cli.Export`'s root, because the dev server's fallback and a
bundle's own calendar are built on one path being the other with
`/static/wec` and `/api/wec` swapped, and neither would notice that failing.
`Manifest.toJson` is the rendering either root goes through, and it is the
only module of that name: `Cli.Export.urlRoot` and `Server.Api.urlRoot` are
what the two sides hand it.

## The `laps` and `cars` tables

The run loads every round it converts into two tables, dropped and rebuilt each
time as the JSON files are rewritten each time. `laps` is one lap of one car;
`cars` is one car of one round, holding the `class`, `car_group`, `team` and
`manufacturer` the feed repeats on every lap that car ran. The archive is what
says they can be: no `(season, round, car_number)` in its 130,017 laps is
described two ways, and the 579 cars they name are 4.7MB of the 26.7MB the one
flat table took. A lap carries the number and nothing else about its car, which
is also all the JSONL writes out, so the four columns are no longer read back
20,182 times a round to be dropped.

Where the file first mentioned a car is not in `cars`: it is `MIN(source_row)`
over the round's laps, which is what `Round.Summary` orders the grid by. What
`cars` holds is what the file said, and nothing counted off it.

What one row per car cannot hold is a file that describes one car two ways.
`Db.CarRow` keeps the first mention and the second reaches no column, so
`Db.CarRow.disagreements` is read before the insert and `Cli.Load` prints what
it found: said there or nowhere, since no query over the tables can find it
afterwards. It has not happened within a round in the archive; between rounds it
has, which is why `cars` is keyed by round and not by season -- 2026's Le Mans
file spells a manufacturer `Mercedes-AMG` where the season's other rounds spell
it `Mercedes`.

Everything else stays as it was. A column takes the type its Flix value already
has -- a `Duration` is the milliseconds it holds, `kph` and `topSpeed` stay the
text the feed gave -- so the load parses nothing the decoder did not. Le Mans's
mini-sectors are two JSON array columns rather than thirty more: only one round
in the archive has them. They hold the fifteen of `Motorsport.MiniSector.all()`
in track order, so a subscript is a place on the circuit and a null is a marker
the feed left blank. `json_each` is what a query reads one back with, one row
per marker, keyed from zero where `Motorsport.MiniSector.positionOf` counts from
one. That is the shape a query wants rather than the shape the JSON output has,
which is the whole reason they are not the object `Motorsport.Wec` writes.

Five readers of the tables. `Cli.Load.Validation` runs its five rules as
SQL over the round just loaded, leaving only the message formatting in Flix:
three are a comparison per row, and the two that walk a lap need the mini-sectors
in track order, which is what those columns are for. `Round.Summary`
reads the round's summary the same way, joining `cars` to the laps its grid order
and its first lap come from. `Round.Index` reads the two indices a
race is read at a moment through -- when the lap counter went up, and when each
of the twenty records changed hands -- which are a walk of every lap of the round
each: a `GROUP BY` for the first, and for the second one window over every
record's readings stacked into a single column. `Round.Laps` reads a whole round
back, `Db.LapRow.selection` and `toRawLap` being the reverse of the load, and
`Round.Cars` hands it the round's cars keyed by number -- read once each rather
than once a lap, which is the reading the split bought. A car with laps and no
row in `cars` is a round loaded by halves, and is said so rather than written out
as a car with no name. `Cli.Export` and `Server.Api` are both rendered from what
those readers return, so the files written and the round served are the same
bytes rather than two renderings that agree. The indices ride in the summary
rather than in a file of their own, so a round is still two URLs. Nothing renders
a round from the laps a CSV decoded to: `Cli.Load` sends the rows and stops
there.

What moved into SQL is the counting, not the deciding. `Motorsport.Metadata` and
`Motorsport.Track` still choose the grid's basis, break its ties, and divide the
lap; they take the readings those decisions are made from rather than the laps
they were counted out of, and neither imports `Motorsport.Wec` any more. The
counting is what SQL is better at and what cost the most: reading a round's cars
off its laps was `O(laps x cars)` in Flix, which for one Le Mans is 20,182 laps
against 62 cars, and `GROUP BY` is not.

`source_row` carries the position the file listed the lap in, which nothing else
in the tables recovers. It is what makes `laps` an image of the CSV rather than
a set of it, and every reading that would move off Flix needs it: the validator's
baseline is the file's first row, a car's drivers are in the order the file
first showed them, and so is the grid.

## `Db`, the effect

`Db` is an effect, not a module of functions, so that what a round would
send can be read back without a server: `Db.runRecording` keeps the statements
and answers a read with the error that nothing was sent, and `Db.Jdbc` is the
only file that imports `java.sql`. The effect names no table and no column, so
`Db`, `Db.Jdbc` and `Sql` are together a database and a query language and
nothing of this application; `Db.Laps`, `Db.Cars` and the two row types beside
them are the whole of what the application tells them about itself, which is
the same line Acadia draws between `Transaction`, `Rows` and a `Table`.

Nothing a statement sends is kept until `Db.commit`, and `Db.transact` is where
that is decided: it commits what its caller sent when the caller answers `Ok`
and rolls it back when it does not. `Cli.Load.runAll` is the one caller, so the
rebuild of both tables is a single transaction -- the two `DROP TABLE`s it opens
with land only if the run reaches its end, and a run that is killed partway leaves
the rounds it was rebuilding from. Measured on the archive: the same kill takes
it from fourteen rounds to three without that boundary, and leaves all fourteen
with it.

A round the database refuses is still counted and reported rather than taking
the run with it, so `Db.Jdbc`'s insert marks a savepoint and undoes its own
batches against that: the rows go out a thousand at a time, and a refusal
partway through has already sent some of them. A read commits nothing, and
closing a connection rolls back the transaction it opened.

The JDBC driver arrives through `[mvn-dependencies]` in `flix.toml`, resolved
into the gitignored `lib/` by `flix build` — CI needs nothing added for it.
`/update-deps` does not reach it, so it is the one dependency raised by hand,
against `org.xerial:sqlite-jdbc`'s `maven-metadata.xml`. Its version is the
SQLite it carries with a build number after it, so the pin says which engine
the queries run on: `3.53.4.0` is SQLite 3.53.4.

## `Db.Schema`, and the two declarations

`Db.Schema` is a table declared as its columns, and `Db.Laps` and `Db.Cars` are
each one such declaration: a column's name, the type it takes there, how a row
binds it and how it reads back are one record, and a table's `all`, its DDL,
its insert, its `values` and what a projection picks from are all views of it.
A `Column` carries the row type it binds as well as the type it reads back, so
a column of one table cannot be bound from a row of the other. The table's name
and its keys are declared there too, so the `CREATE TABLE` names no column the
declaration does not have, and a query reads `Db.Laps.table` rather than
spelling it.

What it does not reach is the ordering: `all` and the row's `selection` name the
same columns twice, which is the one pairing no compiler sees and
`Db.TestLapRow` and `Db.TestCarRow` assert. Flix cannot read a record's fields,
so `all` restates each name the declaration already has; only the `bind` beside
it is checked against the row type. A column drawn from the declaration is the
checked way to name one, and `Round.Index.lapCompletions` is the shape of that
-- but a query reading from a common table expression cannot use it, since the
expression's own `SELECT` is text and would not follow a rename.

## `Sql`, the query language

Every one of those readers builds its SELECT with `Sql`, the repository's own
query builder over this database and no particular one of its tables. A
`Sql.Sel` is one projection and the reading of it held in the same value, so
the clause is rendered from the readings rather than written beside them, and
a column is named once. What a query projects is a
`Sql.Project` -- a column, a reading, or a tuple of them -- which is why
`Sql.map` takes the columns and hands back what to read of them, as Acadia's
`map` does; the tuple that comes back becomes the caller's own type through
`Sql.reading`.

A row read as a record rather than a tuple is `Sql.record` extended a field at
a time with `Sql.field`, which is what `Db.LapRow.selection` is: each line
names a column and the field its cell lands in, so the two cannot be paired
wrongly, a field left out is not a `LapRow`, and a field named twice does not
typecheck. It is also the only form a row of more than eight has, an instance
head being written per arity. A curried constructor with the readings piped
into it in turn holds none of that, and the type checker cannot afford it
either: two dozen of those need a 2m stack where the record needs 512k.

A value a query compares against is bound rather than written into it: a
`Sql.Frag` is a piece of SQL and the values its `?` placeholders take, and
concatenating two pieces carries both, so a value cannot come to sit under
another piece's placeholder.

What a query asks of its rows is a `Sql.Expr[Bool]`, and `filter` takes it of
the columns the source declared rather than on its own: the predicate is a
function of what `map` would be handed, as Acadia's `filter` is of the row, so
a column of another source is not one this query can be scoped by.
`Db.Laps.scope` and `Db.Cars.scope` -- the pair naming a round, which every
reading of either table is scoped by -- take those columns, and a reader ANDs
its own onto them. Both tables carry `season` and `round` alike, so a scope
built from the wrong one would bind to whichever side of a join happened to
have them, and to the wrong side without a word where only one does; the two
records do not unify, so it does not compile. What a query builds itself
cannot reach a `WHERE` written into a common table expression, which is text
and takes the table's own columns. Both name the table they are of, and a
source that renames it says so itself: `Schema.scopeOf`, and what
`Round.Summary.carBuilds` hands its `c`. The type is what carries
nullability: `Sql.isNotNull` asks for an `Expr[Option[_]]`, so it can be
asked of `mini_sector_time_ms` and not of `lap_time_ms`, which is a reading the
column list already knows and no longer a thing to notice. A column a common
table expression made up is `Sql.column`, named rather than drawn, and its type
is the caller's word.

`Sql.unionAllTagged` stacks arms of a `UNION ALL` and labels each with a number
it picks, handing back a reading of that number as the thing the arm was about.
`Round.Index` is the caller: its twenty records are five arms of one reading
each and one arm of fifteen, and neither the arms nor the reading names a
number.

A query is built rather than written: `Sql.rows` names what follows `FROM`
(`Sql.access` where the caller says what columns it has, which is what
`Db.Laps.rows` hands a reader), `filter`, `groupBy`, `orderBy`, `limit` and
`using` add to it in any order, `map` says what to read of a row and
`selectAll` or `selectOne` runs it -- the shape Acadia's own queries have. The
clauses come out in the order SQL wants them rather than the order they were
asked for, a clause with nothing to say is left out, and `filter` asked twice
asks both. `Sql.toStatement` is pure, so what
a query is can be read back without a database.

So is what the load writes. `Sql.createTable` takes the columns and the keys
over them, `Sql.dropTableIfExists` the table, and `Sql.insertRows` the columns
and the rows -- and that last one hands back the statement and each row bound
in the order the statement names its columns, both read off the one list, so a
row cannot come to be bound in an order the statement does not name.
`Db.Schema` declares; `Sql` renders. Neither the DDL nor the insert is written
out in this repository any more.

What the query does not reach is its source. The source is text however it is
named, so the columns `Sql.access` carries are the caller's word that the text
has them, and a word about the wrong source fails where the query runs rather
than where it is built. `Db.Laps.rows` and `Db.Laps.rowsBeside` are the two
that cannot be wrong -- the table itself, and the table read alongside a
`json_each` of its own -- so a derived table calls `Sql.access` and names the
columns it selects, which is what `Round.Summary.driverNames` does with two of
them. A source that has none is `Sql.column` as before.

`Round.Summary.carBuilds` joins `cars` to two of those, and what its sides have
is said the same way: `Db.Schema.qualified` is a column of a table under the
name a source gives it, so `c.car_number` and `l1.elapsed_ms` are declared
columns read and compared as that source's, and the join's `ON` is a comparison
of two of them rather than text. What a `LEFT JOIN` does to the far side is
`Sql.orNull`, which reads a null cell as nothing rather than as a reading that
failed -- needed for a column the table has of every row, and not for one that
is null in its own right. The records naming each side are still written out,
Flix having no way to carry a table's columns through a rename. The window
clauses -- `ROW_NUMBER`, `LAG`, `FIRST_VALUE`, `WINDOW w AS` -- are text.

`Sql` is one file. A Flix module cannot span two of them, so splitting it
means submodules -- which its own types would not stand in the way of, a
module and a type being free to share a name. What does is that Flix has no
wildcard `use`: every call would grow a segment, or every caller a `use` line
per name, which is what Acadia's `import Rows exposing (..)` saves it from
paying for the same split.

## Testing

- **Where a test lives** — `test/Motorsport/` drives the domain's decisions
  given the readings they are made from (the grid's basis and its tie-breaks,
  how the lap divides) and needs no database; `test/Round/` and
  `test/Server/TestApi.flix` drive the reading, and need one. A subject with
  both has a file in each, named for the module it drives.
- **A clean build** — `flix build` and `flix test` are incremental, and CI is
  not: a compile that only fails from cold passes locally until `flix/build`
  is removed. `rm -rf flix/build` before believing a green run.
- **The type checker's stack** — it recurses once per expression, and the
  thread it runs on gets a smaller stack on Linux than on macOS, so a chain
  deep enough compiles here and overflows in CI. `flix` is a jar, so the check
  is to run it with the stack cut down: `java -Xss704k -jar <flix.jar> build`
  from `flix/`. 704k is where the tree as it stands builds and 672k where it
  does not, so a change that raises that number is the one to look at. What
  sets it is `Motorsport.Wec.decoder`, whose sixteen fields are a curried
  lambda, a record literal and a pipeline apiece: stubbing it out takes the
  build under 576k. Splitting `cars` out of `laps` did not move the number, a
  reading of many columns being the runner-up rather than the ceiling, and it
  is one of the reasons `Db.LapRow.selection` is a record extended a field at
  a time.
- **The database** — a test drives JDBC rather than a handler standing in for
  it, against the in-memory database `Round.TestSupport.url` names: a
  connection of its own per test, so what one loads is never the archive a
  working copy has. A test that reaches no database fails rather than skipping:
  the boundary is the thing it is there to check. What an in-memory database is
  not is a file, so `Db.TestJdbc` drives one of those too, under a temporary
  directory that does not exist yet — the directory `connect` has to make and
  the journal mode it sets are reached no other way, and two connections at
  once are not reached at all by a database each connection makes afresh.
