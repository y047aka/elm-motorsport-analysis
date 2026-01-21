---
name: playwright-run
description: Run this project's existing Playwright test suite in app/tests/. Use for running committed tests, updating snapshots, or CI validation. NOT for writing new tests or ad-hoc browser automation.
---

# Playwright Test Runner

Run Playwright E2E tests for this project.

## Usage
- `/playwright-run` - Run all E2E tests
- `/playwright-run --update-snapshots` - Update visual regression snapshots
- `/playwright-run --ui` - Run with interactive UI mode
- `/playwright-run example` - Run tests matching "example"

## Commands

### Run all tests (default)
```bash
cd app && npx playwright test
```

### Update snapshots
```bash
cd app && npx playwright test --update-snapshots
```

### Run with UI mode (for debugging)
```bash
cd app && npx playwright test --ui
```

### Run specific test file
```bash
cd app && npx playwright test example.spec.ts
```

### Show test report
```bash
cd app && npx playwright show-report
```

## Options
- `--update-snapshots` - Update visual regression snapshots
- `--ui` - Run with interactive UI mode for debugging
- `--headed` - Run tests in headed browser mode
- `--debug` - Run tests with Playwright Inspector

## Notes
- Tests run against `http://localhost:1234` (dev server auto-starts via webServer config)
- Browser: Google Chrome (Desktop, 1440x900px)
- Test files location: `app/tests/*.spec.ts`
- Snapshots stored in: `app/tests/*.spec.ts-snapshots/`
