# AGENTS.md

Motorsport race analysis and visualization app. CSV telemetry → CLI →
SQLite → HTTP or a JSON export → Elm visualization.

- **`/app`** — Elm SPA, bundled by Vite (Tailwind CSS 4 + shadcn/ui). The only npm
  project: it owns `package.json` and `pnpm-lock.yaml`, so pnpm runs as
  `pnpm -C app`.
- **`/package`** — reusable Elm library (motorsport domain models), reached
  through `elm.json`.
- **`/backend`** — Flix: the CLI that moves CSV through SQLite into JSON/JSONL, and the server that answers `/api` out of the same rows. Read `backend/README.md` before changing anything here.
- **`/data`** — the timing CSV, `data/wec/<season>/<id>.csv`, read by the CLI, and the manufacturer table, `data/wec/manufacturers.json`, which `app/codegen` compiles into the app. It sits outside `/app` because the build copies all of `app/static` into the bundle.

There is no manifest at the repository root; the flake is what ties the parts
together.

## Commands

All commands run through the Nix flake; `nix flake show` lists everything.

| Command | Purpose |
| --- | --- |
| `nix run .#dev` | Vite dev server (localhost:1234) |
| `nix run .#build` | Production build |
| `nix run .#test` | the app's elm-test, then the package's elm-verify-examples + elm-test |
| `nix run .#typecheck` | `tsc --noEmit` over the app's TypeScript |
| `nix run .#test-vrt` | Playwright VRT |
| `nix run .#update-snapshots-vrt` | Update VRT snapshots (macOS renderings; CI will reject them) |
| `nix run .#update-snapshots-ci` | Re-render the VRT baselines on CI and pull them onto this branch |
| `nix run .#benchmark` | Serve `/package/benchmark` (elm reactor) |
| `nix run .#review-app` / `.#review-package` | elm-review |
| `nix run .#format` | elm-format |
| `nix run .#car-images` | Download a season's car photographs and register them |
| `nix run .#flix-build` / `.#flix-test` | Build / test `/backend`, both the CLI and the server |
| `nix run .#sqlitefx-test` | Test `backend/sqlitefx`, the database library (`backend/sqlitefx/README.md`) |
| `nix run .#cli-run` | CSV→SQLite, and the kept round out to JSON/JSONL |
| `nix run .#cli-load` / `.#cli-export` | Either stage of that run on its own |
| `nix run .#serve-api` | Serve the loaded rounds over HTTP (`/api`, port 8080) |
| `nix run .#tauri-dev` / `.#tauri-build` | Tauri v2 native app (`app/src-tauri`); the build writes every round out first |
| `nix run .#deps-audit` | Dependency audit helper for `/skill:update-deps` |

Prefer these over invoking `pnpm` / `cargo` / `flix` directly — the flake pins the toolchain and sets the working directory.
`flix-*` builds and tests `/backend`, `cli-*` moves the data through it, and `serve-api` is its server; all come out of the same jar.

### What a change is checked with

| Changed | Run | CI gates it |
| --- | --- | --- |
| Elm under `app/` or `package/` | `.#format`, `.#test`, `.#review-app` / `.#review-package` | `.#test` only |
| TypeScript under `app/` | `.#typecheck` | yes |
| `backend/` | `.#flix-test` (`backend/README.md`) | yes |
| `backend/sqlitefx/` | `.#sqlitefx-test`, and `.#flix-test` for the files `backend/src/Sqlitefx/` links | yes |
| Anything drawn, or `app/src/shadcn/` | `.#test-vrt`; a baseline lands through `.#update-snapshots-ci`, never `.#update-snapshots-vrt` | yes (`playwright.yml`) |
| Comments or docs | `/skill:distill-docs`'s after-a-change pass | no |

## Skills

Project skills are `.pi/skills/<name>/SKILL.md`, and `/skill:<name>` names one.
They are not registered with Claude Code's `Skill` tool: read the file and follow it.

| Skill | Read before |
| --- | --- |
| `add-round` | adding a timing CSV as a served round — the calendar, the CLI, the checks, and which frozen lists a new name joins |
| `flix` | diagnosing a Flix build failure: the errors this tree has produced and what each meant |
| `shadcn` | changing `app/src/shadcn/` or `app/src/UI/Shadcn/` |
| `vrt` | touching a VRT baseline: how a shot is judged and how a baseline lands |
| `update-deps` | updating dependencies (`[npm\|elm\|rust\|nix]`) |
| `distill-docs` | pruning or auditing documentation, and any change that adds to this file |
| `commit-push` | a commit and push the user asks for — never a pull request |

## Data hazards

