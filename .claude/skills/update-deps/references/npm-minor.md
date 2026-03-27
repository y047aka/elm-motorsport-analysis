# npm (minor)

Semver-compatible (patch and minor) updates for npm packages.

## Audit

```bash
npm outdated || true
npm audit || true
```

Focus on packages where **Current** differs from **Wanted** — these are semver-compatible updates allowed by the existing version constraints.

For `npm audit` findings, note whether fixes require `--force` (which may be a breaking change) and report them to the user.

## Update

Run `npm update --save` for semver-compatible updates.

After updating, pin all dependency versions using the resolved versions from `package-lock.json`
(not the semver constraint, which may differ from the installed version for pre-release packages):

```bash
node -e "
const fs = require('fs');
const lock = JSON.parse(fs.readFileSync('package-lock.json', 'utf8'));

function resolved(name, wsPrefix) {
  if (wsPrefix) {
    const k = wsPrefix + '/node_modules/' + name;
    if (lock.packages[k]) return lock.packages[k].version;
  }
  const k = 'node_modules/' + name;
  return lock.packages[k] ? lock.packages[k].version : null;
}

const workspaces = {
  'package.json': '',
  'app/package.json': 'app',
  'package/package.json': 'package',
  'review/package.json': 'review',
};

for (const [f, ws] of Object.entries(workspaces)) {
  const pkg = JSON.parse(fs.readFileSync(f, 'utf8'));
  for (const key of ['dependencies', 'devDependencies']) {
    if (!pkg[key]) continue;
    for (const name of Object.keys(pkg[key])) {
      const v = resolved(name, ws);
      pkg[key][name] = v || pkg[key][name].replace(/^[\^~]/, '');
    }
  }
  fs.writeFileSync(f, JSON.stringify(pkg, null, 2) + '\n');
}
"
```

Then run `npm install` to sync `package-lock.json` with the pinned versions:

```bash
npm install
```

### Special handling

- **Playwright version change**: If `@playwright/test` is updated, remind the user to run `npx playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.
- **vite version change**: `vite` is directly imported by `app/elm-pages.config.mjs` (`import { defineConfig } from "vite"`). elm-pages also bundles its own vite internally (in `node_modules/elm-pages/node_modules/vite/`). When updating vite:
  1. Check elm-pages's bundled vite version: `node -e "console.log(require('elm-pages/node_modules/vite/package.json').version)"`
  2. Avoid upgrading the user's vite past elm-pages's bundled major version, as `defineConfig` output is merged with elm-pages's internal vite config and major version mismatch may cause incompatibilities.
  3. Never remove vite — without it, elm-pages silently falls back to default config, ignoring `elm-pages.config.mjs` (headTagsTemplate, preloadTagForFile, etc.).

## Verify

```bash
nix run .#test
nix run .#build
```
