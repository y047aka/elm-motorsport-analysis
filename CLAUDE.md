# CLAUDE.md

Motorsport race analysis and visualization app. CSV telemetry → CLI →
SQLite → HTTP or a JSON export → Elm visualization.

- **`/app`** — Elm SPA, bundled by Vite (Tailwind CSS 4 + shadcn/ui). The only npm
  project: it owns `package.json` and `pnpm-lock.yaml`, so pnpm runs as
  `pnpm -C app`.
- **`/package`** — reusable Elm library (motorsport domain models), reached
  through `elm.json`.
- **`/flix`** — written in Flix, and two things rather than one: the CLI that
  moves CSV through SQLite into JSON/JSONL, and the server that answers
  `/api` out of the same rows.

There is no manifest at the repository root; the flake is what ties the three
together.

## Commands

All commands run through the Nix flake; `nix flake show` lists everything.

| Command | Purpose |
| --- | --- |
| `nix run .#dev` | Vite dev server (localhost:1234) |
| `nix run .#build` | Production build |
| `nix run .#test` | elm-verify-examples + elm-test |
| `nix run .#typecheck` | `tsc --noEmit` over the app's TypeScript |
| `nix run .#test-vrt` | Playwright VRT |
| `nix run .#update-snapshots-vrt` | Update VRT snapshots |
| `nix run .#benchmark` | Serve `/package/benchmark` (elm reactor) |
| `nix run .#review-app` / `.#review-package` | elm-review |
| `nix run .#format` | elm-format |
| `nix run .#flix-build` / `.#flix-test` | Build / test `/flix`, both the CLI and the server |
| `nix run .#cli-run` | CSV→SQLite, and the kept round out to JSON/JSONL |
| `nix run .#cli-load` / `.#cli-export` | Either stage of that run on its own |
| `nix run .#serve-api` | Serve the loaded rounds over HTTP (`/api`, port 8080) |
| `nix run .#tauri-dev` / `.#tauri-build` | Tauri v2 native app (`app/src-tauri`) |
| `nix run .#deps-audit` | Dependency audit helper for `/update-deps` |

Prefer these over invoking `pnpm` / `cargo` / `flix` directly — the flake pins
the toolchain and sets the working directory. `/flix` is reached by three
prefixes, and which one says what is being run rather than what is being built:
`flix-*` builds and tests the project, `cli-*` moves the data through it, and
`serve-api` is the server. All of them come out of the same jar.

`.#cli-run` takes the directory holding the season directories and converts
every round `Motorsport.Calendar` lists, in two stages: the CSV goes into the
`laps` table, and a round's summary `.json`, its laps `.jsonl` one lap per line,
and `index.json` beside them are written back out of the rows. **A new round is
added to `Motorsport.Calendar` first** — the run converts nothing the calendar
does not list, reports any CSV no round names, and fails any round whose CSV is
missing.

Every round is loaded and one is written. `--export-only <season>/<id>` narrows
the writing stage alone, the flake passes `2025/le_mans_24h`, and a name no
round on the calendar answers to fails the run before anything is written. The
rows are where a round is read from; the files are one round kept so that what
the renderers produce can be read without a server.

`.#cli-load` and `.#cli-export` are those two stages singly. The stage that
writes reads none of the CSV, so the files are an image of the rows and of
nothing else: a row corrected in SQL is exported, and re-exporting after a
change to a renderer costs no decoding. **A round no run has loaded fails the
export** rather than being written out as a race that never ran — the rows read
back as one, which is the one thing they cannot say for themselves — and the
files it would have replaced are left alone. `/api` answers such a round with a
404 for the same reason, off the same reading: `Round.Laps.loaded` is where the
two of them ask.

Both stages compute in SQLite, and so does the server, so all three need one:
`--database <jdbc url>` names it, `DATABASE_URL` says the same to every run made
in a shell, and the commands name `flix/.db/motorsport.sqlite` when neither
does. One that reaches none does nothing rather than opening an empty database
of its own. The file is in the working copy rather than under /tmp, so what a
run left there is still there to be queried. The integrity checks are read back
out of the rows a round was just loaded into, and so is everything the export
writes and `.#serve-api` answers with.

