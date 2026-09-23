# AGENTS.md

Motorsport race analysis and visualization app. CSV telemetry → CLI →
SQLite → HTTP or a JSON export → Elm visualization.

- **`/app`** — Elm SPA, bundled by Vite (Tailwind CSS 4 + shadcn/ui). The only npm
  project: it owns `package.json` and `pnpm-lock.yaml`, so pnpm runs as
  `pnpm -C app`.
- **`/package`** — reusable Elm library (motorsport domain models), reached
  through `elm.json`.
- **`/flix`** — written in Flix, and two things rather than one: the CLI that
  moves CSV through SQLite into JSON/JSONL, and the server that answers
  `/api` out of the same rows. `flix/README.md` describes it — the server,
  the tables a round is held in, and the `SqlRead` / `SqlWrite` / `DbErr`
  effects and `Sql` those two are reached through — and is the thing to read before changing anything under `/flix`.

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
| `nix run .#update-snapshots-vrt` | Update VRT snapshots (macOS renderings; CI will reject them) |
| `nix run .#update-snapshots-ci` | Re-render the VRT baselines on CI and pull them onto this branch |
| `nix run .#benchmark` | Serve `/package/benchmark` (elm reactor) |
| `nix run .#review-app` / `.#review-package` | elm-review |
| `nix run .#format` | elm-format |
| `nix run .#car-images` | Download a season's car photographs and register them |
| `nix run .#flix-build` / `.#flix-test` | Build / test `/flix`, both the CLI and the server |
| `nix run .#cli-run` | CSV→SQLite, and the kept round out to JSON/JSONL |
| `nix run .#cli-load` / `.#cli-export` | Either stage of that run on its own |
| `nix run .#serve-api` | Serve the loaded rounds over HTTP (`/api`, port 8080) |
| `nix run .#tauri-dev` / `.#tauri-build` | Tauri v2 native app (`app/src-tauri`); the build writes every round out first |
| `nix run .#deps-audit` | Dependency audit helper for `/update-deps` |

Prefer these over invoking `pnpm` / `cargo` / `flix` directly — the flake pins
the toolchain and sets the working directory. `/flix` is reached by three
prefixes, and which one says what is being run rather than what is being built:
`flix-*` builds and tests the project, `cli-*` moves the data through it, and
`serve-api` is the server. All of them come out of the same jar.

`.#cli-run` takes the directory holding the season directories and converts
every round `Motorsport.Calendar` lists, in two stages: the CSV goes into the
tables, and a round's summary `.json`, its laps `.jsonl` one lap per line, its
timeline `.jsonl` one event per line, and `index.json` beside them are written
back out of the rows.
**A new round is added to `Motorsport.Calendar` first** — the run converts
nothing the calendar does not list, reports any CSV no round names, and fails
any round whose CSV is missing.

Every round is loaded and every round is written. `--export-only <season>/<id>`
narrows the writing stage alone, repeated to name more than one, and a name no
round on the calendar answers to fails the run before anything is written.

**A checkout holds the CSV, the calendar and one round's files.** 2025's Le
Mans is kept, so the VRT and a dev server work with nothing run first. The
other thirteen are 50MB the rows already say, so they are ignored rather than
committed, and `.#tauri-build` is the one command that writes them — a bundle
carries the files it opens, and nothing else needs all of them at once. A round
left unwritten is quiet: the dev server answers `/api` for it with a 502, and a
Tauri bundle hands back its own `index.html`.

`.#cli-load` and `.#cli-export` are those two stages singly. The stage that
writes reads none of the CSV, so the files are an image of the rows and of
nothing else: a row corrected in SQL is exported, and re-exporting after a
change to a renderer costs no decoding. **The timeline is rows too**: the load
counts it off the laps into `timeline_events`, so a lap corrected in SQL reaches
the summary and the laps on the next export and the timeline not at all — and
not on the next load either, which rebuilds every table off the CSV and takes
the correction with it. Correct `timeline_events` beside `laps`. **A round no
run has loaded fails the export** rather than being written out as a race that
never ran — the rows read back as one, which is the one thing they cannot say
for themselves — and the files it would have replaced are left alone. `/api`
answers such a round with a 404 for the same reason, off the same reading:
`Round.loaded` is where the two of them ask, and it asks `laps` and `cars` — a
round with laps and no cars is half in the database rather than loaded.

