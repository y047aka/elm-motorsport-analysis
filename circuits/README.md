# circuits

The geometry pipeline: OpenStreetMap's map data in, a GeoJSON per circuit out,
and one directory per circuit — the Overpass answer the geometry was written
from and the atlas line measured against it, kept beside the config that
surveyed them. The
commands are the flake's — one app for the pipeline, taking the word it runs:
`nix run .#geometry -- survey <circuit> [--fetch] [--write]`, `-- atlas
<circuit>`, `-- diff <a.geojson> <b.geojson>`, `--
regenerate` — beside `.#geometry-timing-lines`, and
`.#geometry-test` for the project's tests. The pipeline itself is the
Flix project at this directory's root: it asks OpenStreetMap, surveys a circuit
out of an answer, and writes the file the app serves. Its `-- probe` word is
the same question OpenStreetMap answers, asked before a circuit has a config to
author; its `-- timing-lines` word is the timing report, reading
the feed the load reads with the decoder the load decodes it with.
What follows is what no
single module's header says for itself; what a module can say at its own call
site, its header says there and is not repeated here.

OpenStreetMap data is © OpenStreetMap contributors, under the ODbL; every
geometry and module here is a derivative of it, and the written files carry the
source relation and the license in their own properties.

## One pipeline, one thin config per circuit

A circuit joins as a record in `src/Circuit.flix` — the relation, the member
role naming the line the lap is measured from, the published length the
surveyed line is stretched to, the prose the geometry file is documented with —
and as a directory named by the word the summaries send for it, which keeps
only the evidence: the kept Overpass answer and, where one has been measured,
the kept atlas line. What it writes is not a build artifact but a served
one: the app reads `app/static/geometry/<word>.geojson` at load, through
`Motorsport.Wec.Circuit.Geometry`, which re-runs the pipeline's checks on the
bytes as they arrive, and the `Layout` module beside it holds what the file
cannot know — the drawing's lengths and timing lines. Nothing generates Elm
from the geometry.

## The fence

The Elm tests cannot hold a survey: the pipeline stretches whatever degrees it
gets to the circuit's published lap length whatever the degrees say, so a point
moved 20 m passes every Elm test and leaves the tracker's pixels where they
were. `.#geometry -- regenerate` holds it instead, re-running the pipeline over
each circuit's kept Overpass answer — kept in the circuit's own directory —
and failing unless it reproduces the kept geometry, every fenced property
exactly and `surveyed_at` alone exempt.

A regeneration is read as a diff of the geometry itself — `nix run
.#geometry -- diff` lays the moved file against the kept one and prints the
metres between them. A survey that moved by metres then takes a re-baseline
of the tracker's VRT with it, since every tracker baseline is drawn on those
degrees — but the size of a move is measured on the GeoJSON, and the pixels
only follow it.

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
.#geometry -- probe`, which prints the circuit relations at a place on earth with
each one's unroled ways measured — the length is what tells the full Sarthe
circuit from the Grand Prix circuit standing beside it. It asks two questions:
which relations the box holds and how each is tagged, then, for the ones whose
tags could name a circuit, its ways with their geometry, which is the only
answer a role's length can be measured out of. The box a run opened is printed
back, since a centre widened to 5 km holds Le Mans's Grand Prix circuit and not
the 13.6 km one.

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
and never the shares against the map. The export is confirmed where
it is written — `.#cli-run` reads its own integrity checks back out of the rows
it wrote the export from.

