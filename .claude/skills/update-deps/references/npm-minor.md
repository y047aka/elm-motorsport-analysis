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

This moves transitive dependencies within their ranges and leaves the direct
ones alone: every entry in `app/package.json` is an exact version, which is a
range with nothing to move within. Taking a direct dependency to a newer version
is therefore always the major flow — from pnpm's point of view any change to an
exact pin exceeds its range, whether the number that moves is major or not.

Only `app/pnpm-lock.yaml` changes. Nothing rewrites `package.json` afterwards.

### Special handling

- **Playwright version change**: If the script reports `playwright-changed: true`, remind the user to run `pnpm -C app exec playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.
- **vite version change**: Check `vite-plugin-elm`'s `peerDependencies` range for `vite` (in `app/node_modules/vite-plugin-elm/package.json`) before bumping past a major boundary.

## Verify

```bash
nix run .#test
nix run .#build
```
