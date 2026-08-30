# CLAUDE.md

Motorsport race analysis and visualization app. CSV telemetry → CLI →
JSON/JSONL → Elm visualization.

- **`/app`** — Elm SPA, bundled by Vite (Tailwind CSS 4 + shadcn/ui). The only npm
  project: it owns `package.json` and `pnpm-lock.yaml`, so pnpm runs as
  `pnpm -C app`.
- **`/package`** — reusable Elm library (motorsport domain models), reached
  through `elm.json`.
- **`/flix`** — the CLI for CSV→JSON/JSONL data processing, written in Flix.

There is no manifest at the repository root; the flake is what ties the three
together.

## Commands

All commands run through the Nix flake; `nix flake show` lists everything.

| Command | Purpose |
| --- | --- |
| `nix run .#dev` | Vite dev server (localhost:1234) |
| `nix run .#build` | Production build |
| `nix run .#test` | elm-verify-examples + elm-test |
| `nix run .#test-vrt` | Playwright VRT |
| `nix run .#update-snapshots-vrt` | Update VRT snapshots |
| `nix run .#benchmark` | Serve `/package/benchmark` (elm reactor) |
| `nix run .#review-app` / `.#review-package` | elm-review |
| `nix run .#format` | elm-format |
| `nix run .#cli-build` / `.#cli-test` / `.#cli-run` | CLI build / test / CSV→JSON/JSONL |
| `nix run .#tauri-dev` / `.#tauri-build` | Tauri v2 native app (`app/src-tauri`) |
| `nix run .#deps-audit` | Dependency audit helper for `/update-deps` |

Prefer these over invoking `pnpm` / `cargo` / `flix` directly — the flake pins
the toolchain and sets the working directory. The `cli-*` commands drive
`/flix`; there are no `flix-*` ones.

`.#cli-run` takes the directory holding the season directories and converts
every round `Motorsport.Calendar` lists, writing each round's summary `.json`
and its laps `.jsonl`, one lap per line, plus `index.json` beside them. **A new
round is added to `Motorsport.Calendar` first** — the run converts nothing the
calendar does not list, reports any CSV no round names, and fails any round
whose CSV is missing.

`/update-deps [npm|elm|rust|nix]` (Claude skill) audits and updates dependencies.

## Architecture

**`/app/src/`** — hand-written multi-page SPA on `Browser.application`
(framework-less; no elm-pages). `index.ts` boots `Elm.Main.init`; data is
fetched at runtime via `Http`.

- `Main.elm` — top-level Model/Msg, URL handling, page dispatch
- `Route.elm` — `Url.Parser` routes: `/`, `/debug`, `/wec/:season/:event`
- `Shared.elm` — app-wide state (race control, view model) + data loading
- `Effect.elm` — elm-spa-style effects (`sendCmd`, `sendSharedMsg`, `pushRoute`, ...)
- `Page/` — one module per page, plain TEA
- `Css/` (Color, Palette, Typography), `Data/` (feed decoding), `UI/` (Table,
  and `Shadcn/` for the wrappers)

`Data/Wec/Calendar.elm` decodes `index.json`, fetched once by `Shared`. It is
the app's only source for which rounds exist, what they are called and where
their files are — nothing app-side builds those paths, and a round it does not
list cannot be opened. `Data/Series.elm` is the remains of the compile-time
calendar it replaced: car images, which nothing imports yet.

`Data/Wec/Manufacturer.elm` decodes `/static/manufacturers.json` the same way,
also once, and a round waits on it as it waits on the calendar. That file is
written by hand and no compiler reads it, so a mistake in it shows as cars drawn
by their numbers rather than as a build that fails. Unlike an unlisted round, an
unnamed manufacturer stops nothing: the car keeps the name the feed gave it and
takes a colour from its number.

### The shadcn components

`app/src/shadcn/ui/` is vendored from shadcn's **`base-nova`** registry — Base
UI, not Radix. Each `app/src/shadcn/<name>-element.tsx` mounts one of them into
a custom element, `index.ts` registers them all, and
`app/src/UI/Shadcn/<Name>.elm` is the Elm side. The Elm wrappers hold no
Tailwind classes; the class strings are the vendored file's. `UI.Table` is what
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
`add` overwrites the file.

