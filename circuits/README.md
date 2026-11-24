# circuits

The geometry pipeline: OpenStreetMap's map data in, a GeoJSON per circuit out, and one directory per circuit keeping the evidence — the Overpass answer the geometry was written from, and where a circuit has them, the heights its places were sampled at.
It is the Flix project at this directory's root, run through the flake: `.#geometry -- <word>`, `.#geometry-timing-lines` and `.#geometry-test`, whose words `AGENTS.md`'s table lists.
`-- probe` asks OpenStreetMap before a circuit has a config; `-- timing-lines` reads the timing feed with the decoder the load decodes it with.
Each module's header says what it reads and refuses; what follows is what crosses them.

OpenStreetMap data is © OpenStreetMap contributors, under the ODbL; every geometry and module here is a derivative of it, and the written files carry the source relation and the license in their own properties.

## One pipeline, one thin config per circuit

A circuit joins as a record in `src/Circuit.flix` — the relation, or a box of raceway ground where OpenStreetMap tags no relation, the member role naming the line the lap is measured from, and the timing line's published coordinates — as a map record at `app/static/circuit-maps/<word>.json`, whose centreline is the length the surveyed line is stretched to, and as a directory named by the word the summaries send for it.
How each circuit is actually tagged is its config comment's to say.
A relation may list ground under no role that the lap no longer runs — Imola's bypassed Variante Bassa chicane — and `bypassed` names those ways by id, as `pit` names the pit lane's; a chain that walked the lap and the bypassed chicane both would have to split a way.
The config's timing-line coordinates are what make a run answering the wrong role fail before it writes anything, rather than drawing every car early.

What the pipeline writes is a served file, not a build artifact: the app reads `app/static/geometry/<word>.geojson` through `Motorsport.Wec.Circuit.Geometry`, which re-runs the pipeline's checks on the bytes, and the `Layout` module beside it holds what the file cannot know — the drawing's lengths — and lays the timing lines the map record gives. Nothing generates Elm from the geometry.

The steps of adding a circuit are `/skill:add-circuit`'s.

## The fence

The Elm tests cannot hold a survey: the pipeline stretches whatever degrees it gets to the published lap length, so a point moved 20 m passes every Elm test and leaves the tracker's pixels where they were.
`.#geometry -- regenerate` holds it instead, re-running the pipeline over each circuit's kept Overpass answer and failing unless it reproduces the kept geometry, every fenced property exactly and `surveyed_at` alone exempt.
CI runs that comparison for every circuit and never passes `--write`: a fence that rewrites what it fences passes by construction.

The fence's property list is the writer's own (`Geometry.Write.claims`) less that one exemption; `TestRegenerate` holds both directions — every claim the writer lays is fenced or exempt, and every fenced name is a claim the writer lays.

A regeneration is read with `.#geometry -- diff`, which lays the moved file against the kept one in metres.
A survey that moved takes a re-baseline of the tracker's VRT with it, since every tracker baseline is drawn on those degrees; the size of a move is measured on the GeoJSON, and the pixels only follow it.

`--fetch` asks OpenStreetMap now and keeps the answer only once the survey can read it — an answer that surveys nothing is evidence nobody can re-run. Keeping an answer is `--fetch`'s alone and laying the geometry `--write`'s alone, so `--fetch` without `--write` answers whether a fresh survey moves the served bytes and writes nothing else.

## What the bytes are kept to

Every surveyed point is held in OpenStreetMap's degrees with how far round the lap it stands, and `Circuit/Layout` projects them through the `Circuit.Geodesy.Frame` written beside them, to the tenth of a metre every VRT baseline was rendered at.
The frame's origin is the survey's north-west corner, so the drawing never falls below zero.
A test holds every projected place clear of the half-tenth its rounding turns on, measured before the rounding; the tightest stands 42 micrometres clear at Le Mans and 3 at COTA, which is what lets the metres be projected rather than written down.

`Motorsport.Circuit.Geodesy` re-runs this project's projection app-side, and nothing compares the two: a Geodesy on another sphere lays a drawing whose metres are not the survey's.

## The timing lines, and where their distances come from

Every circuit's timing lines are the "Approximate Distances" of the series' circuit map, and every season is read on the latest map's record (the maps section below).
Le Mans's organiser re-issues its map every season and moves its lines by a few metres, and `--against` finds the 2024 and 2025 rounds' lines within 30 m of the 2026 map's.

