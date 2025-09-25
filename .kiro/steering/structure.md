# Project Structure (Kiro Steering)

Inclusion: Always

Updated: 2025-09-25

## Root Directory Organization
- `.kiro/steering/` — Steering docs (product/tech/structure). Always loaded for AI.
- `.kiro/specs/` — Feature specs and phase artifacts (init/requirements/design/tasks).
- `.codex/prompts/` — Slash-command prompts for Kiro workflow (spec/steering).
- `app/` — Elm application (elm-pages + Vite), UI and decoders.
- `package/` — Shared Elm code, tests, and benchmarks used by the app.
- `review/` — elm-review rules/config for linting Elm code.
- `cli/` — Rust workspace with `cli` (bin) and `motorsport` (lib) crates.
- `.devcontainer/` — Reproducible development environment setup.
- `package.json` — Workspace scripts (start/build/test/benchmark).

## Subdirectory Details
### `app/`
- `src/` — Elm modules.
  - `Data/` — Decoders and domain preprocessors (F1/FormulaE/WEC, lap/timeline models).
  - `UI/` — UI components (e.g., tables/visualizations/styles).
- `elm.json` — Elm app config (includes `../package/src` as a source directory).
- `elm-pages.config.mjs` — Vite + headTags config.
- `index.ts` — Elm app bootstrap (`ElmPagesInit`).
- `custom-backend-task.ts` — Example custom task hook.
- `functions/` — Server-like tasks (if used by elm-pages).
- `style.css` / `output.css` — Tailwind/DaisyUI styling artifacts.

### `package/`
- `src/` — Shared Elm modules (visualizations/utilities) used by `app`.
- `elm.json` — Elm application used for shared code and benchmarks.
- `benchmark/` — Elm benchmarking assets.
- `fixture/` — Sample data used by benchmarks/tests.

### `review/`
- `src/` — elm-review configuration and custom rules.
- `elm.json` — Config for elm-review app.

### `cli/`
- `cli/src/` — Binary entry and orchestration:
  - `main.rs` — Parses CLI args and runs.
  - `config.rs` — CLI arg parsing, auto naming of output/event.
  - `preprocess.rs` — CSV parsing + domain preprocessing (grouping laps etc.).
  - `output.rs` — JSON shape (metadata/laps) and serializers.
- `cli/tests/integration.rs` — End-to-end tests for CSV→JSON output.
- `motorsport/src/` — Domain types (`Car`, `Driver`, `Lap`, `MetaData`, etc.).
- `Cargo.toml` / `Cargo.lock` — Rust workspace configuration.

## Code Organization Patterns
- Strongly-typed pipeline: Rust domain → JSON → Elm decoders.
- Shared Elm code is surfaced to the app by including `../package/src` in `app/elm.json`.
- Integration tests verify the JSON schema fields expected by the Elm decoders.

## File Naming Conventions
- Rust: `snake_case.rs` modules; tests in `tests/`.
- Elm: `PascalCase.elm` modules under `src/`.
- Generated outputs: `<input>.json` (metadata), `<input>_laps.json` (laps).

## Import/Dependency Conventions
- Rust crates use workspace dependencies (`serde`, `serde_json`) and internal crate `motorsport`.
- Elm uses `elm-pages` (Elm lib) and visualization libraries; decoders in `Data/*` mirror CLI JSON.
- Node/npm handles workspace orchestration and tooling (Biome, elm-format, Tailwind CLI).

## Architectural Principles
- Type-first design across Rust and Elm.
- Reproducible development via devcontainer and workspace scripts.
- Additive documentation: deprecations are marked, not deleted.

## Extending The System
- New event types: add mapping in Rust `map_event_name` and supporting decoders in Elm `Data/*`.
- New CSV formats: implement parsing in `preprocess.rs` and update integration tests.
- New UI views: add Elm modules under `UI/` and wire into pages.

