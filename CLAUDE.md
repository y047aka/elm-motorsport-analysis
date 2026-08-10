# CLAUDE.md

Motorsport race analysis and visualization app. Three subprojects, each with the
manifest its own toolchain reads:

- **`/app`** — Elm SPA, bundled by Vite (Tailwind CSS 4 + elm-css)
- **`/package`** — reusable Elm library (motorsport domain models)
- **`/flix`** — the CLI for CSV→JSON data processing, written in Flix

Data flow: CSV telemetry → CLI → JSON → Elm visualization.

There is no manifest at the repository root: no `package.json`, no pnpm
workspace. `/app` is the only npm project and owns `package.json` and
`pnpm-lock.yaml`; `/package` is Elm-only and is reached through `elm.json`
alone; `/flix` has `flix.toml`. What ties them together is the flake, which is
also the only place that names a subproject's working directory — so a root
manifest would only be a second, weaker copy of that. Run pnpm with `-C app`
when the flake has no app for what you need.

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
| `nix run .#cli-build` / `.#cli-test` / `.#cli-run` | CLI build / test / CSV→JSON |
| `nix run .#tauri-dev` / `.#tauri-build` | Tauri v2 native app (`app/src-tauri`) |
| `nix run .#deps-audit` | Dependency audit helper for `/update-deps` |

The `cli-*` commands drive `/flix`; there are no `flix-*` ones. The CLI is one
thing with one set of names, and which language it is written in is not
something a caller should have to know.

`.#cli-run` takes the directory holding the season directories and converts
every round `Motorsport.Calendar` lists, writing each round's two JSON files
plus `index.json` beside them. **A new round is added to `Motorsport.Calendar`
first** — the run converts nothing the calendar does not list, reports any CSV
no round names, and fails any round whose CSV is missing.

`/update-deps [npm|elm|rust|nix]` (Claude skill) audits and updates dependencies.

Prefer these over invoking `pnpm` / `cargo` / `flix` directly — the flake pins the
toolchain and sets the working directory for each one.

## Architecture

**`/app/src/`** — hand-written multi-page SPA on `Browser.application` (framework-less;
no elm-pages). `index.ts` boots `Elm.Main.init`; data is fetched at runtime via `Http`.

- `Main.elm` — top-level Model/Msg, URL handling, page dispatch
- `Route.elm` — `Url.Parser` routes: `/`, `/debug`, `/wec/:season/:event`
- `Shared.elm` — app-wide state (race control, view model) + data loading
- `Effect.elm` — elm-spa-style effects (`sendCmd`, `sendSharedMsg`, `pushRoute`, ...)
- `Page/` — one module per page, plain TEA
- `Css/` (Color, Palette, Typography), `Data/` (feed decoding), `UI/` (Button, Label, Table)

`Data/Wec/Calendar.elm` decodes `index.json`, fetched once by `Shared`. It is
the app's only source for which rounds exist, what they are called and where
their files are — nothing app-side builds those paths, and a round it does not
list cannot be opened. `Data/Series.elm` is what is left of the compile-time
calendar it replaced: car images, which nothing imports yet.

**`/package/src/Motorsport/`** — domain models (`Car`, `Driver`, `Lap`, `Gap`),
`Race/` for the loaded race, its indices, and readings of it at a moment
(`Snapshot`, `LapHistory`), `Widget/` and `Chart/` for rendering (Leaderboard,
GapChart, BoxPlot).

`Wec/` holds the WEC-specific knowledge: the class grid and the eras it has
passed through (`Class`, `Era`), the manufacturers entering it (`Manufacturer`),
and Le Mans's mini-sectors (`Circuit/LeMans`). Decoding the timing feed stays
app-side in `Data.Wec` / `Data.Wec.Laps` — the shape of one publisher's files,
not of the domain.