The geometry publishes what the circuit itself publishes about its lines: the
authored stretches travel in the geometry as `sectors`, which is what the
drawing places its cars between. The report reads the same figures from
`Motorsport.Circuit.timingMap` rather than from the geometry, because what the
report answers is a season against another season, which no geometry file
holds — reading the served bytes would make the report's input whatever a
survey happened to lay down. So a circuit's published lap length and stretches are held twice, in
the circuit's config and in `Motorsport.Circuit`, one for the drawing and one
for the report, and `test/TestTimingMap.flix` lays the two copies together —
it runs under `nix run .#geometry-test`, in the one project that compiles both,
and fails a stretch moved on either side by name. What is not answerable this
way is where a place the shares imply stands against the drawn line itself —
that is `.#geometry -- regenerate`'s and `-- diff`'s to say, measuring the
geometry rather than a season. It is how COTA's second line was found standing
6.7 m off the circuit's own map, which is how far a round whose two seasons agree
to within 40 m can still be drawn wrong by. How the drawing places a line the map
gives no distance for is app-side — `Tracker.Config.lapScale`, and the
`ConfigTest` combinations that hold it.

## The report, and the nine links it reads through

The report is a word of the pipeline, not a project: `src/Report.flix` reads the
arguments and `Main.flix` hands the word over, and
`src/Cli/TimingLines.flix` with its `Feed.flix` reads the two feeds and prints.
Nothing compiled here can name a database: no `Db` effect among the project's
sources, no argument flag for one, and no JDBC driver resolved.

Nine sources are symlinks into `flix/src`: the decoding of a CSV
(`Util/Csv/`), the durations, `Motorsport/`'s `Circuit.flix`, `Events.flix` and
`Calendar.flix`, and the parent stubs `Cli.flix`, `Motorsport.flix` and
`Util/Csv.flix`, which are compiled because Flix will not enter a module whose
parent it has never seen. Compiled twice, held once.

**A link compiles every function a module holds for the few one command calls,**
and the links are held to that rate. What the report reads through is linked; what
belongs to the commands that compute in a database is held again on this side,
smaller. `Cli/Errors.flix` keeps four of the CLI's seven cases — a directory that is
not there, a directory that is not one, a file that would not open, and a feed that
could not be decoded — beside a fifth the CLI holds no failure like: what a reading
found wrong with the data it was handed, which no command that computes in a
database fails into. `Report/Files.flix` is the report's own file reading: read and
stat, neither writing, making a directory nor globbing — the project's own
`Util/Files.flix` resolves every path from `GEOMETRY_FROM` and writes, and the two
are named apart because they resolve apart. Of the
three cases this side drops — an empty file, a round no run loaded, a database's
failure — only the last asked for a source of its own, and `Db.flix` is reached
from no call in this project.

Two of the links are called at one point each and stay links for that: `Calendar.find`
is what refuses a round the calendar does not list, and the calendar's rounds are the
thing the report cannot hold a second copy of; `Events.circuit` says which ground a
round was run on, which is the word the export sends and the drawing matches —
a copy here would be a second table with one reader.

So the two `Cli.Errors` — the CLI's and this project's smaller one — are each
compiled from their own file. What they keep in common is a
wording: one bad `--csv` is answered in the same words at either command.

**A symlink per file, never one per directory.** Flix's source walker does not
descend a symlinked directory: one link at `src/Util` compiles as nothing and fails
as `Undefined use 'Util.Csv.Decode'`, reported in the module that needed the link
rather than in the link itself. Copies are no easier for what is shared: Flix has no
local path dependency, answering anything but `github:username/projectname` with a
format error, and `flix build` takes no source directory as an argument — so a shared
`Util.Csv.Decode` is a shared file, not a second copy of its 552 lines. Per-file
links also leave each shared source visible in `git ls-files -s` as mode `120000`.

`nix run .#geometry-test` runs the project's own `flix test`, and `.#flix-test`
compiles the same nine files on the link's other side, which is what proves the
links survived the checkout as well as
that the readings are right — a link that broke fails the run that reads
through it, as `Undefined use` in the module that needed it. Nothing walks the
links, or the full set of sources the project compiles, from outside it; the
sharing, the `flix.toml` and the flake's apps are reviewed by reading them.

## The probe is a word of the pipeline

