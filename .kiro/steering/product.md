# Product Overview (Kiro Steering)

Inclusion: Always

Updated: 2025-09-25

## What This Product Is
This repository is a monorepo for a motorsport race analysis toolkit combining:
- A Rust CLI that ingests lap timing CSVs and produces JSON outputs (event metadata and per-lap data).
- An Elm web application (via elm-pages + Vite) that visualizes results for F1/Formula E/WEC style data.
- Shared Elm code and developer tooling to enable spec-driven development with Codex CLI (Kiro workflow).

The goal is a type-safe, reproducible pipeline from raw timing data to interactive visualizations.

## Core Features
- CSV → JSON processing (Rust CLI)
  - Accepts a file or directory of CSVs; recursively processes directories.
  - Auto-derives default output file name (`<input>.json`) and event id from the input path.
  - Writes 2 files per input: `metadata` (event name, starting grid, timeline events) and `laps` (per-lap records).
  - Laps JSON fields include (based on code): `carNumber`, `driverNumber`, `lapNumber`, `lapTime`, `lapImprovement`, `crossingFinishLineInPit`, `s1`, `s1Improvement`, `s2`, `s2Improvement`, `s3`, `s3Improvement`, `kph`, `elapsed`, `hour`, `topSpeed`, `driverName`, `pitTime`, `class`, `group`, `team`, `manufacturer`.
  - Metadata JSON includes: `name` (mapped from event id), `startingGrid` (position + car meta), `timelineEvents` (computed from car/lap data).

- Web visualization (Elm app)
  - Uses `elm-pages` (Elm library) with Vite integration for a fast dev/build pipeline.
  - Data decoders and preprocessors for F1, Formula E, and WEC data models.
  - Tailwind CSS v4 and DaisyUI for styling, plus additional Elm visualization libraries.

- Developer experience
  - npm workspaces (`app`, `package`, `review`) with shared tooling (Biome, Elm, elm-format).
  - Devcontainer sets up Node 22, Rust, Elm, Codex CLI, and Claude CLI for a consistent environment.
  - Spec-driven prompts in `.codex/prompts/` and steering in `.kiro/steering/`.

## Target Use Cases
- Convert official/team timing CSVs into a consistent JSON schema for analysis.
- Generate assets consumed by the Elm UI for static or hybrid hosting.
- Batch-process race-weekend folders and quickly validate outputs via integration tests.

## Key Value Proposition
- End-to-end type safety: Rust domain model → JSON → Elm decoders.
- Reproducibility: devcontainer + npm workspaces ensure consistent local and CI environments.
- Performance: Rust for ingestion/processing; Elm for reliable, maintainable UI.

## Notable Constraints & Assumptions
- Input format: current CLI assumes a specific CSV layout (see Rust crate `cli` for parsers and tests).
- Event naming: CLI maps known event ids (e.g., `le_mans_24h`) to display names; unknown ids map to "Encoding Error" until extended.
- Ports/ENV: app dev server/ports are not pinned in repo; no mandatory environment variables are required for basic usage.

## Getting Started Examples
- Run the UI: `npm run start` (root calls `app` workspace)
- Build the UI: `npm run build`
- Process a CSV: `cargo run -p cli -- ./cli/test_data.csv --output ./out.json`
  - Outputs: `./out.json` (metadata) and `./out_laps.json` (laps)

## Change Notes
- 2025-09-25: Regenerated steering files. Last steering commit affecting deletes was `9891ef3` (product.md, structure.md, tech.md removed in that commit).

## Security & Privacy
- Do not commit secrets or proprietary timing data. Sample CSVs should be sanitized.
- JSON outputs may contain driver names and team info; ensure usage complies with licensing and privacy.

