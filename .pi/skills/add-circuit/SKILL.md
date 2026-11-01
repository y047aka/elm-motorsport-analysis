---
name: add-circuit
description: "Add a new circuit's data end to end: probe OpenStreetMap for its relation, author its circuits config, keep the Overpass answer and atlas line, lay the served geometry, join the word on both wire copies, draw it app-side, and run every fence that judges the result. Use when asked to add, survey, or draw a new circuit, or when a new round's circuit has no geometry yet."
---

# Add a circuit

A circuit is one word, spelled in places no compiler reaches from one to the
other. `circuits/README.md` says *why* each part is what it is; this says *what
to run, in what order, and what catches you when you skip a step*.

The word is the stem the round ids share (`fuji_6h` → `fuji`), snake_case. It
names the evidence directory, the served file, and the arm the app matches on.
Choose it before anything else — everything downstream is named by it.

Run every command below from the repository root: the flake exports
`GEOMETRY_FROM` as the directory the command was asked from, and a reader
types `app/static/geometry/...` relative to it.

## 1. Probe before authoring

```bash
nix run .#geometry -- probe <lat>,<lon> [--radius <km>]
```

Prints each candidate relation with its roles' ways measured. The length is
what tells the full circuit from the GP circuit standing beside it; the default
5 km box holds COTA and not a 13.6 km one — widen it for long circuits. The
report is for a human, not for a name: read it before writing a config, and
note how the relation tags its start/finish line (the three kept circuits are
tagged three different ways).

Optionally measure the atlas line first — for a circuit that publishes no
start/finish coordinate, its `start_finish` marker is the surveyed place a
config's `timingLine` is seeded from:

```bash
nix run .#geometry -- atlas <word> --fetch   # keeps circuits/<word>/atlas.geojson
```

## 2. Author the config — `circuits/src/Circuit.flix`

Add one `def <word>(): Circuit` and append it to `circuits()`. Its
doc-comment is where *how the relation is actually tagged* belongs. Fields
worth a decision:

- `timedFrom` — the relation member naming the line the lap is timed across.
  Every metre is measured from whichever one was answered to.
- `timingLine` — the published place (and the `within` the survey may allow),
  or the atlas seed, or `None` where the circuit tags nothing mistakable.
  A run that answers the wrong role fails before writing only when this is set;
  without it a wrong line just draws every car early.
- `lap` — the published length the surveyed line is stretched to.
- `sectors` — exactly one kind:
  - `published`: one map serves every season; the `stretches` must add up to
    `lap` within `stretchTolerance` (0.15 m) and travel into the geometry as
    `sectors`.
  - `eachSeason`: the organiser re-issues the map; carry the reason the timing
    report will quote when it refuses a round.
  - neither: no map was read at authoring (Barcelona). The geometry writes no
    `sectors`; the report reads the circuit as publishing no lines; the drawing
    places cars between lines by each sector's share of the time.

## 3. Keep the evidence, lay the geometry

```bash
nix run .#geometry -- survey <word> --fetch            # asks OSM, keeps circuits/<word>/overpass.json, writes nothing else
nix run .#geometry -- survey <word> --fetch --write    # additionally lays app/static/geometry/<word>.geojson
```

`--fetch` keeps the answer only once the survey can read it, so a kept
`overpass.json` is always re-runnable evidence — commit it beside the atlas
file. The `.geojson` is a served file, not a build artifact: commit it too.

To read a fresh survey against the old one, or the atlas line against either:

```bash
nix run .#geometry -- diff <a.geojson> <b.geojson> [--svg ...]
```

## 4. Spell the word on both wire copies

The word a summary sends and the word the report prints are two files that no
project compiles together:

- `backend/src/Motorsport/Circuit.flix` — enum case + `jsonValue`. Without
  this the calendar can name the round but no summary can send the circuit, and
  the round draws as the ring.
- `circuits/src/Motorsport/Circuit.flix` — the same enum and an *identical*
  `jsonValue` body. `circuits/test/check-sources.mjs` lays the two bodies
  together; editing one alone fails `.#geometry-test`.

## 5. Draw it app-side

- `package/src/Motorsport/Wec/Circuit/<Word>/Layout.elm` — `decoder` is
  `Geometry.decoder { lapLength = <published lap> }`; `layout` turns the
  geometry into a `Circuit.Layout` with its `timingLines` and its `lengths`.
  Measure `Full` against Le Mans's reference set as COTA's doc-comment does
  (the width-fit ratio), and hold it with a
  `package/tests/Motorsport/Wec/Circuit/<Word>/LayoutTest.elm` at that ratio.
  Pair it with `GeometryTest.elm` beside it — the served bytes read through
  the drawing, handed `TestHelpers/Survey/<Word>` (which `test-fixtures.mjs`
  writes, step 7) and driven through `SurveySuite`.
  A lap with no mini-sectors still fills those fields; nothing draws them.
