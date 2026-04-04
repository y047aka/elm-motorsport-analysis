# elm-pages

Coordinated update of the elm-pages ecosystem (npm package + dillonkearns/* Elm packages).

## Audit

1. Check current `elm-pages` version from `app/package.json` (exact pin).

2. Check latest available version:
   ```bash
   npm view elm-pages dist-tags.latest
   ```

3. Report all `dillonkearns/*` package versions:
   ```bash
   node --experimental-strip-types .claude/skills/update-deps/scripts/elm-dillonkearns-guard.ts
   ```

4. Report the current compatibilityKey:
   ```bash
   cat node_modules/elm-pages/generator/src/compatibility-key.js
   ```

## Update

Update npm package first, then Elm packages.

### Step 1: Update npm package

elm-pages must be pinned exact (no caret). Always use `--save-exact` (omitting it adds `^`):
```bash
npm install --save-exact elm-pages@<version> -w app
```

### Step 2: Identify the required Elm package version

The npm package ships Elm source with a compatibilityKey integer. The Elm package installed from package.elm-lang.org must have the same key.

```bash
node --experimental-strip-types .claude/skills/update-deps/scripts/elm-pages-compat-key.ts
```

If the script reports `matchingElmVersion: no-match`, follow its instruction to install the latest Elm package to populate the cache, then re-run the script.

Use the `matchingElmVersion` value as the target version in Step 3.

### Step 3: Update Elm packages in app/elm.json

Use `elm-json` to uninstall the old version and reinstall at the target version. This handles all transitive dependency resolution automatically.

```bash
elm-json uninstall --yes dillonkearns/elm-pages -- app/elm.json
elm-json install --yes 'dillonkearns/elm-pages@<version>' -- app/elm.json
```

`elm-json uninstall` removes the package and any indirect dependencies that are no longer needed. `elm-json install` then resolves and adds all required transitive dependencies correctly, including proper placement in `dependencies` vs `test-dependencies`.

## Verify

```bash
nix run .#build
nix run .#test
```

If the build fails with a compatibilityKey mismatch, revisit Step 2.

If build errors occur due to API changes, follow the next section.

## Application code migration

Major elm-pages updates may require application code changes due to API changes.

### Procedure

1. Check the elm-pages CHANGELOG or upgrade guide (e.g. `CHANGELOG-ELM.md` in the GitHub repository).
2. Use `nix run .#build` compiler errors to identify files that need changes.
3. Commonly affected files:
   - `app/app/Route/*.elm` — page route signatures
   - `app/app/Effect.elm` — effect definitions
   - `app/app/Shared.elm` — shared state
   - `app/app/Site.elm` — site configuration
   - `app/app/View.elm` — view definitions
   - `app/src/**/*.elm` — modules using BackendTask, Head, or other elm-pages APIs

### Common API change patterns

- `BackendTask` API signature changes
- `Head` module meta tag API changes
- Route module `action` / `data` function signature changes
- `Pages.Msg` type changes

## Notes

- The `lamdera/codecs` Elm package is automatically injected by elm-pages during build. Do not manage it manually.
- elm-pages must remain exact-pinned (no caret) in `app/package.json`.
- npm and Elm package version numbers are independent (e.g. npm 3.0.22 corresponds to Elm 10.2.1). The compatibilityKey integer is the binding contract between them.

### vite version alignment

elm-pages bundles its own vite internally, but `app/elm-pages.config.mjs` imports `defineConfig` from the user-installed vite (resolved via Node.js module resolution, not elm-pages's nested copy). The `defineConfig` output is merged with elm-pages's internal vite config at build time.

When elm-pages is updated:

1. Check elm-pages's new bundled vite version:
   ```bash
   node --experimental-strip-types .claude/skills/update-deps/scripts/vite-bundled-version.ts
   ```
2. If the bundled vite major version changed, update the user's vite in `app/package.json` to match:
   ```bash
   npm install --save-exact vite@<version> -w app
   ```
3. If only a minor/patch bump, no action is needed — minor version mismatch between the user's vite and elm-pages's bundled vite is acceptable since `defineConfig` is stable across minors.
