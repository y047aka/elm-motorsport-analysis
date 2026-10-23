# circuits

The geometry pipeline: OpenStreetMap's map data in, a GeoJSON per circuit out,
and one directory per circuit — its config, the Overpass answer the geometry
was written from, and the atlas reading measured against it. The
commands are the flake's — `nix run .#geometry-write -- <circuit>`,
`.#geometry-probe`, `.#geometry-atlas`, `.#geometry-diff`,
`.#geometry-regenerate`, `.#geometry-timing-lines`. What follows is what no
single script's header says for itself; what a script can say at its own call
site, its header says there and is not repeated here.

OpenStreetMap data is © OpenStreetMap contributors, under the ODbL; every
geometry and module here is a derivative of it, and the written files carry the
source relation and the license in their own properties.

## One pipeline, one thin config per circuit

`circuit-geometry.ts` is the pipeline, and a circuit joins it as a directory
named by the word the summaries send for it. Its `circuit.ts` supplies the
relation, the member role naming the line the lap is measured from, the
published length the surveyed line is stretched to, and the prose the geometry
file is documented with. What it writes is not a build artifact but a served
one: the app reads `app/static/geometry/<word>.geojson` at load, through
`Motorsport.Wec.Circuit.Geometry`, which re-runs the pipeline's checks on the
bytes as they arrive, and the `Layout` module beside it holds what the file
cannot know — the drawing's lengths and timing lines. Nothing generates Elm
from the geometry.

A run asks OpenStreetMap, which answers a busy runner with a 502, a 504 or
something that is not JSON; a run walks a second runner before it fails, and a
failure past both is a survey to repeat later — or to hand in as a file.

## The fence

The Elm tests cannot hold a survey: the pipeline stretches whatever degrees it
gets to the circuit's published lap length whatever the degrees say, so a point
moved 20 m passes every Elm test and leaves the tracker's pixels where they
were. `.#geometry-regenerate` holds it instead, re-running the pipeline over
each circuit's kept Overpass answer — kept in the circuit's own directory —
and failing unless it reproduces the kept geometry, every fenced property
exactly. `surveyed_at` is the one exempt property: it stamps which answer a
file was written from rather than what the drawing is made of, and it is the
one property a live regeneration must move while every degree stands still.

A regeneration is read as a diff, and a survey that moved by metres goes to
`update-snapshots-ci` with it, since every tracker baseline is drawn on those
degrees.

## What the bytes are kept to

Every surveyed point is held in the degrees OpenStreetMap gives it, with how
far round the lap it stands, and `Circuit/Layout` projects those degrees into
the drawing through the `Circuit.Geodesy.Frame` the generator writes beside
them — to the tenth of a metre the survey is kept to, which is the tenth every
VRT baseline was rendered at. The frame's origin is the north-west corner of
the survey, so the drawing never falls below its own zero, and a test holds
every projected place clear of the half-tenth its rounding turns on — measured
before the rounding, since a rounded place is clear of every boundary by
construction. The tightest place stands 113 micrometres clear at Le Mans and
39 at COTA, which is what lets the metres be projected rather than written
down. Every circuit's generator writes the same frame, out of the parallel it
scales east-west at and the north-west corner of what it surveyed, and adds
nothing to `Circuit/`.

## Authoring a circuit

Which relation a circuit is before any config says is `nix run
.#geometry-probe`, which prints the circuit relations at a place on earth with
each one's unroled ways measured — the length is what tells the full Sarthe
circuit from the Grand Prix circuit standing beside it.

OpenStreetMap holds a circuit however whoever mapped it tagged it, and the two
here are tagged differently: Le Mans's relation names one node `start-finish`,
and COTA's names two, 297 m apart along the lap. A circuit's config carries
the timing line's published coordinates, so a run that answers the wrong role
fails before it writes anything rather than drawing every car early; how each
relation is actually tagged is the circuit's own config comment to say.

## The timing lines, and where their distances come from

Le Mans's timing lines are the "Approximate Distances" of Al Kamel's circuit
map for that race, and differ by season; the maps are not to be redistributed,
so they are not in the repository. COTA's are its own track sector map's, and
are one set used for every season here, since no later map has been read.
Nothing in a round's own times picks one placement of those lines out of
another — a sector's share of a lap is not a share of its distance, and every
placement has a mean speed of its own — so what they rest on is that the
circuit published them as the lines it times to, beside the lap length they
add up to.

What the times can answer is whether the lines have moved, and `nix run
.#geometry-timing-lines -- 2026/cota_6h --against 2025` reads that: each
class's fastest sector times as two distances round the lap, and the two
rounds here agree within half a percent of a lap — the only evidence there is
that one map serves both. The command judges the season-to-season difference
and never the shares against the map, and prints whether the export in the
tree counts the same shares.

The geometry publishes what the circuit itself publishes about its lines: the
authored stretches travel in the geometry as `sectors`, so the check reads the
geometry file rather than the config behind it. How the drawing places a line the map gives
no distance for is app-side — `Tracker.Config.lapScale`, and the `ConfigTest`
combinations that hold it.

## The atlas readings

`nix run .#geometry-atlas <circuit>` reads the track-atlas line — a midline
measured from orthoimagery, not a survey stretched to a published length, at
5,500.2 m against the 5,515 m this app draws — and keeps it as
`<circuit>/atlas.geojson` with `stretched: false`, beside the survey it is
judged against rather than in what gets served. For a circuit this repository
has not surveyed yet, the atlas's `start_finish` point is a surveyed
coordinate to seed a circuit config's `timingLine` with; whether the lines the
times are read against stand where the seeded line puts them is
`check-timing-lines.ts`'s to answer, once a round has been loaded.

`nix run .#geometry-diff` lays any two kept geometries against each other —
mean and maximum apartness, and an SVG overlay on request — so a fresh survey
is read against the old one, or the atlas line against either, with no script
in between. Neither writes Elm: drawing on a measured line would move every
tracker baseline and re-open where the timing lines stand, which is its own
change judged on that report.

## The readings, and their tests

Every tool is two things: the asking, and the reading of an answer. The asking —
Overpass, the atlas layer, a CSV, a geometry file — stays in the command; the
reading moved into a module beside it that opens nothing. `timing-feed.ts` turns
the feed's text into rows, fastest sectors, shares and implied lines;
`circuit-candidates.ts` says which tags could name a circuit and what an answer's
roles measure; `atlas-line.ts` holds the atlas file's shape checks and its two
guards — the one that keeps a mismatched line out, and the one that keeps the lap
starting at the published line; `geometry-drift.ts` compares two geometries the
way the fence does; and `circuit-geometry.ts` asks nothing until `main` is told
to. `nix run .#geometry-test` runs Node's own test runner over `circuits/tests/`,
where those readings are handed fixtures rather than surveys. What is judged
against the repository's real bytes stays this file's other sections': the fence,
the contract specs, the VRT.

## Where the app reads this

The geometries are kept because the app reads them, and as the line other
datasets are measured against. A drawn circuit is two lists in `Shared` — the
words `trackOf` matches and `decoderFor` decodes — and a geometry file at
`app/static/geometry/<word>.geojson`, and `app/tests/geometry-contract.spec.ts`
keeps all three in step, since none of them compiles against another — and
pins that the circuit's directory under this one is named by that same word.
`app/tests/circuit-contract.spec.ts` pins the word the summaries send for a
circuit against the word `Shared.trackOf` picks a drawing by; a rename on one
side alone would leave a round drawn as the ring with nothing red.
