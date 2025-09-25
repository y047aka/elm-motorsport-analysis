# Technology Stack (Kiro Steering)

Inclusion: Always

Updated: 2025-09-25

## Architecture Overview
- Monorepo with npm workspaces: `app` (Elm UI), `package` (shared Elm code/bench), `review` (elm-review config), plus a Rust workspace under `cli` (`cli` binary and `motorsport` library).
- Data flow: CSV files → Rust CLI parses and computes → JSON (`metadata.json`, `*_laps.json`) → Elm app decodes and renders.
- Dev environment is defined via `.devcontainer` for reproducible toolchains (Node 22, Rust, Elm, Codex CLI, Claude CLI).

## Frontend (Elm + elm-pages + Vite)
- Elm version: 0.19.1 (see `app/elm.json`).
- Elm library: `dillonkearns/elm-pages` 10.x for routing and data workflows in Elm code.
- Node CLI: `elm-pages` (npm) present in devcontainer; `app/elm-pages.config.mjs` configures Vite and head tags.
- Build tooling: Vite 6.x, Tailwind CSS 4.x (`@tailwindcss/cli`), DaisyUI (via CDN in head tags).
- Commands (from root):
  - `npm run start` → `npm run -w app start` → `elm-pages dev`.
  - `npm run build` → `npm run -w app build` → `elm-pages build`.
- Styling: `app/style.css` and generated `app/output.css`; Tailwind v4 CLI is used.

## CLI / Backend (Rust)
- Rust edition: 2024 (see `cli/Cargo.toml`).
- Workspace members: `cli` (binary), `motorsport` (library with domain types: `Car`, `Driver`, `Lap`, etc.).
- Dependencies: `serde`, `serde_json`, `csv`.
- Binary entry: `cli/cli/src/main.rs` uses `Config::build(args)` and runs `cli::run(config)`.
- Features:
  - Accepts a file or directory input.
  - Auto-generates default output file name and event id from input path.
  - For each CSV input, writes `<name>.json` (metadata) and `<name>_laps.json` (laps).
- Example usage:
  - `cargo run -p cli -- ./cli/test_data.csv` (writes `./cli/test_data.json` and `./cli/test_data_laps.json`).
  - Provide a custom output: `cargo run -p cli -- ./cli/test_data.csv --output ./out.json`.
- Tests: integration tests in `cli/cli/tests/integration.rs` validate JSON schemas and fields.

## Development Environment
- Devcontainer (`.devcontainer/devcontainer.json` & `Dockerfile`):
  - Node 22, global installs for Elm toolchain (`elm`, `elm-format`, `elm-test`, `elm-review`, `elm-verify-examples`, `elm-pages`).
  - Rust toolchain via devcontainer feature; `rust-analyzer` extension pinned.
  - Codex CLI and Claude Code CLI installed globally.
  - `postCreateCommand`: `npm install --ignore-scripts && elm --version && rustc --version`.
- Editor tooling: VS Code extensions for Elm and Rust configured.

## Common Commands
- Root package.json scripts:
  - `start` → run Elm app dev server.
  - `build` → build Elm app.
  - `test` → run tests in `package` workspace (Elm tests).
  - `benchmark` → run Elm benchmarks in `package/benchmark`.
- Rust:
  - `cargo run -p cli -- <path|dir> [--output <file>]`.
  - `cargo test -p cli` (or workspace-wide `cargo test`).

## Environment Variables
- None required for default CLI or app flows.
- Devcontainer sets `PATH` to include user-local bin; no fixed ports configured here.

## Ports
- Vite dev server uses its default port unless overridden; repo does not pin a port.
- No backend server process; CLI is offline/local.

## Data Contracts (High-Level)
- Metadata JSON structure:
  - `name: string` (mapped pretty name from event id)
  - `startingGrid: Array<{ position: number, car: { class, group, team, manufacturer, drivers: Driver[] } }>`
  - `timelineEvents: Array<TimelineEvent>` (computed from laps)
- Laps JSON structure (per record):
  - Keys include: `carNumber`, `driverNumber`, `lapNumber`, `lapTime`, `lapImprovement`, `crossingFinishLineInPit`, `s1`, `s1Improvement`, `s2`, `s2Improvement`, `s3`, `s3Improvement`, `kph`, `elapsed`, `hour`, `topSpeed`, `driverName`, `pitTime`, `class`, `group`, `team`, `manufacturer`.
  - Note: time values are serialized to strings by helpers (e.g., `duration::to_string`).

## Third-Party & Tooling
- Lint/format: Biome, elm-format.
- Quality gates: elm-review; Rust tests (unit + integration).
- CSS: Tailwind 4.x (CLI), DaisyUI.

## Notes / Gaps To Revisit
- Extend `map_event_name` in Rust for additional events when needed.
- If the app should consume JSON via HTTP, introduce a small static hosting doc (currently not present).

