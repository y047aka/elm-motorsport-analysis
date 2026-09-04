# Nix (major)

Upgrade the nixpkgs channel to a newer release.

## Audit

Read `flake.nix` to extract the current channel name. This repository pins `nixos-YY.MM` (e.g. `nixos-26.05`); the audit also recognises the `nixpkgs-YY.MM-darwin` spelling. NixOS releases new stable channels every 6 months: May (05) and November (11).

```bash
nix run .#deps-audit -- nix-channel-audit
```

## Update

Edit the `nixpkgs.url` in `flake.nix` to point to the new channel, then run `nix flake update`.

Example (upgrading from 25.11 to 26.05):
```nix
# before
nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

# after
nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
```

After editing `flake.nix`, run:

```bash
nix flake update
```

## Verify

```bash
nix run .#test
nix run .#flix-test
nix run .#build
```