**The served geometry and circuit maps are owned upstream**: `app/static/geometry/*.geojson` and `app/static/circuit-maps/*.json` are not committed — the dev, build, test, VRT and Tauri commands copy them from the pinned `circuit-maps-3d` flake input (`github:y047aka/circuit-maps-3d`) into the working tree. A bump of the pin that moves a geometry moves every tracker VRT baseline with it; the upstream fence is what proves its bytes are reproducible from the kept OpenStreetMap evidence.

**A checkout holds the CSV, the calendar and two rounds' files**: 2025's Le Mans and Circuit of the Americas, so the VRT and a dev server work with nothing run first.
Every other round's files are ignored rather than committed; `.#tauri-build` is the one command that writes them all.
A round left unwritten is quiet: the dev server answers `/api` for it with a 502, and a Tauri bundle hands back its own `index.html`, which then fails to decode.
A kept file is an export like any other, so a summary that grows a key the drawing is chosen by has to be written out again over the kept rounds: `track.circuit` missing reads as a circuit with no drawing.

**The timeline is rows too**: the load counts it off the laps into `timeline_events`, so a lap corrected in SQL reaches the summary and the laps on the next export and the timeline not at all — and the next load rebuilds every table off the CSV and takes the correction with it.
Correct `timeline_events` beside `laps`.

`.#cli-run` converts every round `Motorsport.Calendar` lists and fails any whose CSV is missing; app-side, `Data.Wec.Calendar` is the only source of which rounds exist and where their files are.
The Vite dev server forwards `/api` to port 8080 and answers it from `static/` when nothing is listening.

`static/car-images.json` is read by no compiler: a mistake shows as a car drawn without a photograph, not as a build that fails.

## Architecture

Each module's header says what it is; this section holds only what crosses modules.

- **`/app/src/`** — multi-page SPA on `Browser.application`, no framework. `Main` dispatches pages, `Route` parses URLs, `Shared` holds app-wide state and loading, `Effect` is elm-spa-style. `Page/` one module per page, `View/` what a page is laid out of, `Data/` the shape of the feed, `UI/` `Notice` and the `Shadcn/` wrappers, `Drag` the pointer-carry state machine, `elements/` the one custom element that is not shadcn's (`<drag-handle>`, for `setPointerCapture`).
- **shadcn** — `app/src/shadcn/ui/` is vendored from the **`base-nova`** registry (Base UI, not Radix), one custom element per component, and the Elm wrappers hold no Tailwind classes.
- **An overlay is a `popover`** (the standings', the tracker float's): nothing here hand-rolls a modal.
- **Tables the cars decode against** (colour, badge, photograph) are resolved in `Data.Wec.eventDecoder`, so a widget handed a car asks nothing a second time.
- **Decoding the feed stays app-side** (`Data.Wec*`): it is one publisher's file shape, not the domain.

### The library

`/package/src/Motorsport/` holds the domain; `Internal/` holds what the sport has no word for (`Statistics`, `ChangePoints`, `Jsonl`, `DataView`). Both sides write Tailwind that `app/style.css` defines, which is why it scans `/package` too.

A distance round the lap is a `Length` and a surveyed place a pair of `Angle`s (`ianmackenzie/elm-units`), turned into those where a served file's metres or degrees arrive. What the drawing measures is its own unit and stays a `Float`: a circuit's `x`/`y`, the lengths a detail is drawn at, and the ring's viewBox.

Where a new module goes:

- `Race/` — the loaded race, its indices, and readings of it at a moment.
- `Analysis/` — holds no state and draws nothing. A colour, an emphasis or an axis domain in what it hands back puts it in `Chart/` instead. How many views read it is not a test.
- `Simulation/` — a model run on figures chosen rather than measured: what it hands back is an assumption fitted to the races, never a reading of one. Models are grouped by what they model (`Pace.ReferenceLap`, `Pace.Neutralisation`).
- Directly under `Motorsport/` — serves both sides, so neither owns it (`BestTimes`, `Lap.Performance`).
- `Wec/` — WEC-specific knowledge: the era grids a class is built from, and the circuits. A class itself is a `Motorsport.Class` value, named, placed and colored by the grid it was read against. The core still imports out of `Wec/` (`rg 'import Motorsport.Wec' package/src` lists where); reversing that arrow is its own change.
- Outside `Motorsport/` — `PersonName` and `NonEmpty` know no sport and publish alone (the import rule is `PersonName.elm`'s header's). `Decode/` holds the read of a domain type out of a feed: a driver's name arrives through `Decode.Driver.decoder`, and `Motorsport/Driver` itself imports no JSON.