Nothing in a round's times picks one placement of the lines out of another — a sector's share of a lap is not a share of its distance — so what they rest on is that the circuit published them.
What the times can answer is whether the lines moved: `nix run .#geometry-timing-lines -- 2026/cota_6h --against 2025` is the only evidence one map serves both seasons.
Where a line stands against the drawn line itself is `regenerate`'s and `diff`'s to say.

A lap length and its stretches are written once, in the circuit's map record: `Circuit.figuresOf` reads them, the survey stretches the lap to the one, and the geometry carries the others as `sectors`. The report reads the record rather than the geometry, because it answers a season against another season, which no geometry file holds.
`test/TestTimingMap.flix` reads the derivation, and the regeneration fence reads the real records, which no `@Test` can.
How the drawing places a line the map gives no distance for is app-side: `Tracker.Config.lapScale`.

## The maps' figures, kept as read

`app/static/circuit-maps/<word>.json` is what the latest of the series' circuit maps prints, read off it by hand; the PDF stays out of the repository, since the maps are not to be redistributed, and the record keeps the season, the date the map was issued and the circuit's full name.
It is served beside the geometry because the app reads it too: `Shared` asks for a circuit's record before its geometry, and checks the geometry against the record's centreline. A new map replaces the record, and the geometry is re-laid from it with `regenerate --write`.
Both readers refuse a record whose lines do not stand in the order a car reaches them, every one before the finish line closes the lap: `Circuit.figuresOf` here, and the map decoders in `Motorsport.Wec.Circuit.Map` app-side.
A map gives its finish line no degrees, so where OpenStreetMap tags none at the line the authored place is read off the map's drawing laid over the survey; the config of each such circuit (Monza, Fuji) says how, and how near. Where the relation tags its own line, the map's Start Line Offset is its own check on the reading: the two nodes should stand that far apart along the lap, as São Paulo's tagged `start` and `finish` do at 60.04 m against the map's 60.2 m, as Barcelona's and COTA's tagged pair do at 127 against 128 and 296.6 against 297, and as the node behind Spa's lone `start` node does at 123.9 against 122.
A lone `start` node is not always the map's Start Line — Imola's is its finish line, with the map's Start Line and Pit Out falling 210 m and 228 m after it against the 218 m and 222.8 m the map prints — so which of the two a lone `start` names is the map's drawing's to say, and the config comment records it.
Every figure is kept twice, as `metres` and as the map printed it, because the print carries the precision the map was written to (0.01 m at Le Mans, whole metres elsewhere) and its decimal comma.
`lengths` and `lines` hold only what the map gives a distance for, every line measured from the finish line; `drawn` names what it draws without one, and lists such as Le Mans's timing loops are kept in the map's own order.
`sectors` and Le Mans's `zones` are the stretches the map colours, each bounded by the drawn labels its colour changes at; a colour is sampled off the stretch's own label, since the shared template's labels print one colour on every map where its lines are rendered a little differently on each.
A map's figures need not agree with one another: Lap by Pits should be the centreline less the track between Pit In and Pit Out plus the pit lane, and 2026's Fuji map misses that by 9 m and Barcelona's by 5.2 m. São Paulo's 2026 map misses it by 3 m and Spa's by 48 m, and at Spa Pit In - Pit Out (386.6 m) is all but the track between its own Pit In and Pit Out lines (386.4 m); the record keeps what the map prints either way.

## The links into `backend/src`

Nothing compiled here can name a database: no `Db` effect, no flag for one, no JDBC driver.

Five sources are symlinks into `backend/src`: the durations, `Motorsport/`'s `Events.flix` and `Calendar.flix`, and the parent stubs `Cli.flix` and `Motorsport.flix`, compiled because Flix will not enter a module whose parent it has never seen.
The CSV decoding is not among them: it is `github:y047aka/csv`, named by both projects' `flix.toml`.
`Motorsport/Circuit.flix` is not among them either: the report holds its own copy — the same enum and `jsonValue` body the export sends — and `test/check-sources.mjs` is what lays the two copies together, since no project compiles both.

A link compiles every function a module holds, so only what the report reads through is linked; what the database commands need is held again here, smaller, in `Cli/Errors.flix` and `TimingLines/Files.flix`, whose headers say what they hold.
`Calendar.find` and `Events.circuit` are called once each and stay links: a copy of either would be a second calendar or a second table of circuit words.

**A symlink per file, never one per directory.** Flix's source walker does not descend a symlinked directory: one link at `src/Util` compiles as nothing and fails as an undefined name in the module that needed it.
Copies are no alternative: Flix has no local path dependency and `flix build` takes no source directory, so what two projects share is a symlinked file or a released package.
Per-file links show in `git ls-files -s` as mode `120000`.

