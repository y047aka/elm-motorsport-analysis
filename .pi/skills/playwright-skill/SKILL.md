---
name: playwright-skill
description: Browser work in this repository — the VRT suite under app/tests, the custom-elements contract spec, and how to drive a browser without installing one. Use when adding, running, or debugging Playwright tests, or when a page needs checking in a real browser.
---

# Playwright in this repository

**Never install Playwright here.** The flake owns it: `playwright-test` and its
driver browsers come from nixpkgs (`nix/vrt.nix` symlinks `@playwright/test`
into `app/node_modules` and points `PLAYWRIGHT_BROWSERS_PATH` at the store).
`npm install playwright` and `npx playwright install` — what upstream copies
of this skill tell you to run, sometimes by themselves — download a second
browser into a machine nix pins, and no test here will use it.

The sanctioned ways to drive a browser:

- **Anything re-runnable is a spec** under `app/tests/`, run through the flake:
  `nix run .#test-vrt`, filtered by test name as needed. `car-detail.spec.ts`
  reads widths, pitches and steps out of the Elm sources that decide them, so
  a new assertion takes its constants the same way rather than spelling them;
  `helpers.ts` refuses a VRT round whose summary names no circuit. The roles of the suite's files, and what a baseline may
  be refreshed with (`.#update-snapshots-ci`, never the macOS-local
  `.#update-snapshots-vrt` for landed bytes), are AGENTS.md's Testing section
  to say.
- **A look at a page** — a screenshot, an element, "did my edit render" — is
  the preview tools' work in-session, not a script's. Writing a throwaway
  Playwright file to see a page costs a browser launch the preview already
  holds open.

A browser is only reachable where the flake wraps it in its environment. The
devShell carries the store browser and the `playwright` CLI, but the symlink
`@playwright/test` resolves through is made by the two VRT apps alone — so an
import of it outside a spec resolves only as a leftover of their runs, which
is not a foundation. Anything wanting more than a CLI line is a spec under
`app/tests/`.