`/api` is how the app reads a round, and the export is a check on the two
renderers rather than a second copy of the archive. The calendar is written
either way and lists every round there is, so `dist/api/wec/index.json` — the
copy the build writes, and the one URL the app asks for before it knows
anything — is reached only by a bundle with nothing listening on `/api`. Such a
bundle opens the one round whose files are beside it and 404s on the rest,
which is what the Tauri build now packages. A bundle behind a server never
reaches that copy: the calendar it gets names `/api/wec` and every round
opens.

Passing the flag goes through `nix run .#cli-run -- --database ...`, since the
flake forwards what follows.

`.#serve-api` answers `/api` out of the rows a run loaded: `/api/health`,
`/api/wec/index.json`, and a round's `/api/wec/<season>/<id>.json` and
`_laps.jsonl`. The Vite dev server forwards `/api` to port 8080, and answers it
from `static/` when nothing is listening.

Its operating form is the jar, since `flix run` takes the JVM down with `main`
and the server's does not return. `flix build-jar` leaves the Maven
dependencies out of what it writes, so the JDBC driver is named on the class
path beside the jar rather than bundled in it.

`/update-deps [npm|elm|rust|nix]` (Claude skill) audits and updates dependencies.

## Architecture

**`/app/src/`** — hand-written multi-page SPA on `Browser.application`
(framework-less; no elm-pages). `index.ts` boots `Elm.Main.init`; data is
fetched at runtime via `Http`.

- `Main.elm` — top-level Model/Msg, URL handling, page dispatch
- `Route.elm` — `Url.Parser` routes: `/`, `/debug`, `/wec/:season/:event`
- `Shared.elm` — app-wide state (race control, view model) + data loading
- `Effect.elm` — elm-spa-style effects (`sendCmd`, `sendSharedMsg`, `pushRoute`, ...)
- `Page/` — one module per page, plain TEA
- `Css/` (Color, Palette, Typography), `Data/` (feed decoding), `UI/` (Table,
  and `Shadcn/` for the wrappers)

`Data/Wec/Calendar.elm` decodes `index.json`, fetched once by `Shared` from
`/api/wec/index.json`. It is the app's only source for which rounds exist, what
they are called and where their files are — nothing app-side builds those paths,
and a round it does not list cannot be opened. That one URL is the whole of
what the app knows about where its data comes from: the calendar names each
round's summary and laps, and nothing else does.

`Data/Series.elm` is the remains of the compile-time calendar it replaced: car
images, which nothing imports yet.

`Data/Wec/Manufacturer.elm` decodes `/static/manufacturers.json` the same way,
also once, and a round waits on it as it waits on the calendar. That file is
written by hand and no compiler reads it, so a mistake in it shows as cars drawn
by their numbers rather than as a build that fails. Unlike an unlisted round, an
unnamed manufacturer stops nothing: the car keeps the name the feed gave it and
takes a colour from its number.

### The server

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

`Round` is one round on its way out of the table, both halves of the trip:
`Round.Summary`, `Round.Index` and `Round.Laps` take an `Entry` and the `Db`
effect and read it; `Round.Render` takes what they returned, is pure, and turns
it into the bytes that go out. None of the four knows whether a file or a
request is waiting at the other end.

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

### The shadcn components

`app/src/shadcn/ui/` is vendored from shadcn's **`base-nova`** registry — Base
UI, not Radix. Each `app/src/shadcn/<name>-element.ts` puts one of them behind
a custom element, `index.ts` registers them all, and
`app/src/UI/Shadcn/<Name>.elm` is the Elm side. The Elm wrappers hold no
Tailwind classes; the class strings are the vendored file's. `UI.Table` is what
sits beside them: Elm that writes its own Tailwind and answers to no vendored
file.

