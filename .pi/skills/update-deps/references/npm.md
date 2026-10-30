# npm

`app/` is the repository's only npm project; run pnpm as `pnpm -C app`
(AGENTS.md).

## Audit (minor and major alike)

```bash
pnpm -C app outdated --json 2>/dev/null | nix run .#deps-audit -- npm-outdated-audit
pnpm -C app audit --json 2>/dev/null | nix run .#deps-audit -- npm-security-audit
```

The outdated report splits minor from major. The security report splits by
severity and fix availability; note `fixable-breaking` — those fixes need
`--force` and may introduce breaking changes.

## Update — minor

`pnpm -C app update` moves transitive dependencies only: every entry in
`app/package.json` is an exact version, which is a range with nothing to move
within. From pnpm's point of view any change to an exact pin exceeds its range,
whether the number that moves is the major or not — so a direct dependency
reaching a newer version is always the major flow, patch or not.

Only `app/pnpm-lock.yaml` changes. Nothing rewrites `package.json` afterwards.

## Update — major

For each confirmed bump:

```bash
pnpm -C app add --save-exact <pkg>@latest
```

`app/.npmrc` sets `save-exact=true` and `pnpm update --latest` preserves it, so
the exact form holds even when the flag is forgotten.

Before bumping `vite` past a major boundary, check `vite-plugin-elm`'s
`peerDependencies` range for `vite`, in
`app/node_modules/vite-plugin-elm/package.json`.

## Verify

```bash
nix run .#test
nix run .#build
```