There is no view-model layer above `Race.Snapshot`: `Snapshot.at` runs once per frame and every view reads a `CarAt` straight off it. A record per car on top cost under 2% of the frame (`benchmark/PerFrameBenchmark.elm`), so nothing sits above it; colours and geometry are the view's own.

A reading of the laps is handed them whole with a `LapRange` beside them, and does its own cutting: cut and whole laps are both `List Lap`, so the wrong pairing compiles.

### Reading the race at a moment

Nothing in a `Race` moves; a clock is applied to it to get what is true then.

- **`at`** — the module's own subject at that moment: `Gap.at`, `BestTimes.at`, `Snapshot.at`, `LapHistory.at`.
- **`xAt`** — one named aspect of *someone else's* subject: `Race.statusAt`, `Race.lapCountAt`, `Lap.findLastLapAt`.
- **`Snapshot`** — the type `at` returns when the whole subject is frozen at one instant. `BestTimes.Snapshot` and `Race.Snapshot` are always written qualified.

### The tracker

`Shared` picks a round's drawing by the circuit its summary names (`track.circuit`), not by the round id; a circuit with no geometry draws as the ring.

Where the timing lines stand is the served circuit map's (`static/circuit-maps/<word>.json`); how a car is placed between them is decided here.
A line the map gives no distance for is placed by the time between the lines either side of it (`Tracker.LapScale.lapScale`).
A circuit whose feed is never timed finer than three sectors is drawn less finely too: between two of its lines a COTA car is placed by the time it has run between them, where a Le Mans car is placed by a mini-sector.

`Motorsport.MiniSector.Named` joins by name in three places: `Lap.miniSegments` (which carries the list position, keeping `Lap.compare` O(1)), `Data.Wec.Laps` (which reads a lap's keys into a `Dict` and lays them in the order the shares name them), and `Tracker.LapScale.lapScale`.
The join never fails, so a name present on one side only drops its entry, silently.
`LapScaleTest` names the two combinations the `lapScale` catch-all holds; do not "simplify" it into reading one side.

`Circuit/Layout`'s Le Mans `Lengths` are frozen by a test: every Le Mans snapshot was rendered with them. Any length moved on any circuit goes through `.#update-snapshots-ci`.

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

Length is not the test; placement is. That `optional`/`oneOf` note runs sixteen lines and earns them.

**Break prose only at sentence ends.** Prose written now — documentation, comments, skills — puts a sentence on one line, however long, and never breaks inside one.
An editor that changes text by exact match must otherwise reproduce every mid-sentence break it cannot see, and a re-wrap turns a small change into a diff of lines no one wrote.
Existing fixed-width prose stays as it stands; tables keep a row per line, and bullets an item per line.

## Committing

Re-read the comments and docstrings the change added, against the list above,
and cut what that list forbids. It is a pass of its own, made once the code is
finished: a comment that looked necessary while the code was being written reads
as argument once it is not, and only the second reading tells them apart.

A line a change adds to this file must name no closer owner: what one module, README or skill could hold goes there instead, and this file stays under 2,500 words. `/skill:distill-docs` holds the test.

## Testing hazards

- **Elm** — `.#test` first runs `app/scripts/test-fixtures.mjs`, which writes the served geometry and circuit maps out as ignored Elm modules under `TestHelpers/Survey/` and `TestHelpers/Map/`; a bare `elm-test` without them fails to compile by name, as does any bare `elm make` without `app/generated/` (the flake's `generateElm`).
  `elm-explorations/test` sits in the app's `dependencies` on purpose: hand-written `test-dependencies` read fine to elm-test but make every `elm make` fail with "dependencies edited by hand".
- **TypeScript** — `/app/tests/` is outside the TS project on purpose: Playwright comes from the flake, so `@playwright/test` does not resolve for `tsc`.
- **The Elm/element contract** (`app/tests/custom-elements.spec.ts`) reads the values Elm can send out of the wrapper sources, so a constructor without a matching variant in the vendored component fails there instead of shipping unstyled.
- **Spec constants** (`app/tests/car-detail.spec.ts`) are read out of the Elm sources that decide them. A constant that moves modules must take its pattern with it; `readConstant` fails by name when one misses.
- **Flix** — `backend/README.md` holds what each test reads.
- **VRT** runs against the export, so it needs nothing set up, and drives the two kept rounds.

## Environment

The Nix flake provides Node.js 26 and a Rust toolchain for `app/src-tauri` (the only Rust package).
Enter it with `nix develop`, or run one command in it with `nix develop --command <cmd>`, which is what CI does; there is no direnv hook.
`flake.nix` holds the commands, and `nix/vrt.nix` the VRT's.

`gh` is in the dev shell (`nix develop --command gh ...`); authentication (`gh auth login`) is the user's own step.
