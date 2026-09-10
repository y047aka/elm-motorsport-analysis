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
`Db.Jdbc.runReading` and calls `Round.Summary.read` unchanged. A route that reads
nothing is answered before connecting at all, through `Db.runRecording`: the
calendar is `Motorsport.Calendar` rather than a count of the rows, so a
database that is down stops a round being opened and not the app being used.

An answer is tagged and compressed: a round is the same bytes until a run
loads it again, so a 200 carries a CRC32 `ETag` that a reload revalidates into
a 304, and a body goes out gzipped where the request accepts it — Le Mans's
laps are 25MB, and 3.4MB on the wire.

`Round` is one round on its way out of the tables, both halves of the trip:
`Round.Summary`, `Round.Index`, `Round.Timeline`, `Round.Laps` and `Round.Cars`
take an `Entry` and the `DbRead` effect and read it; `Round.Render` takes what
they returned, is pure, and turns it into the bytes that go out. None of the six
knows whether a file or a request is waiting at the other end. Three of them take a
`Round.Drivers` as well -- who sat in the seat a lap names -- because it is read
once for the round by whichever answer names a driver, rather than once by
each of them; the timeline names none and pays for neither it nor the summary. `Round.loaded` is what both ask first, and it asks `laps` and `cars`:
laps without cars is a round half in the database, and answered off the laps
alone it would be a race whose grid was empty.

`Server.Api` decides nothing about a round, then, and renders none of one
either: it makes the same calls `Cli.Export` makes, so what is served and what
is written are the same bytes rather than two renderings that agree. An answer
carrying one of the three reads only what that one is made of, rather than
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

## The tables

Seven of them, dropped and rebuilt each time as the JSON files are rewritten
each time. Four hold what a round did: `laps` is one lap of one car, `cars` is
one car of one round, `car_drivers` is one seat of one car, and
`timeline_events` is one thing that happened. Three hold what those name rather
than spell: `rounds` is the calendar written down, `drivers` the names the feed
repeats over every lap, and `entries` the cars a season was contested by.

`timeline_events` is the one that is not a reading of the file. Its rows are the
laps counted and then weighed -- which of a car's last crossings was the flag
and which a retirement is read against a time limit no row carries -- so the
load decides it once, writes down what it decided, and the export and the server
read it back rather than each deciding it again, which is why a timeline costs
neither the summary's readings nor the seats. The whole archive's 17,257 events
are 0.56MB against `laps`' 12.94MB.

The archive is what says the three can be split off: no car of a round in it is
described two ways, and no seat of one is named two ways. A lap carries its
car's number and the seat that ran it and nothing else about either, which is
also all the JSONL writes out.

An id means nothing outside the database a run put it in, and no reader computes
one. `Db.Drivers.add` gives a name its number -- carried between the rounds of a
run rather than read back between them, since a driver turns up in several --
and `Db.Rounds.scope` reads a round's id back inside the scope it builds, so a
database written under another calendar scopes to no rows rather than to another
round's.

A car number is an entry within its season and a different one across seasons --
number 12 was three teams' over the three the archive holds -- so `entries` is
keyed by the season and the number together, and the class, group, team and
manufacturer the feed repeats on every lap of every round are written there
once.

`cars` holds no fact the other tables do not. Its rows are `DISTINCT round_id,
car_number` over `laps`, by construction as much as in the archive, and the
`entry_id` on them follows from the round's season and the car's number -- which
the `car_number` beside it follows from in turn, so the table is not in BCNF and
knowingly: `Round.Summary` joins the round's cars to `MIN(source_row)` and to
lap 1 by that number, and both are readings of `laps`. It is a join the tables
keep rather than an entity they hold. `car_drivers` looks the same and is not:
its rows are the laps' distinct seats too, but the `driver_id` on them is
nowhere in `laps`.

What one row per car cannot hold is a file that describes one car two ways, and
one row per seat a file that names one seat two ways. Each keeps the first
mention and the second reaches no column, so `Db.CarRow.disagreements` and
`Db.CarDrivers.disagreements` are read before the insert and `Cli.Load` prints
what they found: said there or nowhere, since no query over the tables can find
it afterwards. Neither has happened within a round in the archive. A seat is the
one of the two that changes what the rows mean rather than how they read: the
second name's laps are credited to the first, in the grid and in the records
alike.

Between rounds it has, which is what holding the description once per season
finds: 2026's Le Mans file spells cars 61 and 79 `Mercedes-AMG` where that
season's other three rounds spell them `Mercedes`. `Db.Entries.add` keeps the
first round's description and reports the later round's, and the export carries
the season's spelling rather than each round's.

