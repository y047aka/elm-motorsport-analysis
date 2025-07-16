# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a motorsport analysis application built with Elm and elm-pages. It provides visualization and analysis tools for Formula 1, Formula E, and WEC racing data. The app displays race control information, lap times, position progressions, and various racing analytics.

## Architecture

The codebase is organized as a monorepo with multiple workspaces:

### Workspaces Structure
- **`app/`**: Main elm-pages application (web frontend)
- **`package/`**: Core Elm library with motorsport analysis logic
- **`cli/`**: Command-line tools for data processing and conversion
- **`review/`**: Elm-review configuration and rules

### Key Components

**Core Motorsport Library (`package/src/Motorsport/`)**:
- `Analysis.elm`: Race analysis calculations and performance metrics
- `Car.elm`, `Driver.elm`, `Class.elm`: Core data models
- `RaceControl.elm`: Race control state management
- `Chart/`: Visualization components (GapChart, LapTimeChart, Tracker, etc.)
- `Widget/`: UI components for race data display

**Data Processing (`app/src/Data/`)**:
- `Series/`: Sport-specific data handling (F1, FormulaE, WEC)
- `F1/Decoder.elm`: Formula 1 data parsing
- `FormulaE.elm`, `Wec.elm`: Series-specific data models

**UI Components (`app/src/UI/`)**:
- Styled components using elm-css
- Reusable table, button, and form components

## Development Commands

### Root Commands
```bash
npm run start         # Start development server
npm run build         # Build the application
npm run test          # Run tests
npm run benchmark     # Run performance benchmarks
npm run csv_to_json   # Convert CSV data to JSON
```

### Workspace-Specific Commands

**App (elm-pages frontend)**:
```bash
npm run -w app start  # Start dev server
npm run -w app build  # Build for production
```

**Package (core library)**:
```bash
npm run -w package test       # Run elm-test and elm-verify-examples
npm run -w package benchmark  # Run benchmarks
```

**CLI (data processing)**:
```bash
npm run -w cli build    # Build CLI tools
npm run -w cli start    # Run CLI application
npm run -w cli test     # Run CLI tests
npm run -w cli watch    # Build in watch mode
```

**Review (code quality)**:
```bash
npm run -w review package  # Review package code
npm run -w review app      # Review app code
npm run -w review cli      # Review CLI code
```

## Data Format

The application processes motorsport data from multiple sources:
- **Static data**: Located in `app/static/` with CSV and JSON files
- **Race data**: Includes lap times, positions, sector times, and timing data
- **Images**: Car images stored in `app/static/images/wec/`

## Code Quality

- **Biome**: Used for TypeScript/JavaScript formatting and linting
- **elm-format**: Automatic Elm code formatting
- **elm-review**: Elm-specific linting and best practices
- **elm-test**: Unit testing framework

## Testing

- Run `npm run test` to execute the full test suite
- Tests use `elm-test` and `elm-verify-examples`
- Benchmarks available for performance-critical code

## Build Process

- Uses `elm-pages` for static site generation
- Vite for TypeScript/JavaScript bundling
- `elm-optimize-level-2` for production builds
- Development server available at localhost with hot reloading