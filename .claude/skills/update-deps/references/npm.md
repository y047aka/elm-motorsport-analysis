# npm

## Audit

```bash
npm outdated || true
npm audit || true
```

Note whether each update is a patch, minor, or major bump.
For `npm audit` findings, note whether fixes require `--force` (which may be a breaking change) and report them to the user.

## Update

Run `npm update` for semver-compatible updates. For major bumps that exceed the semver range, list them separately and ask if the user wants `npm install <pkg>@latest`.

### Special handling

- **Playwright version change**: If `@playwright/test` is updated, remind the user to run `npx playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.

## Verify

```bash
nix run .#test
nix run .#build
```
