# Project Structure

## Root Directory Organization

```
elm-motorsport-analysis/
├── app/                    # Main Elm frontend application
├── cli/                    # Rust workspace for data processing
├── package/                # Reusable Elm motorsport analysis library
├── review/                 # Elm code review configuration
├── node_modules/           # JavaScript dependencies
├── .kiro/                  # Kiro spec-driven development files
├── package.json           # Workspace coordination and scripts
├── biome.json             # Code formatting configuration
└── CLAUDE.md              # Project instructions and guidelines
```

## App Directory (`app/`)

### Source Structure
```
app/
├── src/                   # Elm source code
│   ├── Data/              # Data models and decoders
│   │   ├── F1/            # Formula 1 specific data handling
│   │   ├── Series/        # Multi-series data models
│   │   └── *.elm          # Core data types
│   ├── Css/               # Styling modules
│   ├── UI/                # Reusable UI components
│   └── Path/              # Route handling utilities
├── app/                   # Page components and routing
│   ├── Route/             # Individual page modules
│   │   ├── FormulaE/      # Formula E specific pages
│   │   └── Wec/           # WEC specific pages
│   └── *.elm              # Core app modules (Api, Site, View)
└── static/                # Static assets and data
    ├── formula-e/         # Formula E data files
    ├── wec/               # WEC data files
    └── images/            # Car and series imagery
```

### Configuration Files
- `elm.json`: Elm package configuration
- `package.json`: npm scripts and dependencies
- `elm-pages.config.mjs`: elm-pages build configuration
- `custom-backend-task.ts`: Custom data processing tasks

## CLI Directory (`cli/`)

### Rust Workspace Structure
```
cli/
├── cli/                   # Main CLI application
│   ├── src/
│   │   ├── main.rs        # CLI entry point
│   │   ├── config.rs      # Configuration handling
│   │   ├── preprocess.rs  # Data preprocessing logic
│   │   └── output.rs      # Output generation
│   └── tests/             # Integration tests
└── motorsport/            # Core motorsport data library
    └── src/
        ├── lib.rs         # Library entry point
        ├── lap.rs         # Lap time data structures
        ├── driver.rs      # Driver information
        ├── car.rs         # Car/vehicle data
        ├── class.rs       # Racing class definitions
        └── duration.rs    # Time duration utilities
```

## Package Directory (`package/`)

### Elm Library Structure
```
package/
├── src/
│   ├── Motorsport/        # Core motorsport analysis modules
│   │   ├── Chart/         # Visualization components
│   │   ├── Widget/        # Analysis widgets
│   │   ├── RaceControl/   # Race control functionality
│   │   └── *.elm          # Core analysis types
│   ├── DataView/          # Data visualization utilities
│   ├── SortedList.elm     # Custom data structures
│   └── TypedSvg/          # SVG generation utilities
├── tests/                 # Unit tests
├── examples/              # Usage examples
└── benchmark/             # Performance benchmarks
```

## Code Organization Patterns

### Elm Module Hierarchy
- **Domain-First**: Modules organized by motorsport domain (F1, FormulaE, WEC)
- **Feature-Based**: Related functionality grouped together (Chart, Widget, RaceControl)
- **Reusable Components**: UI and utility modules designed for cross-series use

### Rust Module Structure
- **Library-Binary Separation**: Core logic in `motorsport` library, CLI in separate crate
- **Data-Driven Design**: Types closely mirror race data structures
- **Processing Pipeline**: Clear separation between input, processing, and output

### Data Flow Architecture
```
Raw CSV Data → Rust CLI Processing → JSON Output → Elm Frontend → Interactive Charts
```

## File Naming Conventions

### Elm Files
- **PascalCase**: Module names match file names (`DataView.elm`)
- **Hyphenated Routes**: Page modules use hyphens (`Route-F1.elm`)
- **Descriptive Names**: Clear indication of module purpose (`Chart-GapChart.elm`)

### Rust Files
- **snake_case**: Standard Rust naming (`lap.rs`, `driver.rs`)
- **Descriptive**: Module names indicate data domain
- **Hierarchical**: Related modules in same directory

### Data Files
- **Series/Season/Event**: Organized by racing series and chronology
- **Format Consistency**: CSV for input, JSON for processed output
- **Descriptive Naming**: Event names and dates in filenames

## Import Organization

### Elm Import Standards
```elm
-- Standard library imports first
import Dict
import List

-- Third-party packages
import Css
import Html.Styled

-- Internal modules, organized by hierarchy
import Data.Series
import Motorsport.Analysis
import UI.Button
```

### Rust Import Standards
```rust
// Standard library
use std::collections::HashMap;

// External crates  
use serde::{Deserialize, Serialize};

// Internal modules
use crate::lap::Lap;
use motorsport::Driver;
```

## Key Architectural Principles

### Type Safety First
- **Elm's Guarantees**: No runtime exceptions in frontend code
- **Rust's Memory Safety**: Guaranteed memory safety in data processing
- **Strong Typing**: Custom types for domain concepts (Duration, Gap, Position)

### Functional Programming
- **Immutable Data**: All data transformations create new values
- **Pure Functions**: Predictable, testable data processing
- **Composable Components**: Small, reusable functions and modules

### Performance Optimization
- **Rust for Heavy Lifting**: Data processing in high-performance Rust
- **Elm for UI**: Efficient virtual DOM and minimal JavaScript
- **Static Generation**: Pre-processed data for fast loading

### Modularity and Reusability
- **Package System**: Shared components in separate Elm package
- **Workspace Organization**: Clear boundaries between concerns
- **Domain Abstraction**: Generic components work across racing series