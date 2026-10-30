# Rust

`app/src-tauri/Cargo.toml` is the repository's only Rust package (AGENTS.md).

## Audit

```bash
cargo update --dry-run --manifest-path app/src-tauri/Cargo.toml 2>&1 | nix run .#deps-audit -- rust-minor-audit
nix run .#deps-audit -- rust-major-audit
```

The minor report splits compatible updates into minor and patch. The major
report parses every Cargo.toml and runs `cargo search` per crate; it counts a
major as an increase of the leftmost non-zero component (`0.8 → 0.9` included).

## Update

Minor:

```bash
cargo update --manifest-path app/src-tauri/Cargo.toml
```

Major: edit each confirmed crate's constraint in `Cargo.toml`
(`[dependencies]` and `[build-dependencies]`), then re-resolve with the same
`cargo update`. `tauri` and `tauri-build` are released together and must move
as a pair.

## Verify

```bash
cargo check --manifest-path app/src-tauri/Cargo.toml
```
