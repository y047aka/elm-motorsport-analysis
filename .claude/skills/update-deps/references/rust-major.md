# Rust (major)

Major version updates for Rust crates (leftmost non-zero version component increases).

The workspace root is `cli/Cargo.toml` with members `cli/` and `motorsport/`.

## Audit

```bash
cargo run --manifest-path .claude/skills/update-deps/scripts/Cargo.toml -- rust-major-audit
```

The script parses all Cargo.toml files, runs `cargo search` for each crate, and classifies results. A **major bump** is when the leftmost non-zero version component increases (e.g., `0.8 → 0.9`, `1.x → 2.x`). Focus on the `major updates` section.

## Update

For each crate with a confirmed major version bump, update its version constraint in the relevant file:
- `cli/Cargo.toml` — workspace-level dependencies (`[workspace.dependencies]`)
- `cli/cli/Cargo.toml` — CLI-specific dependencies
- `cli/motorsport/Cargo.toml` — motorsport library dependencies

Then re-resolve:

```bash
cargo update --manifest-path cli/Cargo.toml
```

## Verify

```bash
nix run .#cli-test
```
