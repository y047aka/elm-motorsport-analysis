# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Motorsport race analysis and visualization application. Monorepo with Elm frontend and Rust CLI.

## Commands

### Development
```bash
nix run .#dev                # elm-pages dev server (localhost:1234)
nix run .#build              # Production build
```

### Testing
```bash
nix run .#test               # Elm package tests (elm-verify-examples + elm-test)
nix run .#test-vrt           # Playwright VRT tests
```

### Code Quality
```bash
nix run .#review-app         # elm-review on app
nix run .#review-package     # elm-review on package
nix run .#format             # Format code (biome format --write .)
nix run .#lint               # Lint and fix (biome check --write .)
```

### Rust CLI
```bash
nix run .#cli-build          # Build CLI
nix run .#cli-test           # Run Rust tests
```

### Dependency Management
```bash
/update-deps                 # Audit and update all dependencies (Claude skill)
/update-deps [npm|elm|rust|nix]  # Target a specific ecosystem
```

## Architecture

### Monorepo Structure (pnpm workspaces)
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
- Local: runs directly on host, 1% pixel ratio tolerance for cross-platform diffs
- CI: runs on ubuntu-latest, strict 0 pixel tolerance
- Snapshot updates: CI の workflow_dispatch で実行し、ブランチに自動プッシュ
- Test files in `/app/tests/`

### Elm Tests
- Unit tests: `elm-test`
- Example verification: `elm-verify-examples` (docstring examples)
- Benchmarks: `/package/benchmark/`

## Environment

Nix flake provides reproducible dev environment (Node.js 24, Rust toolchain). Use `direnv allow` or `nix develop`. Run `nix flake show` to list all available `nix run` commands.