Both stages compute in SQLite, and so does the server, so all three need one:
`--database <jdbc url>` names it, `DATABASE_URL` says the same to every run made
in a shell, and the commands name `flix/.db/motorsport.sqlite` when neither
does. One that reaches none does nothing rather than opening an empty database
of its own. The file is in the working copy rather than under /tmp, so what a
run left there is still there to be queried. The integrity checks are read back
out of the rows a round was just loaded into, and so is everything the export
writes and `.#serve-api` answers with.

`/api` is how the app reads a round, and the export is the same archive written
out to files. The calendar is written either way and lists every round there
is, so `dist/api/wec/index.json` — the copy the build writes, and the one URL
the app asks for before it knows anything — is reached only by a bundle with
nothing listening on `/api`. Such a bundle opens whichever rounds were written
before it was built, which is why `.#tauri-build` converts every one of them
first: all fourteen come to 76MB of files and 3MiB in the `.app`, since Tauri
compresses what it embeds. A round the run did not write fails there rather than 404ing —
Tauri's asset resolver answers a path it does not know with `index.html`, so it
decodes HTML. A bundle behind a server
never reaches that copy: the calendar it gets names `/api/wec` and every round
opens.

Passing the flag goes through `nix run .#cli-run -- --database ...`, since the
flake forwards what follows.

`.#serve-api` answers `/api` out of the rows a run loaded: `/api/health`,
`/api/wec/index.json`, and a round's `/api/wec/<season>/<id>.json`,
`_laps.jsonl` and `_timeline.jsonl`. The Vite dev server forwards `/api` to
port 8080, and answers it from `static/` when nothing is listening.

Its operating form is the jar, since `flix run` takes the JVM down with `main`
and the server's does not return. `flix build-jar` leaves the Maven
dependencies out of what it writes, so the JDBC driver is named on the class
path beside the jar rather than bundled in it.

`/update-deps [npm|elm|rust|nix]` (Claude skill) audits and updates dependencies.

`flix` (Claude skill) carries what the compiler does rather than what the code
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
- `Effect.elm` — elm-spa-style effects (`sendCmd`, `sendSharedMsg`, `pushRoute`, ...)
- `Page/` — one module per page, plain TEA
- `Data/` (feed decoding), `UI/` (Notice, and `Shadcn/` for the wrappers)
- `View/` — what a page is laid out of: the car detail panel and its sections,
  the car cards, the live standings, and the badge those share

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

`Data/Wec/CarImage.elm` decodes `/static/car-images.json`, waited on as the
manufacturer table is, which names each season's photographs and the directory
under `static/images/wec` they sit in. `.#car-images --season <year>` writes one
season of it.

It reads two sources because neither has all of it. Le Mans's LMP2 field is the
organiser's class and not the championship's, so fiawec.com — whose categories
are Hypercar and LMGT3 — does not carry it and `api-he.lemans.org` does; and
that API has no list of which races a season ran, which the grid page has. A
season the grid page is not showing is reached through its season filter, which
takes the ids `/evo/1/seasons` publishes and answers for seasons the page itself
no longer offers: 2024 is reached that way and nowhere else, `/en/car/2024`
having become a redirect to the current season.

A season still being run is a photograph per car on the grid page, and a round
is compared against it. One the site keeps only in its archive lists the cars
without their pictures, and then the rounds are the whole of where a car's
photographs come from — its first of them is what the car carries, which is how
2024 reads.