`-- probe` opens no file at all — it asks something of a network rather than of
a database: `src/Probe.flix` reads the arguments and prints,
`src/Overpass/Query.flix` spells the two questions it asks, `src/Overpass.flix`
walks the runners, `src/Overpass/Answer.flix` gives what comes back the shape of
an answer, and `src/Candidates.flix` reads an answer already got — which tags
could name a circuit, and what a relation's roles measure. `nix run .#geometry-test` runs their `flix test`, which
is the only way a probe is testable at all: the asking is one call
and the reading is a fixture, and the tests are given fixtures.

**One asking, two answers.** Which runners there are, what a run calls
itself, and how long one that just failed is left alone are facts about
OpenStreetMap, and `Overpass.flix` spells them once, walking the probe's
question and the pipeline's through the same runners. What a service
*answered with* is the same one reading for both, and that reading — beside
the sphere `Geodesy.earthMetres` that every metre is measured on — is held to
one spelling by `test/check-sources.mjs`, since an `@Test` can build no
`HttpResponse` and meets no source file. What nothing compares is the app's
own number, in `Motorsport.Circuit.Geodesy`: neither compiler reaches into
the other project's sources, and a Geodesy on another sphere lays a drawing
whose metres are not the survey's.

## The pipeline is the project at this directory's root

The geometry pipeline is the Flix package at `circuits/`, one module per reading
named in the sections above, with `src/Main.flix` holding the words the commands go
by and `src/Cli/Args.flix` the exit code each of them comes to. It resolves no dependency and
links no source — it reads nothing `flix/src` holds, which is what the report's nine links
are for — so no `Db` effect is compiled into it and no JDBC driver is resolved for it.

**What is written once, and what is written twice.** The pipeline is written once: the
asking of two paths, the report and the overlay are `Diff.flix`'s; the comparison of two
lines is `Apart.flix`'s, which the diff samples and the atlas reading samples; the atlas
file's shapes and guards are `Track.flix`'s; the survey of an answer, the reading of a
kept file and the bytes a geometry is written in are `Survey.flix`, `Geometry.flix` and
`Geometry/Write.flix`, each one the only spelling; the chain from an answer's text to a
surveyed geometry is `Survey.geometry`'s, asked whole by the live survey, by the
guard a fetched answer passes before it is kept, and by the regeneration fence,
so all three fail in one reading's words — and so is the asking of
OpenStreetMap, `Overpass.flix` one spelling of the runners for the survey's
question and the probe's alike, and of the sentence a transport failure is
printed in. The ground those readings are taken on is `Geodesy.flix` alone — the
radius, the parallel two lines are laid on, the projection that keeps `y` south, the
north-west corner a drawing is measured from, the metres a line accumulates from its
own zero and the tenth a distance is kept to — which the survey, the probe, the atlas
reading and the diff all read and none of them holds. So are the three questions
asked of OpenStreetMap, spelled one each in `Overpass/Query.flix`, and the answer
they come back as, read in `Overpass/Answer.flix`: the shape of an element is known
in one place, so the `--fetch`ed answer and the kept one are read alike and a
question cannot drift from the reading that works it.

What is written twice is the timing
figures, authored in `src/Circuit.flix` for the drawing and held again in the linked
`Motorsport.Circuit` for a run that reads no geometry, laid together by
`test/TestTimingMap.flix`.

`nix run .#geometry -- survey cota` reads `circuits/cota/overpass.json`, finds the relation by
the role naming the line the lap is timed from, chains the ways into a closed lap and a pit
lane, stretches the surveyed length to the published one, thins it at a metre, and answers
whether what it would write is the file the app serves; `--write` writes it. The
network is a flag and not a word: `--fetch` asks OpenStreetMap now, keeps the answer
at `--answer` or beside the circuit — and keeps it only once the survey can read it,
since an answer that surveys nothing is evidence nobody can re-run — and then travels
on through exactly the survey a kept answer travels through. Keeping an answer is
`--fetch`'s alone and laying the geometry is `--write`'s alone, so a `--fetch` with no
`--write` keeps the fresh evidence and then answers, writing nothing else, whether the
fresh survey moves the served bytes. CI runs the
comparison for both circuits and never passes `--write`: a fence that rewrites
what it fences passes by construction. The wiring around the project — the
sources it holds, what it resolves, the flake apps that reach it, the directory
a reader's paths resolve against — is everything a Flix test run from inside
the project cannot see, and nothing reads it from outside either; it is judged
by reading `flake.nix` and `.github/workflows/test.yml`.