A column takes the type its Flix value already has -- a `Duration` is the
milliseconds it holds, `kph` and `topSpeed` stay the text the feed gave -- so
the load parses nothing the decoder did not. Two say more than the type:
`flag_at_fl` is checked against `Motorsport.Wec.flags` rather than against a
list written beside it, and `car_group` is nullable because the feed spells a
car with no sub-class as one whose group is empty, an absence rather than a
value. `hour_offset_ms` is the one no row binds: `(hour - elapsed) mod 24h` is a
column the database makes, which is what `Db.Schema.Computed` is and why it is
not a `Column` -- there is no row to bind it from, so it cannot reach a table's
`all`, the ordering the insert follows. `VIRTUAL`, so the rows are no larger for
it.

Where a table's rows are stored is declared beside its keys, and the key is what
decides it. A table keyed by more than a number takes `Sql.Storage.WithoutRowid`
and is that key's tree outright. One keyed by a number leaves SQLite's own
arrangement alone and declares the column with `Db.Schema.identity`, which
spells it `integer` -- the one spelling SQLite reads as an alias for the row's
own id, and so the one that has it build no second tree over the first. Either
way there is one tree and not two, which is a thing the DDL does not state:
`Db.TestJdbc` asks a database that took it.

`source_row` carries the position the file listed the lap in, which nothing else
in the tables recovers. It is what makes `laps` an image of the CSV rather than
a set of it, and every reading that would move off Flix needs it: the
validator's baseline is the file's first row, a car's drivers are in the order
the file first showed them, and so is the grid. Nothing is keyed by it: the
reader numbers it one to n over the round's laps, so no two of them can share a
place, and a unique index asserting that cost 1.88MB and no time.

`car_drivers` carries the one index the tables declare, over `driver_id`. Its
key leads with the round, so nothing in it reaches the seats one driver sat in,
which is the reading `drivers` was separated out for and a scan of every lap in
the archive without it.

No foreign key is declared and `PRAGMA foreign_keys` is left off. A declaration
would add one check the code does not already make: every `round_id` is
`Db.Rounds.idIn`'s and a car or a seat the run did not number fails the same
way, both by name rather than by constraint, but nothing beyond the load's own
numbering says a `driver_id` has a row. Turning them on costs two rewrites,
neither of them the declarations: with the pragma on, `DROP TABLE` runs an
implicit `DELETE FROM`, so the drops have to run children first while the
creates run parents first, and the pragma is a silent no-op inside a
transaction, so it belongs in `Db.Jdbc.connect` beside the journal mode. The one
fixture in the way is `Round.TestSupport.onLapsAlone` -- laps with no cars,
which is what `Round.loaded` asks about and what a `laps` to `cars` key would
make unbuildable.

Le Mans's mini-sectors are two JSON array columns rather than thirty more: only
one round in the archive has them. They hold the fifteen of
`Motorsport.MiniSector.all()` in track order, so a subscript is a place on the
circuit and a null is a marker the feed left blank. `json_each` is what a query
reads one back with, one row per marker, keyed from zero where
`Motorsport.MiniSector.positionOf` counts from one. That is the shape a query
wants rather than the shape the JSON output has, which is the whole reason they
are not the object `Motorsport.Wec` writes.

What moved into SQL is the counting, not the deciding. `Motorsport.Metadata` and
`Motorsport.Track` still choose the grid's basis, break its ties, and divide the
lap; they take the readings those decisions are made from rather than the laps
they were counted out of, and neither imports `Motorsport.Wec` any more.
Counting is what a `GROUP BY` is better at than a fold over the laps, and it is
what cost the most.

`Cli.Load.Validation` runs its five rules as SQL
over the round just loaded, leaving only the message formatting in Flix: three
are a comparison per row, and the two that walk a lap need the mini-sectors in
track order, which is what those columns are for. `Round.Index` reads the two
indices a race is read at a moment through -- when the lap counter went up, and
when each of the twenty records changed hands -- which are a walk of every lap
of the round each: a `GROUP BY` for the first, and for the second one window
over every record's readings stacked into a single column. They are twenty
readings and a few hundred rows, so they ride in the summary rather than in a
file of their own.

`Round.Timeline` is the third such walk and does not: it is thousands of records
rather than hundreds -- Le Mans is 3983 of them against the summary's 100KB --
so it is written a line at a time as the laps are, and a round is three files
and three URLs. It is also the only one of the walks a reader does not make:
`Round.Timeline.fromLaps` is the load's, and `Round.Timeline.read` is the
round's own rows in the order the load numbered them.