Every round has an upload of its own for every car, most of them the season's
picture again under another name, so a round is registered for the picture
differing and not the file: they are compared by what they hold. Of 2025's, 179
were the season's again and 134 were not.

The photographs are kept as WebP at `-q 75 -sharp_yuv`, at the width they are
published rather than a narrower one — measured as the card draws them, bytes
spent on resolution beat bytes spent on quality. `-sharp_yuv` is the one flag
worth its cost: WebP's lossy mode is YUV 4:2:0 at every quality, and the
sharper conversion recovers a tenth of the error for a twenty-fifth of the size.
Three seasons come to 13MB, where the same pictures as PNG were 71MB.

**A photograph already here is never asked for again.** The one place an image
is requested is reached from two, and both are behind that check, so a run that
cannot compare a file it holds stops and says which. Comparing needs the
original and not the WebP written from it, so `app/scripts/car-image-origins.json`
holds each original's digest — every one a run fetched and not only the ones it
kept, each written as it arrives, so an error, an interrupt or a `--dry-run`
cannot drop what was already paid for. Everything else is bounded by what was
read: one request for the grid page, two more for a season it is not showing,
one for each race the calendar has a round for. A run says how many images it
asked the site for, which is the number to read rather than how many it kept.
Requests are a second apart and nothing is retried.

A photograph is put in place by a rename: half of one would read as a photograph
already here, never be asked for again, and be served.

A run ends by naming **the cars the table has that no source named** — a car
that has left the entry lists keeps whatever the table said of it, which is the
one way a photograph goes unreplaced — and **the photographs narrower than the
rest**, read off the WebP header. 2024's 14 and 2025's 199 are on neither
source and are the two still at 300px.

Both tables are read where the cars decode rather than where they are drawn:
`Data.Wec.eventDecoder` is given the manufacturers and a lookup closed over the
round, and `Car.Metadata` comes out of it carrying the colour, the badge and the
photograph. Nothing downstream asks a second time, so a widget handed a car has
everything it draws.

### The shadcn components

`app/src/shadcn/ui/` is vendored from shadcn's **`base-nova`** registry — Base
UI, not Radix. Each `app/src/shadcn/<name>-element.ts` puts one of them behind
a custom element, `index.ts` registers them all, and
`app/src/UI/Shadcn/<Name>.elm` is the Elm side. The Elm wrappers hold no
Tailwind classes; the class strings are the vendored file's. `UI.Notice` is what
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
(`Snapshot`, `LapHistory`), `Analysis/` for what a view asks of one of those
(`Rivals`, `Pace`), `Chart/` for the charts drawn off them (`GapChart`,
`LapTimeDistribution`), `Leaderboard` and `Lap/SegmentStrip` for the field and a
lap drawn the way this sport prints them.

What is drawn here is a reading of the race in a form the sport is read in: the
field as a timing table, a lap as the segments the circuit times it in, the
charts. How a page is laid out of those -- which panels, in which boxes, what
the reader has picked and what they have open -- is `/app/src/View/`'s. Both
sides are written in the Tailwind `app/style.css` defines, which is why that
file scans `/package` too.

**`/package/src/Internal/`** sits outside `Motorsport/` and holds what the sport
has no word for: `Statistics` and `ChangePoints`, the arithmetic the readings
are built on; `Jsonl`, which decodes a file a line at a time; and `DataView`,
the sortable, filterable table `Leaderboard` is a configuration of, with the
`Table` it draws its rows with.

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
the first kind to say how much of it to read.

A reading of the laps is handed them whole, with a `LapRange` beside them, and
does its own cutting. Cut laps and whole ones are both `List Lap` at a call
site, so a module taking one and a module taking the other are
indistinguishable, and the wrong pairing compiles. The rule earns itself on
`Pace`, whose outlier fence has to come off the whole race the car ran: there
the range and the laps are deliberately not the same stretch, and any other
convention would make that read as a bug.

