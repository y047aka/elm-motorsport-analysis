# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Motorsport race analysis and visualization application. Monorepo with Elm frontend and Rust CLI.

## Commands

### Development
```bash
npm start                    # elm-pages dev server (localhost:1234)
npm run build               # Production build
```

### Testing
```bash
npm test                    # Elm package tests (elm-verify-examples + elm-test)
npm run -w app test         # Playwright VRT tests (Docker required)
npm run -w app test:update-snapshots  # Update VRT snapshots
```

### Code Quality
```bash
npm run -w review app       # elm-review on app
npm run -w review package   # elm-review on package
biome format --write .      # Format code
biome check --write .       # Lint and fix
```

### Rust CLI
```bash
cd cli && cargo build       # Build CLI
cd cli && cargo test        # Run Rust tests
```

## Architecture

### Monorepo Structure (npm workspaces)
- **`/app`** - elm-pages 3.x web application (frontend)
- **`/package`** - Reusable Elm library (motorsport domain models)
- **`/cli`** - Rust CLI for CSV→JSON data processing
- **`/review`** - elm-review configuration

### Frontend Stack
- **Elm 0.19.1** with elm-pages 3.x (full-stack framework)
- **Tailwind CSS 4.x** + elm-css for styling
- **Vite** for bundling
- **Playwright** for visual regression testing

### Key Elm Modules

**`/app/app/Route/`** - Page routes
- `GapChart.elm` - Gap analysis visualization
- `LapTimeCharts.elm` - Lap time comparison charts
- `F1/` - Formula 1 specific pages

**`/app/src/`** - Shared modules
- `Css/` - Type-safe styling (Color, Palette, Typography)
- `Data/` - Series configurations (FormulaE, WEC)
- `UI/` - Reusable components (Button, Label, Table)

**`/package/src/Motorsport/`** - Domain models
- `Car.elm`, `Driver.elm`, `Lap.elm`, `Gap.elm`
- `Analysis.elm` - Race analysis functions
- `Chart/` - Chart rendering (GapChart, BoxPlot)

### Data Flow
CSV telemetry → Rust CLI parsing → JSON → Elm frontend visualization

## Testing

### Playwright VRT
- Docker container required: `mcr.microsoft.com/playwright:v1.57.0-noble`
- Strict 0 pixel tolerance for visual diffs
- Test files in `/app/tests/`

### Elm Tests
- Unit tests: `elm-test`
- Example verification: `elm-verify-examples` (docstring examples)
- Benchmarks: `/package/benchmark/`

## Environment

Nix flake provides reproducible dev environment (Node.js 24, Rust toolchain). Use `direnv allow` or `nix develop`.