`components.json` configures the CLI, so `shadcn add <name>` writes these files
and `shadcn add <name> --diff` reports how far one has drifted from upstream.
That holds only while the `@/*` alias resolves the same way in `tsconfig.json`
and in `vite.config.ts` — the CLI writes `@/shadcn/...` imports, and neither
file alone makes them build.

Anything this app adds to a vendored component carries a
`Not in upstream base-nova:` comment. `--diff` should report those lines and
nothing else: a line it reports without one is drift to fold back in, since
`add` overwrites the file. A single class the registry has no variant for does
not need to be added there at all — `cn` puts it last, so the element can pass
it and win, which is how a circular button gets `rounded-full`.

Every prop is set as a JS property, so what crosses the boundary is JSON and
Elm holds the state. Four things that boundary will not carry, all found by
running it rather than by building it:

- A property that arrives as `undefined` reads to React as "leave this
  uncontrolled", and the component then keeps a value beside the one Elm
  holds. Elm clears the value, the component goes on showing the old one, and
  nothing fails — so an element always passes a value, never a hole.
- React's synthetic events never reach a custom element's slotted children, so
  a component Elm passes children to cannot report its own clicks. No element
  takes children at all: the ones that mount nothing render their own node,
  and children Elm rendered would land beside it rather than inside it.
- A `Html.Keyed` reorder removes and re-inserts a node within one task, so a
  teardown queued by `disconnectedCallback` has to be cancelled when the node
  comes back, or every reorder destroys a React root. `ReactElement` guards
  that with its `leaving` flag, and nothing exercises the guard: no element of
  this kind sits in a keyed list today.
- A directory whose name differs from an Elm one only in case is folded into
  it on macOS and only fails on Linux CI. The React sources are laid out as
  the registry expects, so `src/shadcn/` and `src/shadcn/ui/` are both taken:
  the Elm side is `UI.Shadcn.*`, and no top-level Elm module may be named
  `Shadcn` or `Ui`.

Two of the elements mount React: the slider and the toggle-group, which are
the two that borrow behaviour — a drag, and a row that answers the arrow keys.
The rest are class strings, and the registry hands those out without React:
`badgeVariants`, `buttonVariants` and `buttonGroupVariants` are all exported,
so the badge, button and button-group elements build their own DOM from them
with nothing vendored changed. A class the registry has no variant for goes on
through `cn`, which is also what drops a base class a variant contradicts.

`card-elements.ts` has a second reason to mount nothing. Card's classes read
the tree its content sits in — `has-data-[slot=card-footer]`,
`has-[>img:first-child]` — and content projected through a `<slot>` is not in
the shadow root's tree, so the element carries the vendored class string and
Elm fills it directly. Nothing may pass one of those a `class`: the element
owns that attribute, and layout belongs on a wrapper around it.

What one of these costs, measured: mounting sixty-two of them takes ~26ms
against ~2ms for the same number of plain Elm nodes, about ten times, paid once
when the list appears. A reorder costs nothing. Ten times a node it only lends
class strings to is the reason nothing mounts React for class strings alone.

An unrelated re-render costs nothing only where the property is a primitive.
Elm compares a property against the last one by reference, so a re-encoded list
or record arrives as a write however little it has changed, and a view that
runs every animation frame then renders React every animation frame. Measured
on the event page: the two elements taking an `items` array rendered on 181 of
181 frames of playback, showing nothing new. `changed` in `react-element.ts` is
what an object-valued setter compares with, and both are back to zero.

**`/package/src/Motorsport/`** — domain models (`Car`, `Driver`, `Lap`, `Gap`),
`Race/` for the loaded race, its indices, and readings of it at a moment
(`Snapshot`, `LapHistory`), `Widget/` and `Chart/` for rendering (Leaderboard,
GapChart, BoxPlot).

