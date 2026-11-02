# AGENTS.md

Motorsport race analysis and visualization app. CSV telemetry → CLI →
SQLite → HTTP or a JSON export → Elm visualization.

- **`/app`** — Elm SPA, bundled by Vite (Tailwind CSS 4 + shadcn/ui). The only npm
  project: it owns `package.json` and `pnpm-lock.yaml`, so pnpm runs as
  `pnpm -C app`.
- **`/package`** — reusable Elm library (motorsport domain models), reached
  through `elm.json`.
- **`/backend`** — written in Flix, and two things rather than one: the CLI that moves CSV through SQLite into JSON/JSONL, and the server that answers `/api` out of the same rows. `backend/README.md` describes it — the server, the two stages and the one database they compute in, the tables a round is held in, and the `SqlRead` / `SqlWrite` / `DbErr` effects and `Sql` those two are reached through — and is the thing to read before changing anything under `/backend`. Neither the timing-lines report nor the probe is in this jar: both are words of the `circuits/` project, which reads some of this `src` through symlinks — `backend/README.md` holds the double compile that reaches a change here, and `circuits/README.md` which files are read that way.
- **`/data`** — the timing CSV, `data/wec/<season>/<id>.csv`: what the CLI reads
  and nothing else does. It sits outside `/app` because the build copies all of
  `app/static` into the bundle.
- **`/circuits`** — the geometry pipeline: OpenStreetMap relations through
  the Flix project at `circuits/src` into the served `app/static/geometry/*.geojson`,
  with one directory per circuit — its kept Overpass answer
  and its kept atlas line — named by the word the summaries send for the circuit,
  and its figures authored in the project's own `Circuit.flix`.
  It sits outside `/app` because nothing it writes but the geometry files is
  ever served, and nothing in the bundle reads the pipeline itself.
  `circuits/README.md` describes it — the fence that keeps a geometry an
  answer to its survey, what a circuit's config is authored from, and where
  the timing lines' distances come from — and is the thing to read before
  changing anything under `/circuits`. It holds one of the repository's two Flix
  projects, the geometry pipeline at the `circuits/` root — the other is `/backend`: the pipeline
  resolves nothing of that one's and reads nothing of it either; only the timing report does,
  through the links `circuits/README.md` lists.

There is no manifest at the repository root; the flake is what ties the parts
together.

## Commands

All commands run through the Nix flake; `nix flake show` lists everything.