**A byte comparison and a property comparison, kept because they answer different
questions.** `-- survey` without `--write` compares bytes; the regeneration fence
compares parsed properties with `surveyed_at` exempt, because asking OpenStreetMap now takes a
newer survey while every degree stands still. The byte comparison needs no such exemption — it
reads the very answer whose stamp the property carries, so the stamp it would write is the stamp
it reads — and a metre that lands on a different digit is a drawing that moved. The
fence's list of compared properties is the writer's own list (`Geometry.Write.claims`) less that
one exemption, so a claim added to the profile is asked of both files at its own place
in a drift line rather than in the unordered tail everything unnamed falls into; the
two directions — every claim the writer lays is fenced or exempt, and every name in
the fence's list is a claim the writer lays — are `TestRegenerate`'s.

**The layout of the repository is said once, in `Circuit.flix`.** The evidence
directory, the served directory, and the names a circuit's own directory keeps its
evidence under are functions there, and the warning that lists kept files answering
no circuit reads them from those functions rather than naming the files again — a
name spelled a second time beside the writer of one of those files is a directory the
warning stops calling out, and a fence that stays green. A circuit's own geometry path
stays authored in its config, the way its timing figures are authored twice; what
holds it to the word the app reaches for is `TestCircuit`.

**Its runner changes directory, and says so.** `flix` has to start inside the project to
find its `flix.toml`, and a reader names `app/static/geometry/le_mans.geojson` from
outside it, so the flake exports `GEOMETRY_FROM` as the directory the command was asked
from and `Util/Files.flix` resolves every path there. Rename the variable in either
place and every path a reader types is a file not found, with the name they typed in the
message. `nix run .#geometry-test` runs the project's own `flix test`, every reading
being handed a fixture rather than a file — an Overpass answer written out in the test that
reads it, two geometries laid together in the test that measures them.

**A file that will not read is a failure, and not an absence.** A run of this project meets
a file one of two ways. It *branches* — deciding a circuit was never surveyed — or it
only *reports*, printing what the filesystem said with the path beside it.
`Cli/Errors.flix` is the reporting and `Util/Files.flix` holds the branching
questions, `exists` and `isDirectory`, a stat that answers nothing being a
failure rather than the `false` that ends a walk quietly. Before either was
askable, runs answered a read's failure by deciding there was nothing there,
and the fence was among them: an unreadable kept answer was a circuit "not
surveyed yet", and a served directory that would not list was a warning with
nothing to say, both of them exit 0. `test/check-sources.mjs` holds that
shape — one discarded-failure arm left in the project, on a parse refusal
another reading said first — because no test of this project ever meets a
file.

## The atlas readings

`nix run .#geometry -- atlas <circuit>` is the geometry project's own: `Track.flix`
reads the foreign file's shapes and refuses what they contradict, `Atlas.flix`
reads the layer and asks its home only on `--fetch`, and the apartness is the
diff's `Apart.flix` sampling the same pair of lines. It reads the track-atlas
line — a midline measured from orthoimagery, not a survey stretched to a
published length, at 5,500.2 m against the 5,515 m this app draws — and keeps
it as `<circuit>/atlas.geojson` with `stretched: false`, beside the survey it
is judged against rather than in what gets served. For a circuit this
repository has not surveyed yet, the atlas's `start_finish` point is a
surveyed coordinate to seed a config's `timingLine` with; whether the lines
the times are read against stand where the seeded line puts them is `nix run
.#geometry-timing-lines`'s to answer, once a round has been loaded.

