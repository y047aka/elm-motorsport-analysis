# CLAUDE.md

Motorsport race analysis and visualization app. pnpm workspaces monorepo:

- **`/app`** — Elm SPA, bundled by Vite (Tailwind CSS 4 + elm-css)
- **`/package`** — reusable Elm library (motorsport domain models)
- **`/cli`** — Rust CLI for CSV→JSON data processing

Data flow: CSV telemetry → Rust CLI → JSON → Elm visualization.

## Commands

All commands run through the Nix flake; `nix flake show` lists everything.

| Command | Purpose |
| --- | --- |
| `nix run .#dev` | Vite dev server (localhost:1234) |
| `nix run .#build` | Production build |
| `nix run .#test` | elm-verify-examples + elm-test |
| `nix run .#test-vrt` | Playwright VRT |
| `nix run .#update-snapshots-vrt` | Update VRT snapshots |
| `nix run .#review-app` / `.#review-package` | elm-review |
| `nix run .#format` | elm-format |
| `nix run .#cli-build` / `.#cli-test` / `.#cli-run` | Rust CLI build / test / CSV→JSON |
| `nix run .#tauri-dev` / `.#tauri-build` | Tauri v2 native app (`app/src-tauri`) |
| `nix run .#flix-build` / `.#flix-test` / `.#deps-audit` | Flix helpers for `/update-deps` |

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
- `Css/` (Color, Palette, Typography), `Data/` (series config), `UI/` (Button, Label, Table)

**`/package/src/Motorsport/`** — domain models (`Car`, `Driver`, `Lap`, `Gap`),
`Race/` for the loaded race, its indices, and readings of it at a moment
(`Snapshot`, `LapHistory`), `Widget/` and `Chart/` for rendering (Leaderboard,
GapChart, BoxPlot).

There is no view-model layer between the two. `Race.Snapshot` is the whole of
the per-frame derivation — sampling the cars at the clock, ordering the field,
measuring the gaps, rating the times against the records as they stood — and
views read a `CarAt` straight off it. Colours and geometry are the view's own:
a widget that wants a class's colour calls `Class.toColor` itself.

`Snapshot.at` is called once per frame and every view of that frame shares the
result. That sharing is the only reason the type exists; measured against
building a record per car on top of it, the record cost under 2% of the frame
(`benchmark/PerFrameBenchmark.elm`), which is why there is no layer above.

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

So `BestTimes.Snapshot` and `Race.Snapshot` are the same idea applied twice, not
a name collision — the records at a moment, and the field at a moment. They are
always written qualified, which is what keeps them apart at the call site.

A module that hands out only the frozen form may name it for what it holds
instead (`LapHistory`); one that holds both names them for the difference
(`BestTimes.Changes` spans the race, `BestTimes.Snapshot` is one moment of it).
Either way it is `at` that applies the clock.

## Testing

- **Elm** — `elm-test` for unit tests, `elm-verify-examples` for docstring examples.
  Benchmarks live in `/package/benchmark/`.
- **VRT** (`/app/tests/`) — local runs allow 1% pixel tolerance for cross-platform
  diffs; CI (ubuntu-latest) is strict 0. Update snapshots locally, or trigger the
  workflow_dispatch in CI to auto-push to the branch.

## Environment

Nix flake provides the reproducible dev environment (Node.js 26, Rust toolchain).
Use `direnv allow` or `nix develop`.

## Permissions

`.claude/settings.json` follows one rule: **allow broadly, then carve out the
destructive flags with `ask`** — `ask` wins over `allow`, so `Bash(git branch:*)`
can stay open while `-D` still prompts. Before adding a narrow `allow` entry, check
whether a broader one plus an `ask` carve-out covers it; that keeps read-only flags
(`--show-current`, `-r`, ...) from silently falling through to a prompt. `deny` is
reserved for the genuinely irreversible: force push, publish, `sudo`, secret files.

Read/Grep/Glob are preferred over `cat`/`grep`/`find` in Bash — only the tool-level
rules can enforce the secret-file `deny` entries, which Bash bypasses.
