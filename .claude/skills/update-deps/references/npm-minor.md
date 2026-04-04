# npm (minor)

Semver-compatible (patch and minor) updates for npm packages.

## Audit

```bash
npm outdated --json 2>/dev/null | node .claude/skills/update-deps/scripts/npm-outdated-audit.cjs
npm audit || true
```

The script classifies outdated packages into minor and major sections, and flags Playwright/vite changes. Focus on the `minor updates` section.

For `npm audit` findings, note whether fixes require `--force` (which may be a breaking change) and report them to the user.

## Update

Run `npm update --save` for semver-compatible updates.

After updating, pin all dependency versions using the resolved versions from `package-lock.json`
(not the semver constraint, which may differ from the installed version for pre-release packages):

```bash
node .claude/skills/update-deps/scripts/npm-pin-versions.cjs
```

Then run `npm install` to sync `package-lock.json` with the pinned versions:

```bash
npm install
```

### Special handling

- **Playwright version change**: If the script reports `playwright-changed: true`, remind the user to run `npx playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.
- **vite version change**: If the script's `vite` section shows the update would cross the `bundled-major` version boundary, do not update vite. Never remove vite — without it, elm-pages silently falls back to default config, ignoring `elm-pages.config.mjs`.

## Verify

```bash
nix run .#test
nix run .#build
```