Each car's first and last crossing is one `GROUP BY`, the stops are the laps
carrying a pit time, and the lead is `ROW_NUMBER` picking each lap's first
crossing with `LAG` asking who held the one before -- two queries rather than
one, since SQLite settles a `WHERE` before either window. What is left in Flix
is the deciding: `Motorsport.Timeline` weighs each car's last crossing against
the time limit, which is `Metadata`'s estimate and the one reading here the laps
do not carry, so `Round.Summary.particulars` is read first and hands it over --
the whole of what the load wants a summary for. It also fixes the order events
sharing an instant come back in -- `List.sortBy` is not stable -- which is why
the gathering order rides in the sort key and lands in `seq`. That order is
there so a round is written the same way twice and nothing more: two events at
one instant have none of their own, and what a car is said to be where a stop
ends as the flag falls is `Motorsport.Status.stronger`'s on the Elm side, off
the pair rather than off the order they arrive in.

`Motorsport.Timeline.parts` is where the line written out and the row meet: what
an event is called and which of the three optional fields it carries is settled
once, so the JSON, the column's `check` and the reading back cannot disagree
about it. A row that spells no event -- a stop with no lap, a name no event
answers to -- is `Db.Error.Incomplete` rather than an event with either made up.

`Round.Laps` takes one window function beside the reading for where the car
stood in the field as it crossed the line -- a reading of the round rather than
of any row of it, so it rides beside the lap rather than in it. `Round.Cars` and
`Round.Drivers` hand the others the round's cars keyed by number and who sat in
each seat -- read once for the round rather than once a lap, and the two that
say when a round is loaded by halves: a car with laps and no row in `cars`, or a
lap from a seat with none in `car_drivers`, is said so rather than written out
as a car with no name.

## Why SQLite

The database is not a system of record. It is a cache derived from the CSV, and
dropping every table on each run is the design saying so, which is what takes
durability, replication, migration and availability out of the question
entirely. What is left is one writer, no point lookups, no concurrent writes,
no transactions between users, and reads that are whole-round scans, `GROUP
BY`, window functions and `json_each`. SQLite answers all of it from one file
in the working copy.

DuckDB is the near miss worth recording, since its column store and native
`LIST` types fit the mini-sectors better than JSON text does: its files lock
per process, so nothing reads one while a run writes it, and
`.#serve-api` staying up across a `.#cli-run` is exactly that. A document store
is what the export already is -- one round, one file -- and moving the tables
there would take the window functions the indices are counted with. NewSQL
solves distributed writes and horizontal scale, and there is one writer and one
region here.

Nothing about the scale argues otherwise later, either: the whole of the WEC,
twenty seasons of it, is on the order of 1.5 million laps and 150MB in these
tables, and adding other series keeps it in the low gigabytes.

## `SqlRead`, `SqlWrite` and `DbErr`

Reaching a database is an effect rather than a module of functions, so that
what a round would send can be read back without a server: `Db.runRecording`
keeps the statements and answers a read with the error that nothing was sent,
`Db.runFailing` answers every statement with one error the caller chose, and
`Db.Jdbc` is the only file that imports `java.sql`. No effect here names a
table or a column, so they, `Db.Jdbc` and `Sql` are together a database and a
query language and nothing of this application; the `Db` table modules and the
row types beside them are the whole of what the application tells them about
itself, which is the same line Acadia draws between `Transaction`, `Rows` and a
`Table`.

Reading and writing are two effects because the sides of this repository are
two: `Round`'s readers, `Server.Api` and `Cli.Export` would not compile with a
statement that changes the database in them, and the table modules and
`Cli.Load.load` are the other half. The handlers are split the same way, so
what the type says of the server the connection says too: `Db.Jdbc.runReading`
installs the read alone, and a write reaches no handler through it.

`DbErr` is the third, and it is what a reader does not carry a `Result` for.
Its one operation does not return, so `Round.Summary.read` answers with a
`Metadata` rather than with whether it could read one, and the failure travels
by itself to the boundary that asked -- `Db.runWithError`, which is where a
value comes back. Three of those: a round of the export, a request, and the
run's own transaction. Everything between them is written as though the
database always answers.

