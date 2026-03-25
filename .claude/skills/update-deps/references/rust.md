# Rust

## Audit

```bash
cargo update --dry-run --manifest-path cli/Cargo.toml
```

## Update

```bash
cargo update --manifest-path cli/Cargo.toml
```

## Verify

```bash
nix run .#cli-test
```
