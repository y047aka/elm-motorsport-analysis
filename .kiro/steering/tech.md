# Technology Stack

## Architecture

**Multi-Workspace Monorepo** with clear separation of concerns:
- **Frontend**: Elm application with static site generation
- **Data Processing**: Rust CLI for high-performance data transformation
- **Package**: Reusable Elm library for motorsport analysis components
- **Development**: TypeScript tooling and build pipeline

## Frontend Stack

### Core Framework
- **Elm 0.19.1**: Main application language for type safety and reliability
- **elm-pages 3.0.22**: Static site generator with dynamic data loading
- **Vite 6.2.4**: Build tool and development server

### UI & Visualization
- **TypedSvg**: Type-safe SVG generation for charts
- **Elm Styling**: CSS-in-Elm approach for component styling
- **Interactive Charts**: Custom motorsport-specific visualization components

### Development Tools
- **elm-format**: Code formatting
- **elm-review**: Static analysis and linting
- **elm-test**: Unit testing framework
- **elm-verify-examples**: Documentation testing

## Backend & Data Processing

### Rust CLI Tools
- **Rust 2021 Edition**: High-performance data processing
- **Serde**: JSON/CSV serialization and deserialization
- **CSV Processing**: Native CSV parsing for race data
- **Workspace Structure**: Modular Rust packages (`cli` + `motorsport` library)

### Data Pipeline
- **Input**: CSV race data files
- **Processing**: Rust CLI transforms raw timing data
- **Output**: JSON files for frontend consumption
- **Static Assets**: Processed data served via elm-pages

## Development Environment

### Package Management
- **npm**: JavaScript dependencies and workspace management
- **Cargo**: Rust dependency management
- **elm.json**: Elm package configuration

### Build System
- **Workspaces**: Root package.json coordinates `app`, `package`, `review` workspaces
- **Development Scripts**: Unified commands across all workspaces
- **Build Pipeline**: elm-pages handles Elm compilation and asset bundling

## Common Commands

### Development
```bash
npm run start    # Start development server (app workspace)
npm run build    # Build production assets (app workspace)
npm run test     # Run Elm tests (package workspace)
npm run benchmark # Run performance benchmarks (CLI)
```

### Data Processing
```bash
cd cli && cargo run    # Process race data
cargo test            # Run Rust tests
```

### Code Quality
```bash
elm-format --validate  # Check Elm code formatting
elm-review            # Run static analysis
elm-test              # Run test suite
```

## Environment Variables

### Build Configuration
- **NODE_ENV**: Development/production mode
- **VITE_***: Vite-specific configuration variables

### Data Paths
- Static data served from `app/static/` directory
- Race data organized by series and season
- Image assets in `app/static/images/` with series-specific subdirectories

## Port Configuration

### Development Ports
- **elm-pages dev**: Typically port 3000 (configurable)
- **elm reactor**: Port 8000 for package benchmarks
- **Vite dev server**: Integrated with elm-pages

## Key Dependencies

### Elm Ecosystem
- **elm-pages**: Static site generation and routing
- **elm-codegen**: Code generation utilities
- **lamdera**: Development tooling
- **elm-optimize-level-2**: Production optimization

### Rust Ecosystem
- **serde**: Serialization framework
- **csv**: CSV parsing and writing
- **tempfile**: Testing utilities

### JavaScript/TypeScript
- **@biomejs/biome**: Code formatting and linting
- **TypeScript**: Type checking for custom backend tasks