What a signature says is the alias rather than the effect: `\ DbRead` is
`{SqlRead, DbErr}`, `\ DbWrite` is `{SqlWrite, DbErr}`, and `\ Db` is all
three. Flix has no subeffecting here -- a `\ DbRead` function is not a `\ Db`
one -- so a caller taking one as an argument is written for the half it uses,
which is what `Main.onRoot` is polymorphic over and what
`Round.TestSupport.onRound` takes.

The two statement effects answer with a `Result` even so, and that is not a
choice: a Flix handler body is evaluated outside the `run` it belongs to, so a
failure raised inside `Db.Jdbc`'s handler would pass every handler its caller
had installed. `Db.orRaise` is where the value becomes a `DbErr`, in the
caller's own context. sqlfx found the same thing and answers it the same way.

So nothing outside `Db` calls an operation: `Db.fetch`, `Db.execute` and
`Db.insertMany` are the same statements with that step already taken, and they
are what `Sql` and `Db.Schema` reach. `Db.Jdbc.withConnection` is the other
one -- a database opened, worked in, and closed however that went, which is
what a run, a test and the server each did for themselves before.

What a failure is is a `Db.Error` rather than a sentence, and which of the six
says where the fix is: `Unreachable` is no database reached at all, `Refused` is
what the driver said no to in its own words, `Busy` is the one refusal that may
go through next time -- a lock SQLite waited out rather than got, which
`Db.Jdbc.classify` reads off the driver's code and is tested without a
database -- `Unread` is a cell the reading could not read, `NoRow` is a query
that had to answer with one and did not, and `Incomplete` is rows that came back
whole and do not describe a round. The sentence is `ToString`'s, so the wording is in one place and the kind is what a
caller reads.

`Server.Api` is the one that reads it. `Unreachable` and `Busy` are answered
503 and everything else 500, which is the difference between a round that
cannot be served now and one that cannot be served. What the answer carries is
that sentence and not the database's: a failure names tables and files in its
own words, so those ride in the response's `cause`, which `Server.send` logs
and does not send.

Nothing a statement sends is kept until a commit, and `Db.transact` is the only
sender of one: it commits what its caller sent when the caller returns, and
rolls a `DbErr` back before raising it again, the rollback being what it did
about the failure rather than what it answers. `Cli.Load.runAll` is the one
caller, so the rebuild of every table is a single transaction -- the
`DROP TABLE`s it opens with land only if the run reaches its end, and a run
killed partway leaves the rounds it was rebuilding from rather than three of
them.

A round the database refuses is still counted and reported rather than taking
the run with it, and `Db.atomically` is the boundary that makes it so: it is
`transact` of a part of one, marking a savepoint of SQLite's own so what a
round sent is undone together and what the run sent before it is still to be
committed. `Cli.Load` marks one per round, which is also what lets the
numbering follow the rows -- a round that failed frees the names it took, and
advancing past it would leave a name numbered and unwritten for every later
round to reference. `Db.Jdbc`'s insert marks one of the driver's inside that,
and that one is the batch's alone: the rows go out a thousand at a time, and a
refusal partway through has already sent some of them. A read commits nothing,
and closing a connection rolls back the transaction it opened.

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

What it does not reach is the ordering: `all` and `selection` name the same
columns twice, which is the one pairing no compiler sees and `Db.TestLapRow`
and `Db.TestCarRow` assert. Both are declared here rather than beside the row
they build, so the two orderings are read in one file; `Db.LapRow` and
`Db.CarRow` are the feed's side of the trip and name neither `Db` nor `Sql`.
Flix cannot read a record's fields, so `all` restates each name the
declaration already has; only the `bind` beside it is checked against the row
type. A column drawn from the declaration is the checked way to name one, and
`Round.Index.lapCompletions` is the shape of that
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
a time with `Sql.field`, which is what `Db.Laps.selection` is: each line
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
The round is what every reading of a table keyed by one is scoped by, and it is
applied where the rows come from rather than by the reader: `Db.Laps.rows` and
`Db.Cars.rows` take the round and hand back rows already filtered by it, so rows
of a table at large are not something those modules hand out and a reader cannot
forget the scope. A reader ANDs its own onto them. Both carry a `round_id`, so a
scope built from the wrong one would bind to whichever side of a join happened
to have one; the records do not unify, so it does not compile. What a query builds itself cannot reach a
`WHERE` written into a common table expression, which is text and takes the
table's own columns: `Db.Laps.inRound` is the same predicate had on its own,
for the queries in `Round.Index`, `Round.Summary` and `Cli.Load.Validation`
that write one. Each names the table it is of, and a source that renames it
says so itself: `Db.Rounds.scope` takes the column under that name, which is
what `Round.Summary.carBuilds` hands its `c`. The type is what carries
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
row cannot come to be bound in an order the statement does not name. A
`Sql.Key` is declared columns rather than their names, as Acadia's
`primary = .id` is the field rather than a string, so a key over a column the
table has not declared does not typecheck. What it does not reach is `all`:
that ordering is restated by hand, and `Db.TestLapRow` is what says the key's
columns are in it. `Db.Schema` declares; `Sql` renders. Neither the DDL nor
the insert is written out in this repository any more.

