---
name: add-round
description: "Add a race round's data end to end from a timing CSV and a few clues: file the CSV, register the round in the calendar and events, load and export it through the CLI, check the rows against the hand-written tables, and verify what the app draws. Use when asked to add, import, load, or a new race/round to the app, or when someone hands over a timing CSV for a round."
---

# Add a round

A round is a CSV, four hand-written lines saying it exists, and two stages of
a CLI that moves it through SQLite into served files. `AGENTS.md` and
`backend/README.md` say what each part *is*; this says what to run and edit, in
order, and what catches you when you skip a step.

The reader's clues are the CSV and its story: the season year, the race's name,
its date, and which circuit it was run at. Nothing downstream can derive the
year — the feed's `HOUR` column is a time of day with no date behind it — so
ask for anything missing before editing.

## 0. Name the round

A round id is `<circuit stem>_<duration>`: `fuji_6h`, `bahrain_8h`,
`qatar_1812km`. The stem is the circuit's word (`bahrain_8h` and a future
`bahrain_1812km` are both `bahrain`), and the suffixes are not a grammar —
that is why `Events.circuit` matches whole ids rather than cutting them.

If the circuit is new — its word is not in `Motorsport.Circuit`'s enum, or no
geometry is served for it — run the **/add-circuit** skill first and come back.

## 1. File the CSV

Put it at `data/wec/<season>/<id>.csv`. The name must answer to the calendar id
exactly: the run fails any round whose CSV is missing and reports any CSV no
round names.

The feed is `;`-separated with a BOM'd header row — compare against a kept file
(`data/wec/2025/cota_6h.csv`) before loading; a differently-spelled publisher's
export is a decoding failure, not a round with odd data.

## 2. Register the round in code

- `backend/src/Motorsport/Calendar.flix` — add `{ id, date }` to its season's
  `rounds`, **in the order the season ran them**; a new year is a new `Season`
  at the front of `seasons()` (newest first is the whole of what makes a season
  current). A season opens when it has data.
- `backend/src/Motorsport/Events.flix` — two cases:
  - `displayName` — the prose name (`"6 Hours of Fuji"`). `TestEvents` fails any
    calendar id that answers as its own id.
  - `circuit` — `Some(Circuit.<Case>)`. `TestEvents` fails any calendar round
    naming no circuit; the drawing decides what to draw it with, this must
    simply answer.
- A genuinely new class grid (a category added, dropped, or moved in order) is
  `package/src/Motorsport/Wec/Era.elm` and `Class.elm`'s `grid` — the only
  place an era is spent. A class name the era's grid does not list is not an
  error: the car reads as `none`.

## 3. Load and export

```bash
nix run .#cli-run                                    # every round on the calendar, both stages
nix run .#cli-load                                   # just the CSV → rows
nix run .#cli-export -- --export-only <season>/<id>  # just the files, out of rows already there
```

The flake names `--csv data/wec` and `--out app/static/wec` itself;
`--database <jdbc url>` is what follows `--`. Both stages compute in
`backend/.db/motorsport.sqlite` unless the flag or `DATABASE_URL` says
otherwise. A round that failed to load has no rows, fails the export too, and
the rounds beside it are written either way — read the run's output rather than
trusting the exit code alone. A round no run has loaded is then a 404 at `/api`
and unwritable at the export; `Round.loaded` is where both ask.

The export writes `app/static/wec/<season>/<id>.json` (summary, carries
`track.circuit`), `_laps.jsonl`, `_timeline.jsonl`, and `index.json` — the
calendar the app reads as its only knowledge of which rounds exist. Of those,
**`index.json` is tracked**: every export rewrites it, and its diff belongs in
the commit even when the round's own three files stay ignored. Nothing
app-side is edited for a new round at a circuit the app already draws.

## 4. Read the rows back

The integrity checks the load answers with are read out of the rows it wrote;
these next checks are against the tables no compiler reads, and are worth
querying after a first load of a new round:

