# npm

## Audit

```bash
npm outdated || true
npm audit || true
```

Note whether each update is a patch, minor, or major bump.
For `npm audit` findings, note whether fixes require `--force` (which may be a breaking change) and report them to the user.

## Update

Run `npm update --save` for semver-compatible updates.

After updating, pin all dependency versions by stripping `^` / `~` prefixes:

```bash
node -e "
const fs = require('fs');
const files = ['package.json', 'app/package.json', 'package/package.json', 'review/package.json'];
for (const f of files) {
  const pkg = JSON.parse(fs.readFileSync(f, 'utf8'));
  for (const key of ['dependencies', 'devDependencies']) {
    if (!pkg[key]) continue;
    for (const [name, ver] of Object.entries(pkg[key])) {
      pkg[key][name] = ver.replace(/^[\^~]/, '');
    }
  }
  fs.writeFileSync(f, JSON.stringify(pkg, null, 2) + '\n');
}
"
```

For major bumps that exceed the semver range, list them separately and ask if the user wants `npm install --save-exact <pkg>@latest`.

### Special handling

- **Playwright version change**: If `@playwright/test` is updated, remind the user to run `npx playwright install` and warn that VRT snapshots may need updating via `nix run .#test-vrt`.

## Verify

```bash
nix run .#test
nix run .#build
```
