# npm (major)

Major version updates for npm packages (exceeding the current semver range).

## Audit

```bash
pnpm -r outdated --json 2>/dev/null | nix run .#deps-audit -- npm-outdated-audit
```

The `-r` flag is required: without it, `pnpm outdated` only checks the workspace root and misses outdated packages in workspace projects such as `app`.

The script classifies outdated packages into minor and major sections, and flags Playwright changes. Focus on the `major updates` section.

## Update

For each confirmed major bump, install explicitly with an exact pin:

```bash
pnpm add --save-exact <pkg>@latest
```

If the package belongs to a workspace, add the filter flag (e.g., `--filter app`).

### Special handling

- **Playwright version change**: If the script reports `playwright-changed: true`, remind the user to run `pnpm exec playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.
- **vite version change**: Check `vite-plugin-elm`'s `peerDependencies` range for `vite` (in `app/node_modules/vite-plugin-elm/package.json`) before bumping past a major boundary.

## Verify

```bash
nix run .#test
nix run .#build
```
