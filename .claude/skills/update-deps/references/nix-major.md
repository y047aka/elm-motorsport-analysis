# Nix (major)

Upgrade the nixpkgs channel to a newer release.

## Audit

Read `flake.nix` to extract the current channel name. Channels follow the pattern `nixpkgs-YY.MM-darwin` (e.g. `nixpkgs-25.05-darwin`). NixOS releases new stable channels every 6 months: May (05) and November (11).

```bash
node -e "
  const fs = require('fs');
  const flake = fs.readFileSync('flake.nix', 'utf8');
  const m = flake.match(/nixpkgs\/nixpkgs-([\d]+)\.([\d]+)-darwin/);
  if (!m) { console.log('channel: unknown'); process.exit(0); }
  const [, yy, mm] = m;
  console.log('current channel: nixpkgs-' + yy + '.' + mm + '-darwin');

  const now = new Date();
  const year = now.getFullYear() % 100;
  const month = now.getMonth() + 1;

  const channels = [];
  for (let y = 24; y <= year; y++) {
    for (const releaseMonth of [5, 11]) {
      const releaseDate = new Date(2000 + y, releaseMonth - 1, 1);
      if (releaseDate <= now) {
        const mm2 = String(releaseMonth).padStart(2, '0');
        channels.push({ y, mm: mm2, label: y + '.' + mm2 });
      }
    }
  }

  const latest = channels[channels.length - 1];
  const currentNum = parseInt(yy) * 100 + parseInt(mm);
  const latestNum  = latest.y * 100 + parseInt(latest.mm);

  if (latestNum > currentNum) {
    console.log('latest channel:  nixpkgs-' + latest.label + '-darwin  <- UPGRADE AVAILABLE');
  } else {
    console.log('latest channel:  nixpkgs-' + latest.label + '-darwin  (up to date)');
  }
"
```

## Update

Edit the `nixpkgs.url` in `flake.nix` to point to the new channel, then run `nix flake update`.

Example (upgrading from 25.05 to 25.11):
```nix
# before
nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";

# after
nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
```

After editing `flake.nix`, run:

```bash
nix flake update
```

## Verify

```bash
nix run .#test
nix run .#cli-test
nix run .#build
```