The three charts the car detail panel tabs between take one shape --
`LapRange -> Snapshot -> Rivals` -- because they are interchangeable to
`ChartTabs`, which holds them side by side. The two wanting only the laps read
`Snapshot.lapHistory` themselves. `ClassPositions` is still given the class and
the snapshot rather than reading the population off `Rivals`, which holds the
whole class already: `around` is only handed the whole field by convention, and
a caller handing it less would leave the position chart drawn against a class
with cars missing, with nothing to say so.

`Wec/` holds the WEC-specific knowledge: the class grid and the eras it has
passed through (`Class`, `Era`), and Le Mans's mini-sectors
(`Circuit/LeMans`). Decoding the timing feed stays app-side in `Data.Wec` /
`Data.Wec.Laps` — the shape of one publisher's files, not of the domain.
`Data.Wec.Manufacturer` and `Data.Wec.CarImage` are app-side for the same
reason: which manufacturers there are, how each is coloured and badged, and
which photograph a car carries at a round, is one series' entry list and this
application's assets. Neither holds any of it itself — each decodes the table
that does, and what reaches `Car.Metadata` is the resolved colour, badge and
photograph rather than the tables.

The names are sorted; the dependencies are not. The core imports out of `Wec/`
in three places: `Car.Metadata` holds a `Class`, `Lap.miniSectors` is fixed to
`Circuit/LeMans`'s type, and `Leaderboard` carries `*_Wec` and `*_LeMans24h`
columns beside the generic ones. Reversing that arrow is its own change.

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
does, so `Race.fromCars` is given a `Race.Index` rather than building one.
`Race.TimelineEvent` is read the same way, off `Round.Timeline` — the race as a
list of what happened, which the round's report is drawn from — though it
arrives in a file of its own rather than in the summary, being the same order of
size as the laps rather than of the indices. Nothing a `Race` holds is counted
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

### The Flix side

`flix/README.md` is the other half of the trip: the server that answers `/api`,
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
- **Flix** — `flix/README.md` holds the rest: where a test lives, what a clean
  build is worth, the stack the type checker gets, and the database a test
  reaches.
- **VRT** (`/app/tests/`) — runs against the export rather than the server, so
  it needs nothing set up: with nothing listening on 8080 the dev server
  answers `/api` from `static/`, and those are the same bytes. It drives
  2025's Le Mans because that is the round a checkout keeps; a test reaching
  for another needs `.#serve-api` behind it. Local runs allow a 0.1%
  pixel-ratio tolerance (`maxDiffPixelRatio: 0.001`, and 0.15% for
  `position-tab`) for cross-platform diffs; CI is strict 0.

The baselines are CI's: rendered on Linux, and what a merge is judged
against. `nix run .#update-snapshots-ci` refreshes them — it dispatches the
workflow on the branch you have checked out, waits for it, pulls the commit
it pushes back, and approves the runs GitHub holds because a bot pushed them.
`.#update-snapshots-vrt` writes macOS renderings, which CI rejects: reach for
it to see what a change did, never to land a baseline.

What separates the two platforms is the rasteriser (CoreText against
FreeType), which no Chromium flag touches. `tests/screenshot.css` narrows it
by asking for greyscale antialiasing and the tolerance absorbs the rest, but
barely. The tolerance is a ratio, so a smaller snapshot gets a smaller budget
while the gap does not shrink with it. The tightest is `position-tab`, the
Comparison section alone at 328x162: it differs by 55 pixels where 0.001 would
allow it 53, which is why it alone is given 0.0015. Next is
`selected-car-with-rivals`, the one shot of a panel whole, at 221 against 246;
`lap-180` has 738 against 1,296. Eight runs gave the same counts but once, when
`lap-180` fell to 102, so a count that moves is worth a second run before it is
taken for a rendering that moved. What no tolerance can absorb is a change
smaller than itself — a digit redrawn is tens of pixels — so a local pass is
not a promise, and a local failure on `position-tab` or
`selected-car-with-rivals` is worth measuring before it is believed. CI stays
strict for both reasons.

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