`Wec/` holds the WEC-specific knowledge: the class grid and the eras it has
passed through (`Class`, `Era`), and Le Mans's mini-sectors
(`Circuit/LeMans`). Decoding the timing feed stays app-side in `Data.Wec` /
`Data.Wec.Laps` — the shape of one publisher's files, not of the domain.
`Data.Wec.Manufacturer` is app-side for the same reason: which manufacturers
there are, and how each is coloured and badged, is one series' entry list and
this application's assets. It holds none of them itself — it decodes the table
that does.

The names are sorted; the dependencies are not. The core imports out of `Wec/`
in three places: `Car.Metadata` holds a `Class`, `Lap.miniSectors` is fixed to
`Circuit/LeMans`'s type, and `Widget.Leaderboard` carries `*_Wec` and
`*_LeMans24h` columns beside the generic ones. Reversing that arrow is its own
change.

There is no view-model layer between the two. `Race.Snapshot` is the whole
per-frame derivation — sampling the cars at the clock, ordering the field,
measuring the gaps, rating the times against the records as they stood — and
views read a `CarAt` straight off it. Colours and geometry are the view's own: a
widget that wants a class's colour calls `Class.toColor` itself, and a
`Manufacturer` is read for the colour and logo it was built with. `Snapshot.at`
runs once per frame and every view shares that result, which is the only reason
the type exists; a record per car on top of it cost under 2% of the frame
(`benchmark/PerFrameBenchmark.elm`), so nothing sits above it.

Modules serving both sides sit directly under `Motorsport/` rather than in a
subdirectory — `BestTimes` is held by `Race` and read back by `Race.Snapshot`,
and `Lap.Performance` rates a lap for either side, so neither owns them.
Neither walks a lap of the race. Which lap took which record is counted in
`Round.Index` and arrives with the round's summary, as `Race.lapCompletions`
does, so `Race.fromCars` is given a `Race.Index` rather than building one.

### The `laps` table

The run loads every round it converts into one flat `laps` table, dropped and
rebuilt each time as the JSON files are rewritten each time. Flat is
a decision, not an omission: `class`, `team` and `manufacturer` never vary within
a `(season, round, car_number)` across the whole archive, so the 579 entries they
describe can be read back as a `VIEW` over the table, and normalising them out
would buy about 16% of its size in exchange for resolving ids on the way in.
A column takes the type its Flix value already has — a `Duration` is the
milliseconds it holds, `kph` and `topSpeed` stay the text the feed gave — so the
load parses nothing the decoder did not. Le Mans's mini-sectors are two JSON
array columns rather than thirty more: only one round in the archive has them.
They hold the fifteen of `Motorsport.MiniSector.all()` in track order, so a
subscript is a place on the circuit and a null is a marker the feed left blank.
`json_each` is what a query reads one back with, one row per marker, keyed from
zero where `Motorsport.MiniSector.positionOf` counts from one. That is the shape
a query wants rather than the shape the JSON output has, which is the whole
reason they are not the object `Motorsport.Wec` writes.

Four readers of the table. `Cli.Load.Validation` runs its five rules as
SQL over the round just loaded, leaving only the message formatting in Flix:
three are a comparison per row, and the two that walk a lap need the mini-sectors
in track order, which is what those columns are for. `Round.Summary`
reads the round's summary the same way. `Round.Index` reads the two indices a
race is read at a moment through — when the lap counter went up, and when each
of the twenty records changed hands — which are a walk of every lap of the round
each: a `GROUP BY` for the first, and for the second one window over every
record's readings stacked into a single column. `Round.Laps` reads a whole round back,
`Db.LapRow.fromRow` and `toRawLap` being the reverse of the load;
`Cli.Export` and `Server.Api` are both rendered from what it,
`Round.Summary` and `Round.Index` return, so the files written and the round
served are the same bytes rather than two renderings that agree. The indices
ride in the summary rather than in a file of their own, so a round is still two
URLs. Nothing renders a round from the
laps a CSV decoded to: `Cli.Load` sends the rows and stops there.

