# npm (major)

Major version updates for npm packages (exceeding the current semver range).

## Audit

```bash
pnpm outdated --json 2>/dev/null | cargo run --manifest-path .claude/skills/update-deps/scripts/Cargo.toml -- npm-outdated-audit
```

The script classifies outdated packages into minor and major sections, and flags Playwright/vite changes. Focus on the `major updates` section.

## Update

For each confirmed major bump, install explicitly with an exact pin:

```bash
pnpm add --save-exact <pkg>@latest
```

If the package belongs to a workspace, add the filter flag (e.g., `--filter app`).

### Special handling

- **Playwright version change**: If the script reports `playwright-changed: true`, remind the user to run `pnpm exec playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.
- **vite version change**: If the script's `vite` section shows the update would cross the `bundled-major` version boundary, **never** update vite. Never remove vite — without it, elm-pages silently falls back to default config, ignoring `elm-pages.config.mjs`.

## Verify

```bash
nix run .#test
nix run .#build
```
