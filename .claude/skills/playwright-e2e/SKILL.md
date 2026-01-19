---
name: playwright-e2e
description: Run Playwright E2E tests
---

# Playwright E2E Test Runner

Run Playwright E2E tests for this project.

## Usage
- `/playwright-e2e` - Run all E2E tests
- `/playwright-e2e <test-name>` - Run specific test file or test name

## Commands

### Run all tests (default)
```bash
cd app && npx playwright test
```

### Run specific test (when argument provided)
```bash
cd app && npx playwright test $ARGUMENTS
```

### Useful options
- `--ui` - Run with UI mode for debugging
- `--update-snapshots` - Update visual regression snapshots
- `--headed` - Run tests in headed browser mode

### Show test report
```bash
cd app && npx playwright show-report
```

## Notes
- Tests run against `http://localhost:1234` (dev server auto-starts via webServer config)
- Browser: Google Chrome (Desktop, 1440x900px)
- Test files location: `app/tests/*.spec.ts`
- Snapshots stored in: `app/tests/*.spec.ts-snapshots/`