What the query does not reach is its source. The source is text however it is
named, so the columns `Sql.access` carries are the caller's word that the text
has them, and a word about the wrong source fails where the query runs rather
than where it is built. `Db.Laps.rows` and `Db.Laps.rowsBeside` are the two
that cannot be wrong -- the round's rows of the table itself, and of the table
read alongside a `json_each` of its own -- so a derived table calls `Sql.access` and names the
columns it selects, which is what `Round.Summary.driverNames` does with two of
them. A source that has none is `Sql.column` as before.

`Round.Summary.carBuilds` joins `cars` to `entries` and to two of those, and
what its sides have is said the same way: `Db.Schema.qualified` is a column of a table under the
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
  build under 576k. A reading of many columns is the runner-up rather than the
  ceiling, which is one of the reasons `Db.Laps.selection` is a record extended
  a field at a time.
- **The database** — a test drives JDBC rather than a handler standing in for
  it, against the in-memory database `Round.TestSupport.url` names: a
  connection of its own per test, so what one loads is never the archive a
  working copy has. A test that reaches no database fails rather than skipping:
  the boundary is the thing it is there to check. What an in-memory database is
  not is a file, so `Db.TestJdbc` drives one of those too, under a temporary
  directory that does not exist yet — the directory `connect` has to make and
  the journal mode it sets are reached no other way, and two connections at
  once are not reached at all by a database each connection makes afresh.

  What no database is asked for is what a caller does about a failure, since
  that is decided off the kind rather than off any row: `Db.runFailing` is a
  database that answers with the one it was given, and `Server.TestApi` is
  where a `Busy` becomes a 503 and a `Refused` a 500 with the driver's words
  kept out of the body. The two halves of that are otherwise only met apart --
  `Db.Jdbc.classify` reads the code, and a round read over a real database
  never fails.

## What sqlfx does and this does not

[sqlfx](https://github.com/ababup1192/sqlfx) is a Flix database library for
PostgreSQL, written over the same months as this and arriving at the same base:
`SqlRead` and `SqlWrite` split apart, `DbRead` and `DbWrite` as the aliases
over them, a failure carried as an effect and turned into a value once at a
boundary, statements answering with a `Result` for the reason above, and
handlers swapped to run the same code without a database. Where it goes the
other way is the SQL itself, which it writes rather than builds: raw statements
in `.q` files, checked against a migration's DDL and turned into typed
functions by a generator. Its author's account of it is
[the article](https://zenn.dev/ababup1192/articles/0c29f21fe1ab8f).

Three things it has that are not here, none of them adopted, none of them
resting on which way the SQL is written:

- **A marker on raw SQL.** `Sql.raw`, `Sql.column` and a reading of a written
  expression are the holes in what the builder checks, and a function reaching
  through one says nothing about it -- `Round.Index` is written almost entirely
  through them. sqlfx gives a raw statement an effect of its own, `RawSql`,
  which travels to whoever allows it, so how far unchecked SQL reaches is a
  question the type checker answers rather than a grep.
- **A read handler answering with rows.** `Db.runRecording` answers a read with
  the error that nothing was sent, so a reading is driven either over a real
  database or, as `Sql.TestSel` does, by handing a row to the reading alone. A
  handler taking the rows to answer with would put a query and its reading under
  one test without a database.
- **A refusal that says whether to send it again.** `Db.Error.Busy` is that
  refusal and nothing re-sends what it refused: the server answers 503 and the
  caller is told. sqlfx keeps its transient failures in an effect of their own
  and retries a transaction against it. One run writing to one file makes the
  case thin here -- but the kind is already read for the status code, and a
  retry would be read off the same place.

The rest of it is PostgreSQL's, and does not carry: sqlstate read down to the
constraint name, a generator turning a DDL's named constraints into an enum a
`match` must cover, a connection pool, forward-only migrations. A single file
rebuilt from CSV each run has no use for the last two, and SQLite's driver does
not answer the first.
