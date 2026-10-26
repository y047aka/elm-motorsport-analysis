# Verifying a change to /flix

## The two commands

```bash
rm -rf flix/build && nix run .#flix-test
```

`flix build` and `flix test` are incremental and CI is not. A cold run is the
only one worth believing.

## The other project

The pipeline at the `circuits/` root — which holds the probe's readings as its
`-- probe` word and the timing report's as its `-- timing-lines` one — is a Flix
project with
its own `flix.toml`, and nothing about a green `.#flix-test` says anything about it:

```bash
nix run .#geometry-test    # the geometry project's `flix test`: survey, probe and
                           # report readings, the last through nine symlinks
```

The run starts inside the project,
which is the only place `flix` finds its `flix.toml`.

The report compiles nine sources *out of* `flix/src` by symlink, so a change to one of
those is compiled twice and tested twice, once on each side of the link — and a symlink
that did not
survive a checkout fails as `Undefined use`, reported in the module that needed it
rather than in the link. Nothing else is linked into
the project: it asks
OpenStreetMap and reads kept Overpass answers and geometry files, writing a kept answer,
a served geometry or an overlay only when told to, while its own tests hand every reading
a string rather than a file — so `.#geometry-test` opens and writes nothing. It
needs no jar to be tested: the command runs the interpreter.

## What is written where

`flix build` typechecks and writes nothing; `flix build-jar` writes
`artifact/<project>.jar`, and an interrupted one leaves a jar with no central
directory in it, newer than every source it was made from — which is why the flake's
server app keeps its own `$jar.ok` marker beside it instead of trusting an mtime.
There is no `artifact/` to clear before believing a run either: it is output, and
nothing reads it back to decide what to compile. The directory that is worth leaving
alone is `lib/`, the resolution cache CI restores — clearing it makes the next run ask
Maven Central again, which answers a busy runner with a 429.

A second Flix project writes those same two directories wherever it is run, so it takes
a `.gitignore` with it: `circuits/` holds one.

## The stack check

The type checker recurses once per expression and the thread it runs on gets a
smaller stack on Linux than on macOS, so a deep enough chain compiles here and
overflows in CI. Run the compiler directly with the stack cut down:

```bash
# the compiler the flake app uses -- see below, the obvious find is wrong
cat "$(nix eval --raw .#apps.aarch64-darwin.flix-build.program)"

rm -rf flix/build && mkdir -p flix/build
nix shell nixpkgs#jdk21_headless --command bash -c \
  'cd flix && java -Xss704k -jar /nix/store/<flix-0.79.0>/share/java/flix/flix.jar build'
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
  prints, take the `flix-0.79.0` store path out of it, and the jar is at
  `share/java/flix/flix.jar` under it.

## What CI runs

`test.yml` on ubuntu-24.04 runs the Elm tests, then each Flix project's own tests —
the CLI's, the report's and the geometry commands' (the probe's readings among
them) — then the circuit
tools' and `tsc`. A failure
there that passes locally is either the cold build or the stack.
