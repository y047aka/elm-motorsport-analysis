# Nix (minor)

Update flake inputs to the latest commit within the current channel.

## Audit

Check pinned revision dates in flake.lock:

```bash
nix run .#deps-audit -- nix-flakelock-audit
```

## Update

```bash
nix flake update
```

## Verify

```bash
nix run .#test
nix run .#flix-test
nix run .#build
```

A new nixpkgs can move `playwright-test`, which the VRT renders with, so run
`nix run .#test-vrt` as well; baselines that move are refreshed with
`nix run .#update-snapshots-ci`.
