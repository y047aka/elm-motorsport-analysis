# Verifying a change to /flix

## The two commands

```bash
rm -rf flix/build && nix run .#flix-test
```

`flix build` and `flix test` are incremental and CI is not. A cold run is the
only one worth believing.

## The stack check

The type checker recurses once per expression and the thread it runs on gets a
smaller stack on Linux than on macOS, so a deep enough chain compiles here and
overflows in CI. Run the compiler directly with the stack cut down:

```bash
# the compiler the flake app uses -- see below, the obvious find is wrong
cat "$(nix eval --raw .#apps.aarch64-darwin.flix-build.program)"

rm -rf flix/build && mkdir -p flix/build
nix shell nixpkgs#jdk21_headless --command bash -c \
  'cd flix && java -Xss704k -jar /nix/store/<flix-0.75.1>/share/java/flix/flix.jar build'
```

704k is where the tree as it stands builds and 672k where it does not, so a
change that raises that number is the one to look at. What sets it today is
`Motorsport.Wec.decoder`.

Two things that waste time here:

- **`mkdir -p flix/build` is required.** Invoked as a bare jar the compiler does
  not create its own build directory, and answers `Error: Path not found: build`.
- **Finding the jar.** `find /nix/store -name 'flix*.jar' | head -1` finds this
  repository's own `flix/artifact/flix.jar` — the built server, not the
  compiler — and running `build` with it prints an error from *this application*
  (`Error: no database ...`), which reads like a broken checkout. The compiler
  is the one the flake app puts on `PATH`: read the wrapper the command above
  prints, take the `flix-0.75.1` store path out of it, and the jar is at
  `share/java/flix/flix.jar` under it.

## What CI runs

`test.yml` on ubuntu-24.04 runs the unit tests and the typecheck. A failure
there that passes locally is either the cold build or the stack.