What moved into SQL is the counting, not the deciding. `Motorsport.Metadata` and
`Motorsport.Track` still choose the grid's basis, break its ties, and divide the
lap; they take the readings those decisions are made from rather than the laps
they were counted out of, and neither imports `Motorsport.Wec` any more. The
counting is what SQL is better at and what cost the most: reading a round's cars
off its laps was `O(laps x cars)` in Flix, which for one Le Mans is 20,182 laps
against 62 cars, and `GROUP BY` is not.

`source_row` carries the position the file listed the lap in, which nothing else
in the table recovers. It is what makes the table an image of the CSV rather than
a set of it, and every reading that would move off Flix needs it: the validator's
baseline is the file's first row, and a car's drivers are in the order the file
first showed them.

`Db` is an effect, not a module of functions, so that what a round would
send can be read back without a server: `Db.runRecording` keeps the statements
and answers a read with the error that nothing was sent, and `Db.Jdbc` is the
only file that imports `java.sql`. `Db.Schema.columns` and `Db.LapRow.values`
are two lists no compiler sees together, which is what `Db.TestSchema` is for.

The JDBC driver arrives through `[mvn-dependencies]` in `flix.toml`, resolved
into the gitignored `lib/` by `flix build` — CI needs nothing added for it.
`/update-deps` does not reach it, so it is the one dependency raised by hand,
against `org.xerial:sqlite-jdbc`'s `maven-metadata.xml`. Its version is the
SQLite it carries with a build number after it, so the pin says which engine
the queries run on: `3.53.4.0` is SQLite 3.53.4.

### Reading the race at a moment

Nothing in a `Race` moves; a clock is applied to it to get what is true then.
Three spellings, used consistently:

- **`at`** — the module's own subject at that moment: `Gap.at`, `BestTimes.at`,
  `Snapshot.at`, `LapHistory.at`.
- **`xAt`** — one named aspect of *someone else's* subject: `Race.statusAt`,
  `Race.lapCountAt`, `Lap.findLastLapAt`.
- **`Snapshot`** — the type `at` returns when the whole subject is frozen: every
  value in it read at the same instant, and that instant baked in.

`BestTimes.Snapshot` and `Race.Snapshot` are the same idea applied twice — the
records at a moment, and the field at a moment — always written qualified, which
keeps them apart at the call site. A module handing out only the frozen form may
name it for what it holds instead (`LapHistory`); one holding both names them for
the difference (`BestTimes.Changes` spans the race, `BestTimes.Snapshot` is one
moment of it).

## Comments and documentation

Prefer a clear implementation to a comment explaining an unclear one, and let
names and types carry what they can.

**Never write.** The examples are real, and were cut:

- **The case for the code.** `held here rather than checked by the caller
  because ...`; `Offering ▶ rather than ■ says which way the head is stuck, and
  disabling it saves the round trip`. Why a change was made belongs in its
  commit message.
- **What the code already says.** `Offered forwards`, above a function every
  caller passes a positive duration to.
- **What the history says.** `previously this was ...`, `renamed from ...`,
  issue and PR numbers. That is `git log`'s.

**Write only what the code cannot say**, which is nearly always one of three:

- **An outside constraint.** `` `finishedAt` is the file's `race.duration` `` —
  a name on the wire that no type reaches.
- **A hazard.** `` `Started` is defined against the wall clock, so a clock that
  is running and not being ticked has not stopped `` — the mistake it stops the
  next person making.
- **A decision whose alternatives looked equal.** Why `Data.Wec.trackDecoder`
  takes `optional` over `oneOf`.

Length is not the test. That `optional`/`oneOf` note runs sixteen lines and earns
them; every cut listed above was shorter than it. Placement is the test.

This file holds what cannot be read off the code; anything derivable from it is
noise, for the next agent as much as the next person.

## Committing

Re-read the comments and docstrings the change added, against the list above,
and cut what that list forbids. It is a pass of its own, made once the code is
finished: a comment that looked necessary while the code was being written reads
as argument once it is not, and only the second reading tells them apart.

