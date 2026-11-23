---
name: add-circuit
description: "Add a new circuit's data end to end: read its official circuit map into a served map record, probe OpenStreetMap for its relation, author its circuits config, keep the Overpass answer, lay the served geometry, join the word on both wire copies, draw it app-side, and run every fence that judges the result. Also the steps for a circuit whose map is re-issued. Use when asked to add, survey, or draw a new circuit, when a new round's circuit has no geometry yet, or when a newer circuit map arrives for a circuit already here."
---

# Add a circuit

A circuit is one word, spelled in places no compiler reaches from one to the other, and two served files the app reads by that word: its map record and its geometry.
`circuits/README.md` says *why* each part is what it is; this says *what to run, in what order, and what catches you when you skip a step*.

The word is the stem the round ids share (`fuji_6h` → `fuji`), snake_case.
It names the map record, the evidence directory, the served geometry, and the arm the app matches on.
Choose it before anything else.

Run every command below from the repository root: the flake exports `GEOMETRY_FROM` as the directory the command was asked from, and every path here is relative to it.

## 1. Write the map record — `app/static/circuit-maps/<word>.json`

The record is the one place the lap and its lines are written: the survey stretches the lap to it, the geometry carries its stretches, the report reads it, and the app checks the geometry against it.
Write it before surveying; `survey` and `regenerate` read it and fail without it.

Read the series' circuit map (the PDF stays out of the repository) into the shape the other records keep; `circuits/README.md`'s maps section says what each part holds.
What the code reads, and so must be right:

- `season` — the season of the map.
- `lengths.centerline.metres` — the lap the survey is stretched to and the geometry is checked against.
- `lines.intermediate1.metres` and `lines.intermediate2.metres` — both or neither: both imply the three stretches; neither leaves the circuit publishing no lines, and the app has no layout for that yet (`Map.intermediatesDecoder` requires both).

Every figure is written twice, as `metres` and as the map printed it.
Before going on, check by hand what no reader checks: each `printed` figure reads as its `metres`, and Lap by Pits comes back from the centreline, Pit In, Pit Out and the pit lane — a miss is recorded in the README, not corrected.
The lines' order is checked by both readers: a record whose lines do not run 0 < i1 < i2 < centreline is refused.

## 2. Probe before authoring

```bash
nix run .#geometry -- probe <lat>,<lon> [--radius <km>]
```

Prints each candidate relation with its roles' ways measured.
The length is what tells the full circuit from the GP circuit standing beside it; the default 5 km box holds COTA and not a 13.6 km one — widen it for long circuits.
The report is for a human, not for a name: read it before writing a config, and note how the relation tags its start/finish line — no two of the kept circuits tag it alike.

**When the probe comes back empty,** OpenStreetMap holds that circuit as loose `highway=raceway` ways rather than a relation — Fuji is mapped that way.
Author the box grounding instead: `relation = None`, a `box` around the ground, and a `timingLine` at the line's place.
`survey <word> --fetch` reads the ground and names every refusal by way id: author the box loosely and let the refusals tell you what else the box holds.

## 3. Author the config — `circuits/src/Circuit.flix`

Add one `def <word>(): Circuit` and append it to `circuits()`.
Its doc-comment is where *how the relation is actually tagged*, and where its line's place came from, belong.

