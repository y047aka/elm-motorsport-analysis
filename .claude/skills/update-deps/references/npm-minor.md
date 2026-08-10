# npm (minor)

Semver-compatible (patch and minor) updates for npm packages.

## Audit

```bash
pnpm -C app outdated --json 2>/dev/null | nix run .#deps-audit -- npm-outdated-audit
pnpm -C app audit --json 2>/dev/null | nix run .#deps-audit -- npm-security-audit
```

`-C app` is required: `app/` is the repository's only npm project and holds
`package.json` and `pnpm-lock.yaml`. There is no manifest at the repository root,
so pnpm run from there finds nothing.

The first script classifies outdated packages into minor and major sections, and flags Playwright changes. Focus on the `minor updates` section.

The second script classifies security vulnerabilities by severity and fix availability. Note `fixable-breaking` count — these fixes require `--force` and may introduce breaking changes.

## Update

Run `pnpm -C app update` for semver-compatible updates.

After updating, pin all dependency versions using the resolved versions from `pnpm-lock.yaml`
(not the semver constraint, which may differ from the installed version for pre-release packages):

```bash
nix run .#deps-audit -- npm-pin-versions
```

Then run `pnpm install` to sync `app/pnpm-lock.yaml` with the pinned versions:

```bash
pnpm -C app install
```

### Special handling

- **Playwright version change**: If the script reports `playwright-changed: true`, remind the user to run `pnpm -C app exec playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.
- **vite version change**: Check `vite-plugin-elm`'s `peerDependencies` range for `vite` (in `app/node_modules/vite-plugin-elm/package.json`) before bumping past a major boundary.

## Verify

```bash
nix run .#test
nix run .#build
```