| Command | Purpose |
| --- | --- |
| `nix run .#dev` | Vite dev server (localhost:1234) |
| `nix run .#build` | Production build |
| `nix run .#test` | the app's elm-test, then the package's elm-verify-examples + elm-test |
| `nix run .#typecheck` | `tsc --noEmit` over the app's TypeScript (the circuit tools are Flix now and compile under `.#geometry-test`) |
| `nix run .#test-vrt` | Playwright VRT |
| `nix run .#update-snapshots-vrt` | Update VRT snapshots (macOS renderings; CI will reject them) |
| `nix run .#update-snapshots-ci` | Re-render the VRT baselines on CI and pull them onto this branch |
| `nix run .#benchmark` | Serve `/package/benchmark` (elm reactor) |
| `nix run .#review-app` / `.#review-package` | elm-review |
| `nix run .#format` | elm-format |
| `nix run .#car-images` | Download a season's car photographs and register them |
| `nix run .#geometry -- <word> ...` | The geometry pipeline, one word at a time: `survey` re-surveys a kept answer and answers whether it lays the served bytes (`--write` lays them, `--fetch` asks OpenStreetMap now); `atlas` measures another dataset's line and keeps it beside the survey; `diff` lays two kept geometries in metres, optionally as an SVG overlay; `regenerate` is the fence over every kept answer (`--write` re-lays, `--freeze` asks now); `probe` asks which relations hold a place on earth, each candidate's ways measured; `timing-lines` prints whether a circuit's timing lines held where they stood a season earlier. Paths resolve from where the command is run; what each word keeps, and what each fence answers, is `circuits/README.md`'s |
| `nix run .#geometry-test` | The project's `flix test` — readings off fixtures, no network, no database, no files written — then `test/check-sources.mjs`, the facts about the project's own sources that no pure `@Test` can reach |
| `nix run .#geometry-timing-lines` | Whether a circuit's timing lines still stand where they stood a season earlier, read off two rounds' sector times (the geometry project's `timing-lines` word, computing in no database; `<season>/<id> [--against <season>] [--tolerance <metres>]`) |
| `nix run .#flix-build` / `.#flix-test` | Build / test `/backend`, both the CLI and the server |
| `nix run .#cli-run` | CSV→SQLite, and the kept round out to JSON/JSONL |
| `nix run .#cli-load` / `.#cli-export` | Either stage of that run on its own |
| `nix run .#serve-api` | Serve the loaded rounds over HTTP (`/api`, port 8080) |
| `nix run .#tauri-dev` / `.#tauri-build` | Tauri v2 native app (`app/src-tauri`); the build writes every round out first |
| `nix run .#deps-audit` | Dependency audit helper for `/skill:update-deps` |

Prefer these over invoking `pnpm` / `cargo` / `flix` directly — the flake pins
the toolchain and sets the working directory. `/backend` is reached by three
prefixes, and which one says what is being run rather than what is being built:
`flix-*` builds and tests the project, `cli-*` moves the data through it, and
`serve-api` is the server. All of them come out of the same jar.

`.#cli-run` converts every round `Motorsport.Calendar` lists, reports any CSV no round names, and fails any round whose CSV is missing — the calendar is the gate a round joins before anything runs. What each stage reads and writes, and the database all of them compute in, are `backend/README.md`'s; the whole trip from a CSV to a drawn round is `/skill:add-round`.

**A checkout holds the CSV, the calendar and two rounds' files.** 2025's Le Mans and 2025's Circuit of the Americas are kept, so the VRT and a dev server work with nothing run first — COTA is kept on the strength of one tracker shot, at 1.8MB against Le Mans's 25MB of laps.
The other fourteen are tens of megabytes of what the rows already say, so they are ignored rather than committed, and `.#tauri-build` is the one command that writes them — a bundle carries the files it opens, and nothing else needs all of them at once.
A round left unwritten is quiet: the dev server answers `/api` for it with a 502, and a Tauri bundle hands back its own `index.html`. A kept file is an export like any other, so a summary that grows a key the drawing is chosen by has to be written out again over the kept rounds: `track.circuit` missing reads as a circuit with no drawing.

**The timeline is rows too**: the load counts it off the laps into `timeline_events`, so a lap corrected in SQL reaches the summary and the laps on the next export and the timeline not at all — and not on the next load either, which rebuilds every table off the CSV and takes the correction with it.
Correct `timeline_events` beside `laps`.

`/api` is how the app reads a round, and the export is the same archive written out to files.
The calendar is written either way and lists every round there is, so `dist/api/wec/index.json` — the copy the build writes, and the one URL the app asks for before it knows anything — is reached only by a bundle with nothing listening on `/api`. Such a bundle opens whichever rounds were written before it was built, which is why `.#tauri-build` converts every one of them first — sixteen rounds' files, which Tauri compresses into the `.app`. A round the run did not write fails there rather than 404ing — Tauri's asset resolver answers a path it does not know with `index.html`, so it decodes HTML.
A bundle behind a server never reaches that copy: the calendar it gets names `/api/wec` and every round opens.

`.#serve-api` answers `/api` out of the rows a run loaded; the endpoints and the jar the server runs as are `backend/README.md`'s. The Vite dev server forwards `/api` to port 8080, and answers it from `static/` when nothing is listening.

Project skills live in `.pi/skills/`. `/skill:update-deps [npm|elm|rust|nix]` audits and updates dependencies.
`/skill:add-round` takes a timing CSV and its clues through the calendar, the CLI and the checks into a served round; `/skill:add-circuit` takes a circuit from an OpenStreetMap probe through the config, the kept answer and the geometry to a drawing.
Adding a round or a circuit is those skills' — the sections below say what things *are*, and the skills hold what to *do*, in order, and which frozen lists a new name joins.
`/skill:distill-docs` keeps that division true: which layer owns a fact, what over-documentation looks like, and how to prune and audit without losing a hazard.
`/skill:commit-push` does the commit and push a user asks for, and only that — never a pull request.

`flix` carries what the compiler does rather than what the code
is: the errors this tree has actually produced, what each one meant, and how a
change is verified cold and against CI's smaller stack. Reach for it before
diagnosing a Flix build failure by reading code.

## Architecture

**`/app/src/`** — hand-written multi-page SPA on `Browser.application`
(framework-less; no elm-pages). `index.ts` boots `Elm.Main.init`; data is
fetched at runtime via `Http`.

- `Main.elm` — top-level Model/Msg, URL handling, page dispatch
- `Route.elm` — `Url.Parser` routes: `/`, `/debug`, `/wec/:season/:event`
- `Shared.elm` — app-wide state (race control, view model) + data loading
- `Effect.elm` — elm-spa-style effects (`sendCmd`, `sendSharedMsg`, ...)
- `Page/` — one module per page, plain TEA
- `Data/` (feed decoding), `UI/` (Notice and `Shadcn/` for the wrappers),
  `Drag`/`Drag.Handle` for carrying a thing by a pointer (the state machine
  and the grip that reports it), and `elements/` for the one custom element
  that is not shadcn's: `<drag-handle>`, which does the one thing Elm cannot,
  `setPointerCapture`
- `View/` — what a page is laid out of: the car detail panel and its sections,
  the live standings, a class's own column with its pit lane list, and the
  badge and class mark those share

`Data/Wec/Calendar.elm` decodes `index.json`, fetched once by `Shared` from
`/api/wec/index.json`. It is the app's only source for which rounds exist, what
they are called and where their files are — nothing app-side builds those paths,
and a round it does not list cannot be opened. That one URL is the whole of
what the app knows about where its data comes from: the calendar names each
round's summary and laps, and nothing else does.

`Data/Wec/Manufacturer.elm` decodes `/static/manufacturers.json` the same way,
also once, and a round waits on it as it waits on the calendar. That file is
written by hand and no compiler reads it, so a mistake in it shows as cars drawn
by their numbers rather than as a build that fails. Unlike an unlisted round, an
unnamed manufacturer stops nothing: the car keeps the name the feed gave it and
takes a colour from its number. What the feed spells is
`SELECT DISTINCT manufacturer FROM entries` once a run has loaded, so which of
them the file has no row for is one query rather than a reading of the cars.

`Data/Wec/CarImage.elm` decodes `/static/car-images.json`, waited on as the manufacturer table is, which names each season's photographs and the directory under `static/images/wec` they sit in.
`.#car-images --season <year>` writes one season of it; `app/scripts/fetch-car-images.mjs` says which two sources it reads and why.
A season the grid page is not showing is reached through its season filter, which takes the ids `/evo/1/seasons` publishes and answers for seasons the page itself no longer offers: 2024 is reached that way and nowhere else, `/en/car/2024` being a redirect to the current season.
How the photographs are encoded, and the digest that keeps one already here from being asked for again, are that script's own header to say.

Both tables are read where the cars decode rather than where they are drawn:
`Data.Wec.eventDecoder` is given the manufacturers and a lookup closed over the
round, and `Car.Metadata` comes out of it carrying the colour, the badge and the
photograph. Nothing downstream asks a second time, so a widget handed a car has
everything it draws.

### The car column strip

`Page/Wec/Columns.elm` is the strip's own model, messages and update: the
order, the one column a pointer carries, and how far
down each car's panel was scrolled. The page holds one `Columns.Model`,
forwards through `ColumnsMsg`, and hands the field in per call.

A column is keyed by `StripKey` -- a class's, a car's, the tracker's or the
events table's. The strip opens with one column per class the field has cars
out in, in the order a classification lists them and not the order their
leaders run in, the tracker's column and the events table behind them; a
car's column joins at the back when the reader picks one, and from the first
open, close or move the order is the reader's.

A class's column (`View/ClassColumn.elm`) is how a race is followed while it is
still sorting itself out, and is the standings read down one class instead of the
field: every car the class has, class place first, the interval to the class-mate
ahead rather than to whoever is ahead, and the class's own fastest lap as the
reference rather than the race's. A row picks that car, whose panel opens beside
the class's column; a row whose car is up already is marked and scrolls the
strip to that column rather than opening a second. Where a class's column has
been closed, its name in the standings is the press that calls it back. The
class is drawn in classification order, so a column comes in blocks with a rule
between them -- nothing is measured between a car that stopped and one that
did not.

Every column is drawn `Columns.width` wide, and everything that measures the
strip -- where a column stands, how far a carry moves one, how far a press
scrolls -- is done in that one width and `pitch`.

### The shadcn components

`app/src/shadcn/ui/` is vendored from shadcn's **`base-nova`** registry — Base UI, not Radix.
Each `app/src/shadcn/<name>-element.ts` puts one of them behind a custom element, `index.ts` registers them all, and `app/src/UI/Shadcn/<Name>.elm` is the Elm side.
The Elm wrappers hold no Tailwind classes; the class strings are the vendored file's. `UI.Notice` is what sits beside them: Elm that writes its own Tailwind and answers to no vendored file.

`shadcn` carries what touching them obliges: the CLI's `add` and `--diff` workflow and the drift discipline, the four things the Elm↔element property boundary will not carry, which elements mount React and which only lend class strings, and what a mount costs measured.
Reach for it before changing anything under `app/src/shadcn/` or `app/src/UI/Shadcn/`.

**`/package/src/Motorsport/`** — domain models (`Car`, `Driver`, `Lap`, `Gap`),
`Race/` for the loaded race, its indices, and readings of it at a moment
(`Snapshot`, `LapHistory`), `Analysis/` for what a view asks of one of those
(`Rivals`, `Pace`), `Chart/` for the charts drawn off them (`GapChart`,
`LapTimeDistribution`), `Leaderboard` for how a timing screen draws a single
reading (a rated time, a moved arrow, a lap with its sector strip), and
`Lap/SegmentStrip` for a lap drawn the way this sport prints it.

What is drawn here is a reading of the race in a form the sport is read in: a
lap as the segments the circuit times it in, the charts. The field as a
timing tower is the app's `View/LiveStandings.elm`, arranged out of the
`Leaderboard`'s readings. How a page is laid out of those -- which panels, in
which boxes, what the reader has picked and what they have open -- is
`/app/src/View/`'s. Both sides are written in the Tailwind `app/style.css`
defines, which is why that file scans `/package` too.

**`/package/src/Internal/`** sits outside `Motorsport/` and holds what the sport
has no word for: `Statistics` and `ChangePoints`, the arithmetic the readings
are built on; `Jsonl`, which decodes a file a line at a time; and `DataView`,
the sortable, filterable, paginated table the app's Events column configures
directly, with the `Table` it draws its rows with.

Directly under `Motorsport/` are the primitives the rest is written in.
`Analysis/` is what a view asks of a snapshot rather than what a race is made
of: a module belongs there when it holds no state of its own and it draws
nothing -- which is what keeps it out of `Race/`, where nothing owns it, and
out of `Chart/`. Drawing is the test that does the work. A
colour, an emphasis or an axis domain in what a module hands back puts it with
the chart whatever else it computes, which is why `GapChart` keeps `carLine`
and `LapTimeDistribution` keeps `seriesOf` while the arithmetic under both of them
sits here. How many views read a module is not a test: the shelf is organised
by the reading and not by the reader, so `Rivals` is asked by every view that
draws a car among its rivals, and a chart's own sample by that chart alone.

The shelf holds two kinds, and which kind a module is says what its arguments
look like.

**What to read.** `Rivals` answers who a car is racing and `LapWindow` which
laps a stretch of the race covers. Each takes the reader's choice -- how wide a
ring, how long a stretch -- and answers in the snapshot's own `CarAt`s and
numbers rather than a record per car. `Rivals.fight` is the ring every view
comparing cars draws, named here so that the charts and the legend beside them
cannot disagree about how wide it is; the wider rings stay the reader's.

**What it comes to.** `ClassPositions`, `RelativeGap`, `Pace` and `Stint`
derive from a `Race.Snapshot` and the primitives, and are given an answer of
the first kind to say how much of it to read. `CarLog` is read off the field's
events instead: `Line`s of its own, since what happened to a car is a telling and
not a value the race holds.

A reading of the laps is handed them whole, with a `LapRange` beside them, and
does its own cutting. Cut laps and whole ones are both `List Lap` at a call
site, so a module taking one and a module taking the other are
indistinguishable, and the wrong pairing compiles. Two cuts sit side by side in
the lap-time distribution -- `Pace` cuts each car's laps to the range that car has
run, `Chart.LapTimeDistribution` fences the laps of every car that shares the axis
-- and only the two arguments say which is which.

The three charts the car detail panel tabs between take one shape --
`LapRange -> Snapshot -> Rivals` -- because they are interchangeable to
`ChartTabs`, which holds them side by side. The two wanting only the laps read
`Snapshot.lapHistory` themselves. `ClassPositions` is still given the class and
the snapshot rather than reading the population off `Rivals`, which holds the
whole class already: `around` is only handed the whole field by convention, and
a caller handing it less would leave the position chart drawn against a class
with cars missing, with nothing to say so.

`Wec/` holds the WEC-specific knowledge: the class grid and the eras it has
passed through (`Class`, `Era`), Le Mans's mini-sectors (`Circuit/LeMans`), and
the shape of the circuits the tracker draws (`Circuit/Layout`, and one directory
per circuit). Decoding the timing feed stays app-side in `Data.Wec` /
`Data.Wec.Laps` — the shape of one publisher's files, not of the domain.
`Data.Wec.Manufacturer` and `Data.Wec.CarImage` are app-side for the same
reason: which manufacturers there are, how each is coloured and badged, and
which photograph a car carries at a round, is one series' entry list and this
application's assets. Neither holds any of it itself — each decodes the table
that does, and what reaches `Car.Metadata` is the resolved colour, badge and
photograph rather than the tables.

Three circuits are drawn to their own shape rather than as a ring: Le Mans, the
Circuit of the Americas, and the Circuit de Barcelona-Catalunya. `Circuit/Layout` is what
`Tracker.onCircuit` is handed — the lap, the pit lane, the lines the lap is
timed at, and the metres the tracker draws at — and it is where the surveyed
degrees are projected into drawing metres, once, whichever circuit they came
from. Each circuit's `Layout` holds its distances and its lengths; the degrees
themselves are no Elm module: each circuit's geometry is a GeoJSON file at
`static/geometry/<circuit>.geojson`, written out of OpenStreetMap's map
data (ODbL, © OpenStreetMap contributors) into a file that records its own
survey time, and `Motorsport.Wec.Circuit.Geometry` reads it back as a round
loads. Which circuit a round was
run on comes in with the summary (`Motorsport.Events.circuit`, keyed by round id
and tested against the calendar), and `Shared` picks the
layout by that word rather than by the round id — which is still asked for,
because which lines Le Mans is drawn with turns on the season. A circuit with no
directory of its own, and a round exported before the summary named its circuit,
is drawn as the ring.

The lines a drawing times to come from the circuit’s own published map of
them — where those distances come from and how the times are read against
them is `circuits/README.md`’s to say; what is decided here is how a car is
placed between them.
A line a map gives no distance for is
placed by the time between the lines either side of it
(`Tracker.Config.lapScale`), and a circuit whose feed never measures the lap finer
than three sectors — every circuit here but Le Mans's — has no finer lines to place
a car by either. That is a different answer from fifteen lines most of which the
map leaves no distance for, so it is a sum rather than a record of nothings, and it
is drawn less finely too: between two of its lines a COTA car is placed by the time
it has run between them, where a Le Mans car is placed by a mini-sector.

A circuit whose map has never been read at authoring — Barcelona's — has no
line distances to place anything by: its layout puts each line where the
round's own sector share ends, and places every car between two of them by the
time it has run between them, which is the reading the ring gives an undrawn
round, on surveyed degrees.

That sum is named `LeMansMiniSectors`, holds Le Mans's fifteen by name, and is
load-bearing in three places at once: the sum, `Data.Wec`'s `byMiniSectorDecoder`,
which requires all fifteen keys and so reads a differently-split lap as
`NoMiniSectors`, and `Tracker.Config.lapScale`, which matches the pair of
constructors. The first circuit after Le Mans whose feed carries mini-sector shares
has to generalize all three together — a named list at both ends, joined by name —
and re-make the decoder's `optional` decision rather than copy it, because what
catches a missing line today is the record's totality and a list has nothing else.
`ConfigTest` names the two combinations the `lapScale` catch-all holds — a round
timed finer than its circuit places lines, and lines the circuit places that no
round was timed across — which is what stops a future edit "simplifying" that branch
into reading one side alone.

The tracker's cars, labels and lines are metres on the ground, and the svg divides
every one of them by whichever axis the circuit's box binds in the card it stands
in — so a set is measured against a rendered drawing, and one circuit's set is not
another's multiplied by a scale. `Circuit/Layout`'s `Lengths` holds one set per
circuit per detail, and `Compact` carries no names because it draws none. Le Mans's
set is the reference the tracker was measured at, and a test freezes it: those are
the numbers every Le Mans snapshot was rendered with. How another circuit's set is
measured against it — and which one length is left off the ratio — is each
circuit's own `Layout` header and its `LayoutTest`. Tuning a length of Le Mans's set moves every
baseline it has, and any length moved anywhere goes through `update-snapshots-ci`.

The names are sorted; the dependencies are not. The core imports out of `Wec/`
in four places: `Car.Metadata` holds a `Class`, `Lap.miniSectors` is fixed to
`Circuit/LeMans`'s type, `Leaderboard` carries `*_Wec` and `*_LeMans24h`
views beside the generic ones, and `Chart/Tracker` draws `Wec/Circuit/Layout`,
whose finer lines are Le Mans's. Reversing that arrow is its own change.

There is no view-model layer between the two. `Race.Snapshot` is the whole
per-frame derivation — sampling the cars at the clock, ordering the field,
measuring the gaps, rating the times against the records as they stood — and
views read a `CarAt` straight off it. Colours and geometry are the view's own: a
widget that wants a class's colour calls `Class.toColor` itself, and a
`Manufacturer` is read for the colour and logo it was built with. `Snapshot.at`
runs once per frame and every view shares that result, which is the only reason
the type exists; a record per car on top of it cost under 2% of the frame
(`benchmark/PerFrameBenchmark.elm`), so nothing sits above it. What `Analysis/`
holds is not that layer: those modules pick out and count what a snapshot
already holds, and hand its own values back.

Modules serving both sides sit directly under `Motorsport/` rather than in a
subdirectory — `BestTimes` is held by `Race` and read back by `Race.Snapshot`,
and `Lap.Performance` rates a lap for either side, so neither owns them.
Neither walks a lap of the race. Which lap took which record is counted in
`Round.Index` and arrives with the round's summary, as `Race.lapCompletions`
and the field's flags do, so `Race.fromCars` is given a `Race.Index` rather
than building one.
`Race.TimelineEvent` is read the same way, off `Round.Timeline` — the race as a
list of what happened, which the round's report is drawn from — though it
arrives in a file of its own rather than in the summary. Nothing a `Race` holds is counted
off it: a car's status is its own laps read against the time limit, so a round
draws without it and `Shared` does not wait for it.

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

### The circuits side

`circuits/README.md` is the other end of a drawing: how a geometry is surveyed
out of OpenStreetMap, what the kept file is checked against — the byte fence
over a kept answer exempting nothing, the regeneration fence over every
circuit exempting the stamp alone, the contract spec over the bytes the app
is served —
where the timing lines' distances come
from, and how far an atlas line stands from the one drawn.

### The backend side

`backend/README.md` is the other half of the trip: the server that answers `/api`,
the tables it reads a round out of, and the `SqlRead` / `SqlWrite` / `DbErr`
effects and `Sql` query builder the two stages reach it through.

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

**Break prose only at sentence ends.** Prose written now — documentation, comments, skills — puts its line breaks where sentences end and never inside a sentence: a sentence stands on one line, however long.
A mid-sentence break is a character an editor that changes text by exact match must reproduce to touch the lines around it, and cannot know without re-reading; a break guessed wrong turns every edit into a failed call and a retry, and a cut that re-wraps its neighbourhood turns a small change into a diff of lines no one wrote.
One-sentence-per-line gives the editor a sentence-sized anchor, takes re-wrapping out of every change, and keeps a diff hunk exactly as local as fixed-width wrapping did.
This is the reason the rule is layout and not taste: the terminal width fixed wrapping optimized for is read far less than these files are edited.
Existing fixed-width prose stays as it stands — the rule reaches prose being written, not a re-lay of what is; tables keep a row per line, and bullets keep an item per line.

## Committing

Re-read the comments and docstrings the change added, against the list above,
and cut what that list forbids. It is a pass of its own, made once the code is
finished: a comment that looked necessary while the code was being written reads
as argument once it is not, and only the second reading tells them apart.

Nothing is lost by cutting. The reasoning is what the commit message is for.

## Testing

- **Elm** — `elm-test` for unit tests, `elm-verify-examples` for docstring
  examples. Benchmarks live in `/package/benchmark/`. Tests of app modules run
  from `app/tests/` and of the library's from `package/tests/`; `.#test` runs
  both. The package's circuit tests read the geometry bytes as the app reads
  them: `.#test` first runs `app/scripts/test-fixtures.mjs`, which writes the
  served files out as ignored Elm modules under `TestHelpers/Survey/`, and a
  bare `elm-test` without them fails to compile by name.
  `elm-explorations/test` sits in the app's `dependencies` for this --
  hand-written `test-dependencies` read fine to elm-test but make every
  `elm make` fail with "dependencies edited by hand", which is a build break
  the test runner does not see.
- **TypeScript** — the app's `tsc --noEmit` covers `index.ts`, `vite.config.ts`
  and `src/`; `/app/tests/` is outside the TS project on purpose: Playwright
  comes from the flake rather than from `node_modules`, so `@playwright/test`
  does not resolve for `tsc`.
- **The geometry project** (`circuits/`) — a Flix project of its own, tested by `nix run .#geometry-test`: every reading is handed a fixture rather than a survey, the one test handed none is the timing map's derivation, and `check-sources.mjs` holds to one spelling the project-wide facts an `@Test` cannot reach — no browser, no `node_modules`, plain `node` over `circuits/src`. Which readings exist and what each check reads and why, and what stays the fences' and the contract specs' rather than any test's, is `circuits/README.md`'s.
- **The Elm/element contract** (`/app/tests/custom-elements.spec.ts`) — the
  half of the boundary neither compiler sees. It drives the elements from a
  page directly, and reads the values Elm can send out of the wrapper sources
  rather than repeating them, so a constructor added without a matching
  variant in the vendored component fails here instead of shipping unstyled.
- **Spec constants** (`/app/tests/car-detail.spec.ts`) — widths, pitches and
  steps are likewise read out of the Elm sources that decide them. A constant
  that moves modules must take its pattern with it; `readConstant` fails the
  spec load by name when a pattern misses, rather than letting the constant
  become `NaN` and every assertion expect `NaNpx`.
- **Timing figures** (`circuits/test/TestTimingMap.flix`) — the timing-lines report holds no copy of a circuit's lap length or sector stretches: it derives its answer from the ones the circuit's config authors, and `.#geometry-test` reads that derivation. The one figure-list the two projects each hold — the circuit words — and what fails by name when a link or a list moves, is `circuits/README.md`'s.
- **Flix** — `backend/README.md` holds the rest: where a test lives, what a clean
  build is worth, the stack the type checker gets, and the database a test
  reaches.
- **VRT** (`/app/tests/`) — runs against the export rather than the server, so it needs nothing set up, and drives the two rounds a checkout keeps. The `vrt` skill carries how a shot is judged, what a round losing its drawing looks like when no baseline can see it, what the platforms differ by and by how many pixels, and how a baseline is landed. Reach for it before touching a baseline.

CI (ubuntu-24.04) runs the unit tests and the typecheck in `test.yml`, and
everything needing a browser in `playwright.yml`.

## Environment

Nix flake provides the reproducible dev environment (Node.js 26, and a Rust
toolchain for `app/src-tauri` — the repository's only Rust package). Enter it
with `nix develop`, or run one command in it with `nix develop --command <cmd>`,
which is what CI does. There is no direnv hook.

`flake.nix` holds the commands; `nix/` holds a subject that outgrew it,
which so far is only the VRT (`nix/vrt.nix`, and the shell it reads).

`gh` is in the dev shell, so it is reached as `nix develop --command gh ...`.
Authentication is the user's own step (`gh auth login`); no agent performs it.