`nix run .#geometry -- diff` lays any two kept geometries against each other —
mean and maximum apartness, and an SVG overlay on request — so a fresh survey
is read against the old one, or the atlas line against either, with no script
in between. Neither writes Elm: drawing on a measured line would move every
tracker baseline and re-open where the timing lines stand, which is its own
change judged on that report. The diff and the atlas reading are the project at
this directory's root, and both sample `Apart.flix`.

## The readings, and their tests

Every tool is two things: the asking, and the reading of an answer. The asking —
Overpass, the atlas layer, a CSV, a geometry file — stays in the command; the reading
moved into a module beside it that opens nothing, so `nix run .#geometry-test` can
hand it a fixture: `Cli.TimingLines.Feed` turns feed text into rows, fastest sectors,
shares and implied lines; `Candidates.flix` reads a probe answer; `Survey.flix` chains
a kept answer and is held to the bytes the app serves rather than by a shared source, and
is where the `survey` word asks — the asking of a circuit sits with the reading of one, as
it does for the atlas;
`Geometry.flix` is the one reader of every kept file, and `Geometry/Write.flix` the one
writer of them — the outline's layout, the property list and the JSON spelling, with no
asking in it at all, which is what lets the `survey` word, the regeneration fence and the
atlas line be written by one profile rather than by whichever command got there first;
`Track.flix` holds the atlas
file's shape checks and its two guards; and the comparison the fence makes is
`Regenerate.flix`'s. Nothing asks OpenStreetMap from outside this project at all.
Printing stays with the command — what a reading is worth is what it
answers, not how its table is padded. The exit code is the one thing no reading
decides for itself: every command is `arguments` over its own flag table and `asking`
over its own readings, and `Cli.Args.comeTo` is the only place either of the two
becomes a code. A reading hands back a `Result` and the run they add up to hands back
an `Outcome`, of which `Verdict` — the drawing moved, one line moved a season later —
is the negative answer the reader came for and is said on stdout at 1, while `Failed`
is a run that never got to answer and is said on stderr. `--help` is a value in that
`Parsed` rather than a printing, which is why `TestUsage.flix` can read the answering
at all: which of its three answers a run of tokens comes to is asserted there, and
nothing is run. The one test handed no fixture reads none on
purpose: `TestTimingMap` lays the two authored copies of a circuit's timing figures
together, and the real authors are what it is given. What is judged
against the repository's real bytes stays this file's other sections': the fence,
the contract specs, the VRT.

## Where the app reads this

The geometries are kept because the app reads them, and as the line other
datasets are measured against. A drawn circuit is two lists in `Shared` — the
words `trackOf` matches and `decoderFor` decodes — and a geometry file at
`app/static/geometry/<word>.geojson`, and `app/tests/geometry-contract.spec.ts`
reads the served file against those words: that it stands where the app reaches
for it, and that the circuit's directory under this one is named by that same
word. Whether the file's own contents are honest — metres ascending and ending
at the published lap, sectors adding up to it, a pit lane beside it — is a
refusal of `Geometry.outline` and `Geometry.pitLane`, pinned by `TestGeometry`
and re-asked of the real bytes by the byte fence on every CI run. Which words the two Elm lists hold, and which word
the Flix summary sends, nothing compares — no compiler reaches from one side
of that seam to the other, and a rename on one side alone is a round drawn as
the ring with nothing red.
The figures the report reads — the published lap length and sector stretches —
and the figures the drawing was laid from are laid together by
`test/TestTimingMap.flix`, in the one project that compiles both. What of the
sharing is left to read from outside it is the report's own file reading, and
`test/check-sources.mjs` holds that to reading and stat: it writes
nothing. What the asking leaves outside the project's own readings — which sources
read a response, and which sentences a failed answer is printed in — is
`test/check-sources.mjs`'s, held to one source.
