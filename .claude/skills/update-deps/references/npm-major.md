# npm (major)

Major version updates for npm packages (exceeding the current semver range).

## Audit

```bash
pnpm -C app outdated --json 2>/dev/null | nix run .#deps-audit -- npm-outdated-audit
```

`-C app` is required: `app/` is the repository's only npm project and holds
`package.json` and `pnpm-lock.yaml`. There is no manifest at the repository root,
so pnpm run from there finds nothing.

The script classifies outdated packages into minor and major sections, and flags Playwright changes. Focus on the `major updates` section.

## Update

For each confirmed major bump, install explicitly with an exact pin:

```bash
pnpm -C app add --save-exact <pkg>@latest
```

`app/.npmrc` sets `save-exact=true`, so the exact form holds even when the flag
is forgotten, and `pnpm update --latest` preserves it too. There is no pinning
step after the fact — `package.json` never acquires a `^` range to undo.

### Special handling

- **Playwright version change**: If the script reports `playwright-changed: true`, remind the user to run `pnpm -C app exec playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.
- **vite version change**: Check `vite-plugin-elm`'s `peerDependencies` range for `vite` (in `app/node_modules/vite-plugin-elm/package.json`) before bumping past a major boundary.

## Verify

```bash
nix run .#test
nix run .#build
```
