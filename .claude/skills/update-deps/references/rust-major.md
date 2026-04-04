# Rust (major)

Major version updates for Rust crates (leftmost non-zero version component increases).

The workspace root is `cli/Cargo.toml` with members `cli/` and `motorsport/`.

## Audit

Extract direct dependencies and check the latest published version for each:

```bash
node .claude/skills/update-deps/scripts/rust-deps-parse.cjs | while read crate constraint; do
  latest=$(cargo search "$crate" --limit 1 2>/dev/null | grep "^$crate " | grep -o '"[^"]*"' | head -1 | tr -d '"')
  echo "$crate: constraint=$constraint latest=${latest:-unknown}"
done
```

A **major bump** is when the leftmost non-zero version component increases (e.g., `0.8 → 0.9`, `1.x → 2.x`). List these separately for confirmation.

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