- `app/src/Shared.elm` — add the word's arm to **both** `decoderFor` and
  `trackOf`. One list without the other is invisible to both compilers.
- If the circuit's lines are placed by time between lines, check
  `Tracker.Config.lapScale` covers the combination (the `ConfigTest` cases
  name the ones the catch-all holds).

## 6. The lists that name every circuit

These hold the circuits as written-down inventories rather than readings, so a
new circuit fails each of them by name until it joins:

- `circuits/test/TestSurvey.flix` — the refusal-message test carries the known
  words (`"no circuit is surveyed under 'monza': known are cota, le_mans"`).
- `circuits/test/TestRegenerate.flix` — the expected `drawn`/`words` lists over
  `Circuit.circuits()`.
- `circuits/test/TestTimingMap.flix` — `cases()` must name every case of the
  report's enum, and a test counts them.
- `app/tests/geometry-contract.spec.ts` — it reads the words out of the sources
  for the cross-checks, but one assertion freezes the whole inventory:
  `expect(drawnNames().sort()).toEqual([...])`.
- `AGENTS.md` and `circuits/README.md` state the count and the kinds as fact —
  "the three here are tagged differently", "Three circuits are drawn to their
  own shape". A new circuit changes those sentences and often adds a sentence
  of its own about the kind of timing map it authors.

## 7. Verify — in this order

| Command | What it catches |
| --- | --- |
| `nix run .#geometry-test` | the project's readings off fixtures; the two `jsonValue` bodies laid together; the source facts no `@Test` can see |
| `nix run .#geometry -- survey <word>` | byte fence: the served file must come back identical, run with **no** `--write` — a metre on a different digit is a drawing that moved |
| `nix run .#geometry -- regenerate` | property fence over *every* kept answer — a new config must not move another circuit |
| `nix run .#test` | add `{ module: "<Word>", file: "<word>.geojson" }` to `app/scripts/test-fixtures.mjs`'s list first, or the package's tests fail to compile by name; then Elm tests + verify-examples |
| `nix run .#test-vrt` | `geometry-contract.spec.ts` reads the words out of `Shared.elm`, `backend/src/Motorsport/Circuit.flix` and the served file — three lists, one word — plus the inventory assertion of step 6 |
| `nix run .#update-snapshots-ci` | only once a new drawing is in: every tracker baseline stands on these degrees. Never land a macOS baseline with `.#update-snapshots-vrt` |

A survey that moved an *existing* circuit's bytes is its own change: it takes a
VRT re-baseline with it, and the move is measured in metres by `-- diff` before
anyone reads the pixels.

## 8. If a round joins with it

- Add the round to `Motorsport.Calendar` first, put the CSV at
  `data/wec/<season>/<id>.csv`, then `nix run .#cli-run` (or `.#cli-load` /
  `.#cli-export`). The summary carries `track.circuit`; a kept round's files
  are committed, the rest are ignored.
- `nix run .#geometry-timing-lines -- <season>/<id> [--against <season>]`
  answers whether the lines stand where they stood. It refuses an
  `eachSeason` circuit by quoting the config's own reason — that is the
  expected answer there, not a failure.
- A round whose geometry was never laid reads as unnamed and draws as the
  ring; a `track.circuit` no `decoderFor` arm knows is the rename-on-one-side
  mistake the contract spec exists to catch.

## Hazards

- **A word renamed on one side alone** draws the round as the ring with
  nothing red: five places spell it (two Flix enums, two `Shared.elm` lists,
  the file and directory names) and only the contract spec reads across.
- **An Overpass proxy answers a timed-out request as 200 with an HTML page.**
  `Overpass.answered` is the one reading of what a service answered with;
  never add a second reading that asks only the status.
- **An unreadable file is a failure, not an absence.** New file-reading under
  `circuits/` branches via `Util/Files`' `exists`/`isDirectory` or reports via
  `Cli/Errors`; a discarded `Err(_)` fails `check-sources.mjs`.
- **The geometry files carry the ODbL attribution** in their own properties —
  keep the writer's `claims` list and the fence's exemption list answering to
  `TestRegenerate` if a property is added.
- Nothing Elm-side is generated from the geometry; if the drawing should not
  move, do not let a new survey touch a kept circuit's bytes.
