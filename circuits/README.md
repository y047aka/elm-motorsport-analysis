# circuits

The geometry pipeline: OpenStreetMap's map data in, a GeoJSON per circuit out,
and one directory per circuit — its config, the Overpass answer the geometry
was written from, and the atlas reading measured against it. The
commands are the flake's — `nix run .#geometry-write -- <circuit>`,
`.#geometry-probe`, `.#geometry-atlas`, `.#geometry-diff`,
`.#geometry-regenerate`, `.#geometry-timing-lines`. Everything here is
TypeScript but one directory: `circuits/timing/`, the timing-lines report, is a
Flix project of its own, reading the feed the load reads with the decoder the
load decodes it with. What follows is what no
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
are one set used for every season here, since no later map has been read. Which
of the two a circuit's map is belongs to its config, as its `sectors` — one set
`published` for every season, or `perSeason` — and `nix run
.#geometry-timing-lines` refuses a round on the second kind by quoting the
circuit's own reason. Nothing in a
round's own times picks one placement of those lines out of
another — a sector's share of a lap is not a share of its distance, and every
placement has a mean speed of its own — so what they rest on is that the
circuit published them as the lines it times to, beside the lap length they
add up to.

What the times can answer is whether the lines have moved, and `nix run
.#geometry-timing-lines -- 2026/cota_6h --against 2025` reads that: each
class's fastest sector times as two distances round the lap, and the two
rounds here agree within half a percent of a lap — the only evidence there is
that one map serves both. The command judges the season-to-season difference
and never the shares against the map. An older check printed whether the export
in the tree counted the same shares as the feed; that print is gone with the
report's move to Flix, which parses no JSON, and the export is confirmed where
it is written — `.#cli-run` reads its own integrity checks back out of the rows
it wrote the export from.

The geometry publishes what the circuit itself publishes about its lines: the
authored stretches travel in the geometry as `sectors`, which is what the
drawing places its cars between. The report reads the same figures from
`Motorsport.Circuit.timingMap` rather than from the geometry, because a report
that laid a place the times imply against the surveyed shape would need a JSON
reader and this project has none — `Util.Json.Encode` writes and parses
nothing. So a circuit's published lap length and stretches are held twice, in
the circuit's config and in `Motorsport.Circuit`, one for the drawing and one
for the report, and `app/tests/circuit-timing-map.spec.ts` reads both sources
and fails them apart; nothing else connects them. What is not answerable this
way is where a place the shares imply stands against the drawn line itself —
that is `.#geometry-regenerate`'s and `.#geometry-diff`'s to say, measuring the
geometry rather than a season. It is how COTA's second line was found standing
6.7 m off the circuit's own map, which is how far a round whose two seasons agree
to within 40 m can still be drawn wrong by. How the drawing places a line the map
gives no distance for is app-side — `Tracker.Config.lapScale`, and the
`ConfigTest` combinations that hold it.

## The report is a project of its own

`circuits/timing/` is a second Flix package: `flix.toml` with no Maven dependency,
`src/Report.flix` reading the arguments, `src/Main.flix` handing them over, and
`src/Cli/TimingLines.flix` with its `Feed.flix` reading the two feeds and printing.
Nothing compiled into it can name a database: no `Db` effect among its sources, no
argument flag for one, and no JDBC driver resolved.

Nine of its sources are symlinks into `flix/src`: the decoding of a CSV
(`Util/Csv/`), the durations, `Motorsport/`'s `Circuit.flix`, `Events.flix` and
`Calendar.flix`, and the parent stubs `Cli.flix`, `Motorsport.flix` and
`Util/Csv.flix`, which are compiled because Flix will not enter a module whose
parent it has never seen. Compiled twice, held once.

**A link compiles every function a module holds for the few one command calls,** and
the two projects divide at that rate. What the report reads through is linked; what
belongs to the commands that compute in a database is held again on this side,
smaller. `Cli/Errors.flix` keeps five of the CLI's eight cases — a feed that could
not be decoded, a directory that is not there, a directory that is not one, and what
the feed said about itself — and `Util/Files.flix` three of its six functions, the
three that read and stat, neither writing, making a directory nor globbing. Of the
three cases this side drops — an empty file, a round no run loaded, a database's
failure — only the last asked for a source of its own: `Db.flix`, three effects, ten
functions and three enums, reached from no call.
`Util/Csv/Decode/Extra.flix` was linked on the same reading and answered to nothing
at all, `traverse` being what `Motorsport.Wec.decoder` uses and no reading of a
timing feed.

