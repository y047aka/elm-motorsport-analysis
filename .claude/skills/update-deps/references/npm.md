# npm

## Audit

```bash
npm outdated || true
```

Note whether each update is a patch, minor, or major bump.

## Update

Run `npm update` for semver-compatible updates. For major bumps that exceed the semver range, list them separately and ask if the user wants `npm install <pkg>@latest`.

### Special handling

- **Playwright version change**: If `@playwright/test` is updated, remind the user to run `npx playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.

## Verify

```bash
nix run .#test
nix run .#build
```
