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

Bumping the `flix` version in `flake.nix` is a run of both Flix projects:
`circuits/` holds its own `flix.toml`, and a project left behind fails as its
own red rather than as the flake not evaluating.

## Verify

```bash
nix run .#test
nix run .#flix-test
nix run .#geometry-test
nix run .#build
```

A new nixpkgs can move `playwright-test`, which the VRT renders with, so run
`nix run .#test-vrt` too; baselines that move are refreshed with
`nix run .#update-snapshots-ci` (AGENTS.md: never `.#update-snapshots-vrt`
for a landed baseline).