Two of the links are called at one point each and stay links for that: `Calendar.find`
is what refuses a round the calendar does not list, and the calendar's rounds are the
thing the report cannot hold a second copy of; `Events.circuit` says which ground a
round was run on, which is the word the export sends and the drawing matches, and
`app/tests/circuit-contract.spec.ts` reads it out of `flix/src` — a copy here would
be a second table with one reader.

So `Cli.Errors` and `Util.Files` are each two modules of one name, one per project,
each compiled from its own file. What the two `Cli.Errors` keep in common is a
wording: one bad `--csv` is answered in the same words at either command.

**A symlink per file, never one per directory.** Flix's source walker does not
descend a symlinked directory: one link at `src/Util` compiles as nothing and fails
as `Undefined use 'Util.Csv.Decode'`, reported in the module that needed the link
rather than in the link itself. Copies are no easier for what is shared: Flix has no
local path dependency, answering anything but `github:username/projectname` with a
format error, and `flix build` takes no source directory as an argument — so a shared
`Util.Csv.Decode` is a shared file, not a second copy of its 552 lines. Per-file
links also leave each shared source visible in `git ls-files -s` as mode `120000`.

`nix run .#geometry-timing-test` runs that package's own `flix test`, beside
`.#flix-test` in CI, which is what proves the links survived the checkout as well as
that the readings are right. `app/tests/circuit-timing-map.spec.ts` pins that every
link resolves to the `flix/src` file of the same relative path, names the sources this
directory holds itself, and reads every source the report compiles — every link
dereferenced — for the words a database is named by.

## The atlas readings

`nix run .#geometry-atlas <circuit>` reads the track-atlas line — a midline
measured from orthoimagery, not a survey stretched to a published length, at
5,500.2 m against the 5,515 m this app draws — and keeps it as
`<circuit>/atlas.geojson` with `stretched: false`, beside the survey it is
judged against rather than in what gets served. For a circuit this repository
has not surveyed yet, the atlas's `start_finish` point is a surveyed
coordinate to seed a circuit config's `timingLine` with; whether the lines the
times are read against stand where the seeded line puts them is `nix run
.#geometry-timing-lines`'s to answer, once a round has been loaded.

`nix run .#geometry-diff` lays any two kept geometries against each other —
mean and maximum apartness, and an SVG overlay on request — so a fresh survey
is read against the old one, or the atlas line against either, with no script
in between. Neither writes Elm: drawing on a measured line would move every
tracker baseline and re-open where the timing lines stand, which is its own
change judged on that report.

## The readings, and their tests

Every tool is two things: the asking, and the reading of an answer. The asking —
Overpass, the atlas layer, a CSV, a geometry file — stays in the command; the
reading moved into a module beside it that opens nothing. `Cli.TimingLines.Feed`
in the report's own project turns the feed's text into rows, fastest sectors,
shares and implied lines, and is tested by `nix run .#geometry-timing-test`
rather than here; the reading of a CSV is one reading and the load's
`Util.Csv.Decode` is the other half of it, which is why the report is written
where the feed is already read;
`circuit-candidates.ts` says which tags could name a circuit and what an answer's
roles measure; `geometry-file.ts` holds the profile's own reading — the outline
with its own metres going up, and the pit lane beside it — which the
`--from-geojson` check, the diff and the atlas reading all run, so what the
fence checks and what the diff lays together are one reading of a file;
`atlas-line.ts` holds the atlas file's shape checks and its two
guards — the one that keeps a mismatched line out, and the one that keeps the lap
starting at the published line; `geometry-drift.ts` compares two geometries
the way the fence does; and `circuit-geometry.ts` asks nothing until `main` is
told to. Printing stays with the command — what a reading is worth is what it
answers, not how its table is padded. `nix run .#geometry-test` runs Node's own test runner over `circuits/tests/`,
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
`app/tests/circuit-timing-map.spec.ts` pins the figures the report reads — the
published lap length and sector stretches — against the figures the drawing was
laid from, which are held in two languages and compiled against nothing.
