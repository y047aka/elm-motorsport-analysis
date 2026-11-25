# Nix

## Audit

```bash
nix run .#deps-audit -- nix-flakelock-audit   # minor: pinned revisions in flake.lock
nix run .#deps-audit -- nix-channel-audit     # major: this repo pins a nixos-YY.MM channel
```

## Update

Minor — re-pin every input within its current channel:

```bash
nix flake update
```

Major — point `nixpkgs.url` in `flake.nix` at the newer `nixos-YY.MM` branch,
then `nix flake update`.

Bumping the `flix` version in `flake.nix` needs a cold `.#flix-test` and
`.#sqlitefx-test`: both Flix projects in the tree build against it.

## Verify

```bash
nix run .#test
nix run .#flix-test
nix run .#build
```

A new nixpkgs can move `playwright-test`, which the VRT renders with, so run
`nix run .#test-vrt` too; baselines that move are refreshed with
`nix run .#update-snapshots-ci` (AGENTS.md: never `.#update-snapshots-vrt`
for a landed baseline).