`.#geometry-test` and `.#flix-test` compile the linked files on either side, which is what proves the links survived the checkout.

## The heights

`elevation <word> --fetch` samples the places a survey walks (`Elevation.placesOf`) from the source the circuit's config names, and keeps the source's own values as `circuits/<word>/elevation.json`.
The survey and the fence read them as they read the kept answer; how they are despiked, smoothed and thinned is `Survey.laidOut`'s, and a circuit keeping none is drawn without heights.

**São Paulo's source is a point cloud no service answers a place of**, so `--fetch` reads every one of the city's 5,544 LiDAR tiles' headers to find the few the lap stands on, then streams those through `laszip4j` (LGPL-2.1, the project's one Maven dependency) and keeps only the ground returns near a place; no tile is written to disk.
A height there is the median of the ground returns within 1 m of the place, or 1.5 m under a bridge, so it is read here rather than taken off a model; `resolution_m` says which radius.

**The samples are keyed by the degrees they were asked at.** An answer re-fetched with any node moved leaves that place unsampled, and the survey and the fence refuse the circuit until `elevation <word> --fetch` samples it again; re-fetching an answer and re-sampling it are one change.

**Sampling a circuit adds points to its drawing**: a crest or a dip on a line straight on the plan is a point the thinning keeps, so a circuit sampled again takes a re-baseline of its VRT with it.

## The probe, and OpenStreetMap's answers

`Overpass.flix` spells the runners and the backoff once, for the probe's question and the survey's alike; its `flix test` pins that only the survey asks for `node(w)`.
`Service.flix` spells a run's name, its pace and the reading of what a service answered with, for Overpass and the elevation sources alike.
**A proxy answers a timed-out request as 200 with an HTML page**, so that reading — beside `Geodesy.earthMetres` — is held to one spelling by `test/check-sources.mjs`: a second reading asking only the status would hand HTML on as a geometry.

## Wiring a test cannot see

The sources the project holds, what it resolves, the flake apps that reach it and the directory paths resolve against are invisible to a Flix test run from inside; they are judged by reading `flake.nix` and `.github/workflows/test.yml`.

**The runner changes directory.** `flix` must start inside the project to find its `flix.toml`, while a reader names paths from outside, so the flake exports `GEOMETRY_FROM` as the directory the command was asked from and `Util/Files.flix` resolves every path there. Rename the variable in either place and every typed path is a file not found.

**A file that will not read is a failure, not an absence.** `Util/Files.flix`'s `exists` and `isDirectory` answer a stat that answers nothing as a failure rather than `false`: an unreadable kept answer must not read as a circuit "not surveyed yet", nor an unlistable served directory as a warning with nothing to say, both of which would exit 0. `test/check-sources.mjs` holds that shape, because no test here meets a file.

**The repository's layout is said once, in `Circuit.flix`**: the evidence directory, the served directory and the names a circuit's directory keeps its evidence under. The warning listing kept files that answer no circuit reads those functions; a name spelled again beside a writer is a directory the warning stops calling out. `TestCircuit` holds a circuit's geometry path to the word the app reaches for.

**One place decides an exit code**: every command is `arguments` over its own flag table and `asking` over its readings, and `Cli.Args.comeTo` turns either into a code. A `Verdict` — the drawing moved, a line moved a season later — is the negative answer the reader came for, said on stdout at 1; `Failed` is a run that never got to answer, said on stderr.
`--help` is a value in `Parsed`, so `TestUsage.flix` asserts which answer a run of tokens comes to without running anything.

## The readings, and their tests

Every tool is the asking and the reading of an answer; the asking stays in the command, and the reading sits in a module that opens nothing, so `.#geometry-test` hands it a fixture.
`TestTimingMap` is the one test handed no fixture: it reads the derivation from the real configs.
What is judged against the repository's real bytes is the fence, the contract specs and the VRT.

## Where the app reads this

A drawn circuit is the list of words `Shared.drawingFor` matches, a map record at `app/static/circuit-maps/<word>.json` and a geometry at `app/static/geometry/<word>.geojson`.
`app/tests/geometry-contract.spec.ts` checks that both files stand where the app reaches for them and that the words are ones this directory and the Flix summary name.
Whether the file's contents are honest — metres ascending to the published lap, sectors adding up to it, a pit lane beside it, a height per point where it carries any — is `Geometry.outline`'s and `Geometry.pitLane`'s refusal, pinned by `TestGeometry` and re-asked of the real bytes by the fence on every CI run.
App-side, `Motorsport.Wec.Circuit.Geometry` refuses the same heights out of step, and `Tracker3d` draws them.