```sql
SELECT DISTINCT manufacturer FROM entries;  -- against app/static/manufacturers.json
SELECT DISTINCT class FROM entries;          -- against the era's grid
```

- **A manufacturer the hand-written table has no row for stops nothing** — the
  car keeps the feed's name and takes a colour from its number. Add a row to
  `manufacturers.json` so it is badged and coloured; the file is in no
  compiler's way, so a wrong entry shows as cars drawn by number, never as a
  red build.
- **A Le Mans feed split other than fifteen mini-sectors** reads as
  `NoMiniSectors` (`byMiniSectorDecoder` requires all fifteen keys) — check the
  mini-sector columns of a new-season Le Mans CSV before believing a round
  drawn without them.
- **Whether the circuit's timing lines still stand** is
  `nix run .#geometry-timing-lines -- <season>/<id> --against <prev-season>`,
  answered once the round is loaded. An `eachSeason` circuit like Le Mans is
  refused by quoting the config's reason — the expected answer, not a failure.

## 5. Photographs and kept files

```bash
nix run .#car-images --season <year>   # fetches and registers static/car-images.json
```

Already-kept originals are never re-asked; the run prints how many it asked the
site for.

**Only two rounds' export files are committed** — which ones, and why the
rest are ignored, `AGENTS.md` says. A new round's files stay ignored (save for
`index.json`, which the export rewrites — step 3); the dev server answers
`/api` from `static/`
only for what is written there, and 502s (or `/api`-404s) for the rest, which
is quiet, not broken. Promoting a round to kept is its own decision: un-ignore
and commit its three files, and it joins the VRT — what the suite then
insists of it, and how the shots land, is the `vrt` skill's.

If a change grew the summary with a key the drawing chooses by, re-export the
kept rounds (`.#cli-export -- --export-only <season>/<id>`, repeated for each —
`AGENTS.md` names which rounds a checkout keeps) or the VRT keeps drawing an
old summary.

**A new round moves the top page's baseline even when nothing else is kept.**
The top page lists every round the calendar has, so its snapshot
(`top.spec.ts-snapshots/top-page.png`) differs the moment `index.json` gains a
card — a registered round is a VRT change whether or not its files are.

## 6. Verify

| Command | What it catches |
| --- | --- |
| `nix run .#flix-build && nix run .#flix-test` | the calendar's whole worklist: `TestEvents` reads ids off `Calendar` and fails a round registered in one file and not the other |
| `nix run .#cli-run` | the round loads and exports with the rest; the integrity checks answer out of the rows |
| `nix run .#serve-api` + `curl localhost:8080/api/wec/<season>/<id>.json` | the round is served, `track.circuit` names the word; `index.json` lists it |
| `nix run .#test` | the app decodes the new feed — classes, eras, mini-sectors |
| `nix run .#test-vrt` | the top page lists the new round, so `top-page.png` needs a re-baseline on `nix run .#update-snapshots-ci` for any registered round — and for promoted or re-exported ones |

## Hazards

- **The load rebuilds every table off the CSV, and the timeline is counted at
  load, not at export** — `AGENTS.md` holds the hazard whole: a row corrected
  in SQL reaches the next export's summary and laps, the timeline not at all,
  and the next load takes the correction away. Correct `timeline_events`
  beside `laps`.
- **`--export-only` narrows the writing stage alone** and is repeated for more
  than one round; a name no calendar entry answers to fails the run *before*
  anything is written.
- **The calendar is knowledge, not data**: no column of the feed carries the
  year, and `seasons()` is written down on purpose. Guessing a season from
  timestamps fabricates a fact the app will draw as history.
- **The stem must match the circuit's word.** A second round at a drawn circuit
  gives it one name and one drawing; a new stem quietly names a new circuit no
  enum, config, or geometry answers to.
- **An empty feed cell for a lap the publisher did not record is `0.000`**, and
  the index reads it as unrecorded — do not "fix" those to nulls or blanks.
- Nothing needs `.#tauri-build` for this; that command is the only one that
  writes every round on the calendar, for a bundle.