The names are sorted; the dependencies are not. The core imports out of `Wec/`:
`Car.Metadata` holds a `Class` and a `Manufacturer`, `Lap.miniSectors` is fixed
to `Circuit/LeMans`'s type, and `Widget.Leaderboard` carries `*_Wec` and
`*_LeMans24h` columns beside the generic ones. Aggregating the modules made that
coupling visible rather than removing it; reversing the arrow is its own change.

There is no view-model layer between the two. `Race.Snapshot` is the whole
per-frame derivation — sampling the cars at the clock, ordering the field,
measuring the gaps, rating the times against the records as they stood — and
views read a `CarAt` straight off it. Colours and geometry are the view's own: a
widget that wants a class's colour calls `Class.toColor` itself.

`Snapshot.at` runs once per frame and every view shares the result; that sharing
is the only reason the type exists. A record per car on top of it cost under 2%
of the frame (`benchmark/PerFrameBenchmark.elm`), so there is no layer above.

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

`BestTimes.Snapshot` and `Race.Snapshot` are the same idea applied twice, not a
collision — the records at a moment, and the field at a moment; always written
qualified, which keeps them apart at the call site. A module handing out only
the frozen form may name it for what it holds instead (`LapHistory`); one
holding both names them for the difference (`BestTimes.Changes` spans the race,
`BestTimes.Snapshot` is one moment of it).

## Testing

- **Elm** — `elm-test` for unit tests, `elm-verify-examples` for docstring examples.
  Benchmarks live in `/package/benchmark/`.
- **VRT** (`/app/tests/`) — local runs allow 1% pixel tolerance for cross-platform
  diffs; CI (ubuntu-latest) is strict 0. Update snapshots locally, or trigger the
  workflow_dispatch in CI to auto-push to the branch.

## Environment

Nix flake provides the reproducible dev environment (Node.js 26, and a Rust
toolchain for `app/src-tauri` — the repository's only Rust package).

Enter it with `nix develop`, or run a single command in it with
`nix develop --command <cmd>` — which is what CI does. There is no direnv hook:
the shell is entered when it is wanted rather than on every `cd`, and the
`nix run .#*` commands carry their own toolchain and need no shell at all.

### GitHub CLI

`gh` is in the dev shell, so it is always reached through the shell:

```bash
nix develop --command gh pr list
```

It is deliberately not a `nix run .#*` app. `Bash(nix run .#:*)` is allowed as a
whole, so an app would make every `gh` subcommand allowed with it — including
merging and releasing. Behind `nix develop --command`, nothing is granted up
front and each subcommand is allowed on its own merits.

**Authentication is the user's own step**: run `gh auth login` yourself. The
flake supplies the binary, never the credentials, and no agent should perform
the login.

## Permissions

`.claude/settings.json` follows one rule: **allow broadly, then carve out the
destructive flags with `ask`** — `ask` wins over `allow`, so `Bash(git branch:*)`
can stay open while `-D` still prompts. Prefer a broad `allow` plus an `ask`
carve-out over a narrow `allow`, which leaves read-only flags (`--show-current`,
`-r`, ...) falling through to a prompt. `deny` is reserved for the irreversible:
force push, publish, `sudo`, secret files.

`gh` is the exception to "allow broadly", because its subcommands reach outside
the repository. What an agent may do unattended is listed rather than inherited:

- **read** — `pr view|list|diff|checks|status`, `issue view|list`,
  `run view|list|watch`, `repo view`, `search`, `auth status`, with any flags.
- **propose** — `pr create` and `pr edit`. Pushing a branch and opening the PR
  for it is one motion, and a PR is reviewed before it lands, so the prompt in
  the middle bought nothing.
- **everything else prompts**, by never being listed — including `pr merge`,
  which is the point at which the change becomes `main`, and `pr comment` /
  `issue comment`, which speak to people in the user's name.
- **denied outright** — `release create|delete`, `repo delete`, `secret`.

`gh api` stays `ask`: it reaches any endpoint with any method, so no prefix can
tell a read from a write.

Read/Grep/Glob are preferred over `cat`/`grep`/`find` in Bash — only the tool-level
rules can enforce the secret-file `deny` entries, which Bash bypasses.
