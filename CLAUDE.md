# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Motorsport race analysis and visualization application. Monorepo with Elm frontend and Rust CLI.

## Commands

### Development
```bash
nix run .#dev                # Vite dev server (localhost:1234)
nix run .#build              # Production build (Vite)
```

### Testing
```bash
nix run .#test               # Elm package tests (elm-verify-examples + elm-test)
nix run .#test-vrt           # Playwright VRT tests
nix run .#update-snapshots-vrt  # Update Playwright VRT snapshots
```

### Code Quality
```bash
nix run .#review-app         # elm-review on app
nix run .#review-package     # elm-review on package
nix run .#format             # Format Elm code (elm-format)
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
- **`/app`** - Elm SPA web application (frontend), bundled by Vite
- **`/package`** - Reusable Elm library (motorsport domain models)
- **`/cli`** - Rust CLI for CSV→JSON data processing

### Frontend Stack
- **Elm 0.19.1** SPA built on `Browser.application` (framework-less; no elm-pages)
- **Tailwind CSS 4.x** + elm-css for styling
- **Vite** for bundling (`vite-plugin-elm`)
- **Playwright** for visual regression testing

### SPA architecture (`/app/src/`)

The application is a hand-written multi-page SPA. `index.ts` boots
`Elm.Main.init`; `Main.elm` owns the `Browser.application` and wires everything
together. Data is fetched at runtime via `Http` (no `BackendTask`).

- `Main.elm` - `Browser.application`: top-level Model/Msg, URL handling, page dispatch
- `Route.elm` - client-side routing (`Url.Parser`): `/`, `/debug`, `/wec/:season/:event`
- `Shared.elm` / `Shared/Msg.elm` - app-wide state (race control, view model) + data loading
- `Effect.elm` - elm-spa-style effects (`sendCmd`, `sendSharedMsg`, `pushRoute`, ...)
- `View.elm` - `{ title, body }` document type
- `Page/` - one module per page (`Index`, `Debug`, `Wec/Event`), plain TEA

**`/app/src/`** - Shared view/data modules
- `Css/` - Type-safe styling (Color, Palette, Typography)
- `Data/` - Series configurations (WEC)
- `UI/` - Reusable components (Button, Label, Table)

**`/package/src/Motorsport/`** - Domain models
- `Car.elm`, `Driver.elm`, `Lap.elm`, `Gap.elm`
- `ViewModel.elm`, `ViewModel/` - Computed models for views (Standings, LapHistory, BestTimes)
- `Chart/` - Chart rendering (GapChart, BoxPlot)

### Data Flow
CSV telemetry → Rust CLI parsing → JSON → Elm frontend visualization

## Testing

### Playwright VRT
- Local: runs directly on host, 1% pixel ratio tolerance for cross-platform diffs
- CI: runs on ubuntu-latest, strict 0 pixel tolerance
- Snapshot updates: run `nix run .#update-snapshots-vrt` locally, or trigger workflow_dispatch in CI to auto-push to branch
- Test files in `/app/tests/`

### Elm Tests
- Unit tests: `elm-test`
- Example verification: `elm-verify-examples` (docstring examples)
- Benchmarks: `/package/benchmark/`

## Environment

Nix flake provides reproducible dev environment (Node.js 26, Rust toolchain). Use `direnv allow` or `nix develop`. Run `nix flake show` to list all available `nix run` commands.