- `relation` / `box` / `pit` — exactly one grounding: the relation the ways are named by, or the box whose raceway ways are chained by standing at the line. A box at a racing complex may hang more than one line off the lap, and the survey reads geometry and one-way tags rather than any way's `name`; `pit` names the pit lane's ways by id then, as a relation's members do.
- `timedFrom` — the relation member naming the line the lap is timed across; every metre is measured from it. Leave it `""` where the relation tags no member at the finish line (Monza's roles name the pit-exit light): the lap is then turned at `timingLine`'s place, as a box's is.
- `timingLine` — the finish line's place (and the `within` the survey may allow). With a `timedFrom` it checks the tagged node; without one it *is* the zero.

**The finish line's place.** The map gives every distance from its finish line and none of its degrees.
Check a tagged line against the map's Start Line Offset: the relation's `start` node should stand that far after `finish` (Barcelona 127 m against 128, COTA 296.6 against 297).
Where nothing tags the line, the place is read off the map's drawing laid over the survey, its drawn lines read against their printed distances; Monza's and Fuji's config comments say how, and that it is good to some 20 m.
A place taken off OpenStreetMap or a third-party dataset checks the survey against nothing but itself — say so in the comment.

## 4. Keep the evidence, lay the geometry

```bash
nix run .#geometry -- survey <word> --fetch            # asks OSM, keeps circuits/<word>/overpass.json, writes nothing else
nix run .#geometry -- survey <word> --fetch --write    # additionally lays app/static/geometry/<word>.geojson
```

Commit the kept answer and the `.geojson`: the first is re-runnable evidence, the second a served file.
To read a fresh survey against the old one: `nix run .#geometry -- diff <a.geojson> <b.geojson> [--svg ...]`.

## 5. Spell the word on both wire copies

- `backend/src/Motorsport/Circuit.flix` — enum case + `jsonValue`. Without it no summary can send the circuit, and the round draws as the ring.
- `circuits/src/Motorsport/Circuit.flix` — the same enum and an *identical* `jsonValue` body; `check-sources.mjs` lays the two together.

## 6. Draw it app-side

- `package/src/Motorsport/Wec/Circuit/<Word>/Layout.elm` — `decoder : Map.Intermediates -> Decoder Geometry` is `Geometry.decoder { lapLength = map.centreline }`; `layout` turns the map and the geometry into a `Circuit.Layout`, its `timingLines` from `map.intermediate1` and `map.intermediate2`. Copy Barcelona's. Measure `Full` against Le Mans's reference set as COTA's doc-comment does (the width-fit ratio). A drawing that needs more lines than the two takes a map record of its own, as Le Mans's `CircuitMap` does, held in order through `Map.inOrder`.
- `app/src/Shared.elm` — add the word's arm to `drawingFor`, naming the map decoder, the geometry decoder and the layout.
- `app/scripts/test-fixtures.mjs` — add `Survey.<Word>` and `Map.<Word>` to its list.
- `package/tests/Motorsport/Wec/Circuit/CircuitsTest.elm` — add the circuit's row: its name, the box it stands in, and its map record and geometry read as `Shared` reads them. **Nothing fails without the row**: it is what runs `SurveySuite` over the served bytes and holds every length at the ratio.
- If the circuit's lines are placed by time between lines, check `Tracker.Config.lapScale` covers the combination (the `ConfigTest` cases name the ones the catch-all holds).

## 7. The lists that name every circuit

These freeze the inventory, so a new circuit fails each by name until it joins:

- `circuits/test/TestSurvey.flix` — the `known are …` refusal message.
- `circuits/test/TestRegenerate.flix` — the `drawn`/`words` lists over `Circuit.circuits()`.
- `circuits/test/TestTimingMap.flix` — `cases()` names every case of the report's enum, and a test counts them.
- `app/tests/geometry-contract.spec.ts` — `expect(drawnNames().sort()).toEqual([...])`.

## 8. Verify — in this order

| Command | What it catches |
| --- | --- |
| `nix run .#geometry-test` | the project's readings off fixtures; the two `jsonValue` bodies laid together; the source facts no `@Test` can see |
| `nix run .#geometry -- survey <word>` | byte fence: the served file must come back identical, run with **no** `--write` |
| `nix run .#geometry -- regenerate` | property fence over *every* kept answer and map record — a new circuit must not move another |
| `nix run .#test` | the map record and geometry decoded as the app decodes them, and the circuit's `CircuitsTest` row |
| `nix run .#test-vrt` | `geometry-contract.spec.ts`: every word `drawingFor` matches is one Flix sends, with both served files behind it, plus the inventory of step 7 |
| `nix run .#update-snapshots-ci` | only once a new drawing is in a kept round's view — the `vrt` skill says how a baseline lands |

## 9. If a round joins with it

- Registering the round is `/skill:add-round`'s; the summary then carries `track.circuit`.
- `nix run .#geometry-timing-lines -- <season>/<id> [--against <season>]` reads the round's sector times against the record's lines, and a second season against the first.

## A newer map for a circuit already here

1. Replace the record's figures, `season` and `issued` with the new map's, and check them as in step 1.
2. `nix run .#geometry -- regenerate <word> --write` re-lays the geometry on the new lap and stretches; commit both files together. A record changed alone is a geometry the app's decoder refuses: the round fails to load.
3. `nix run .#geometry-timing-lines -- <season>/<id> --against <previous season>` says whether the lines moved further than one map can answer for.
4. `nix run .#test`, then `nix run .#test-vrt`; a kept round drawn on this circuit takes a re-baseline through `.#update-snapshots-ci`.

## Hazards

- **A word renamed on one side alone** draws the round as the ring with nothing red: the two Flix enums, `drawingFor`, the map record, the geometry and the evidence directory all spell it, and only the contract spec reads across.
- **An Overpass proxy answers a timed-out request as 200 with an HTML page.** `Overpass.answered` is the one reading of what a service answered with; never add a second reading that asks only the status.
- **An unreadable file is a failure, not an absence.** New file-reading under `circuits/` branches via `Util/Files`' `exists`/`isDirectory` or reports via `Cli/Errors`; a discarded `Err(_)` fails `check-sources.mjs`.
- **The geometry files carry the ODbL attribution** in their own properties — keep the writer's `claims` list and the fence's exemption list answering to `TestRegenerate` if a property is added.
- **A survey that moves an existing circuit's bytes is its own change**: it takes a VRT re-baseline with it, and the move is measured in metres by `-- diff` before anyone reads the pixels.
