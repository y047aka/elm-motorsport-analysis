# npm (major)

Major version updates for npm packages (exceeding the current semver range).

## Audit

```bash
npm outdated || true
```

Focus on packages where **Latest** has a higher **major version** than **Current** (e.g., `6.x → 7.0.0`). Packages where Latest is only a minor or patch bump ahead are not major update candidates. List each major-bump package with its current version and latest version.

## Update

For each confirmed major bump, install explicitly with an exact pin:

```bash
npm install --save-exact <pkg>@latest
```

If the package belongs to a workspace, add the workspace flag (e.g., `-w app`).

### Special handling

- **Playwright version change**: If `@playwright/test` is updated, remind the user to run `npx playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.
- **vite version change**: `vite` is directly imported by `app/elm-pages.config.mjs` (`import { defineConfig } from "vite"`). elm-pages also bundles its own vite internally (in `node_modules/elm-pages/node_modules/vite/`). When updating vite:
  1. Check elm-pages's bundled vite version: `node -e "console.log(require('elm-pages/node_modules/vite/package.json').version)"`
  2. **Never** upgrade the user's vite past elm-pages's bundled major version, as `defineConfig` output is merged with elm-pages's internal vite config and major version mismatch may cause incompatibilities.
  3. Never remove vite — without it, elm-pages silently falls back to default config, ignoring `elm-pages.config.mjs` (headTagsTemplate, preloadTagForFile, etc.).

## Verify

```bash
nix run .#test
nix run .#build
```