Every prop is set as a JS property, so what crosses the boundary is JSON and
Elm holds the state. Four things that boundary will not carry, all found by
running it rather than by building it:

- A property that arrives as `undefined` reads to React as "leave this
  uncontrolled", and the component then keeps a value beside the one Elm
  holds. Elm clears the value, the component goes on showing the old one, and
  nothing fails — so an element always passes a value, never a hole.
- React's synthetic events never reach a custom element's slotted children, so
  a component Elm passes children to cannot report its own clicks.
  `UI.Shadcn.Button` takes its label as a property for this reason.
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

`UI.Shadcn.Card` is the one wrapper with no React behind it. Card's classes
read the tree its content sits in — `has-data-[slot=card-footer]`,
`has-[>img:first-child]` — and content projected through a `<slot>` is not in
the shadow root's tree, so `card-elements.ts` puts the vendored class strings
on custom elements Elm fills directly. Nothing may pass one of those a `class`:
the element owns that attribute, and layout belongs on a wrapper around it.

What one of these costs, measured: mounting sixty-two of them takes ~26ms
against ~2ms for the same number of plain Elm nodes, about ten times, paid once
when the list appears. A reorder and an unrelated re-render cost nothing —
Elm does not re-assign a property whose value has not changed, so React is
never asked. Ten times a node it only lends class strings to is the reason
`UI.Shadcn.Card` mounts nothing.

**`/package/src/Motorsport/`** — domain models (`Car`, `Driver`, `Lap`, `Gap`),
`Race/` for the loaded race, its indices, and readings of it at a moment
(`Snapshot`, `LapHistory`), `Widget/` and `Chart/` for rendering (Leaderboard,
GapChart, BoxPlot).

`Wec/` holds the WEC-specific knowledge: the class grid and the eras it has
passed through (`Class`, `Era`), and Le Mans's mini-sectors
(`Circuit/LeMans`). Decoding the timing feed stays app-side in `Data.Wec` /
`Data.Wec.Laps` — the shape of one publisher's files, not of the domain.
`Data.Wec.Manufacturer` is app-side for the same reason: which manufacturers
there are, and how each is coloured and badged, is one series' entry list and
this application's assets. It holds none of them itself — it decodes the table
that does.

The names are sorted; the dependencies are not. The core imports out of `Wec/`
in three places: `Car.Metadata` holds a `Class`, `Lap.miniSectors` is fixed to
`Circuit/LeMans`'s type, and `Widget.Leaderboard` carries `*_Wec` and
`*_LeMans24h` columns beside the generic ones. Reversing that arrow is its own
change.

There is no view-model layer between the two. `Race.Snapshot` is the whole
per-frame derivation — sampling the cars at the clock, ordering the field,
measuring the gaps, rating the times against the records as they stood — and
views read a `CarAt` straight off it. Colours and geometry are the view's own: a
widget that wants a class's colour calls `Class.toColor` itself, and a
`Manufacturer` is read for the colour and logo it was built with. `Snapshot.at`
runs once per frame and every view shares that result, which is the only reason
the type exists; a record per car on top of it cost under 2% of the frame
(`benchmark/PerFrameBenchmark.elm`), so nothing sits above it.

Modules serving both sides sit directly under `Motorsport/` rather than in a
subdirectory — `BestTimes` is built by `Race` and read back by `Race.Snapshot`,
and `Lap.Performance` rates a lap for either side, so neither owns them.

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
- **VRT** (`/app/tests/`) — local runs allow a 0.1% pixel-ratio tolerance
  (`maxDiffPixelRatio: 0.001`) for cross-platform diffs; CI is strict 0. Update
  snapshots locally, or trigger the workflow_dispatch in CI to auto-push to the
  branch.

CI (ubuntu-24.04) runs the unit tests in `test.yml` and VRT in `playwright.yml`.
Snapshots are generated on Linux, so VRT failures on macOS are usually the
platform, not the change.

## Environment

Nix flake provides the reproducible dev environment (Node.js 26, and a Rust
toolchain for `app/src-tauri` — the repository's only Rust package). Enter it
with `nix develop`, or run one command in it with `nix develop --command <cmd>`,
which is what CI does. There is no direnv hook.

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