Nothing is lost by cutting. The reasoning is what the commit message is for.

## Testing

- **Elm** — `elm-test` for unit tests, `elm-verify-examples` for docstring
  examples. Benchmarks live in `/package/benchmark/`.
- **TypeScript** — `tsc --noEmit`, over `index.ts`, `vite.config.ts` and
  `src/`. `/app/tests/` is outside the TS project on purpose: Playwright comes
  from the flake rather than from `node_modules`, so `@playwright/test` does
  not resolve for `tsc`.
- **The Elm/element contract** (`/app/tests/custom-elements.spec.ts`) — the
  half of the boundary neither compiler sees. It drives the elements from a
  page directly, and reads the values Elm can send out of the wrapper sources
  rather than repeating them, so a constructor added without a matching
  variant in the vendored component fails here instead of shipping unstyled.
- **Where a test lives** — `test/Motorsport/` drives the domain's decisions
  given the readings they are made from (the grid's basis and its tie-breaks,
  how the lap divides) and needs no database; `test/Round/` and
  `test/Server/TestApi.flix` drive the reading, and need one. A subject with
  both has a file in each, named for the module it drives.
- **A clean build** — `flix build` and `flix test` are incremental, and CI is
  not: a compile that only fails from cold passes locally until `flix/build`
  is removed. `rm -rf flix/build` before believing a green run.
- **The database** — a test drives JDBC rather than a handler standing in for
  it, against the in-memory database `Round.TestSupport.url` names: a
  connection of its own per test, so what one loads is never the archive a
  working copy has. A test that reaches no database fails rather than skipping:
  the boundary is the thing it is there to check. What an in-memory database is
  not is a file, so `Db.TestJdbc` drives one of those too, under a temporary
  directory that does not exist yet — the directory `connect` has to make and
  the journal mode it sets are reached no other way, and two connections at
  once are not reached at all by a database each connection makes afresh.
- **VRT** (`/app/tests/`) — runs against the export rather than the server, so
  it needs nothing set up: with nothing listening on 8080 the dev server
  answers `/api` from `static/`, and those are the same bytes. It drives
  2025's Le Mans because that is the round the export keeps; a test reaching
  for another needs `.#serve-api` behind it. Local runs allow a 0.1%
  pixel-ratio tolerance (`maxDiffPixelRatio: 0.001`) for cross-platform
  diffs; CI is strict 0. Update snapshots locally, or trigger the
  workflow_dispatch in CI to auto-push to the branch.

CI (ubuntu-24.04) runs the unit tests and the typecheck in `test.yml`, and
everything needing a browser in `playwright.yml`.
Snapshots are generated on Linux, so VRT failures on macOS are usually the
platform, not the change.

## Environment

Nix flake provides the reproducible dev environment (Node.js 26, and a Rust
toolchain for `app/src-tauri` — the repository's only Rust package). Enter it
with `nix develop`, or run one command in it with `nix develop --command <cmd>`,
which is what CI does. There is no direnv hook.

`gh` is in the dev shell, so it is reached as `nix develop --command gh ...`.
Authentication is the user's own step (`gh auth login`); no agent performs it.

## Permissions

`.claude/settings.json` follows one rule: **allow broadly, then carve out the
destructive flags with `ask`** — `ask` wins over `allow`, so `Bash(git branch:*)`
can stay open while `-D` still prompts. A narrow `allow` is worse: it leaves
read-only flags (`--show-current`, `-r`, ...) falling through to a prompt.
`deny` is reserved for the irreversible: force push, publish, `sudo`, secret
files.

`gh` is the exception, since its subcommands reach outside the repository, so
each is listed rather than inherited. Reads and `pr create` / `pr edit` are
allowed; everything else prompts, including `pr merge` and any comment.
`release create|delete`, `repo delete` and `secret` are denied.

Read/Grep/Glob are preferred over `cat`/`grep`/`find` in Bash — only the tool-level
rules can enforce the secret-file `deny` entries, which Bash bypasses.
