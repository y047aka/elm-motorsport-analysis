# Nix (major)

Upgrade the nixpkgs channel to a newer release.

## Audit

Read `flake.nix` to extract the current channel name. Channels follow the pattern `nixpkgs-YY.MM-darwin` (e.g. `nixpkgs-25.05-darwin`). NixOS releases new stable channels every 6 months: May (05) and November (11).

```bash
cargo run --manifest-path .claude/skills/update-deps/scripts/Cargo.toml -- nix-channel-audit
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
