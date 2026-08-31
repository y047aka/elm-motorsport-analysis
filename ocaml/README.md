# ocaml

The CLI of `/flix`, written again in OCaml. One module here per module there,
same names in OCaml spelling, same tests. It is checked the only way a copy can
be: it writes the same bytes as the Flix CLI for all fourteen rounds the
calendar lists, `index.json` included.

```
nix run .#ocaml-cli-build
nix run .#ocaml-cli-test
nix run .#ocaml-cli-run
```

## Module names

`lib/` is flat and every file spells its Flix path: `Util.Csv.Decode` is
`util_csv_decode.ml`, `Cli.Stages.Transform` is `cli_stages_transform.ml`. Dune
can nest modules by directory, but a directory and a module of the same name
cannot both exist, and `Cli.Stages` is both — a module with `run_all` in it and
the parent of seven stages. Flattening costs the hierarchy; the alternative
costs a rename at the one place the hierarchy is load-bearing.

Inside a module, Flix's `use Util.Duration` is `module Duration = Util_duration`.

## Where the two differ

Flix reaches its standard library for three things OCaml's answers differently,
so they are written out here:

- **`util_getopt.ml`** — the slice of `Util.GetOpt` that `Cli.Args` uses. OCaml's
  `Arg` parses into refs rather than returning options and non-options.
- **`util_parse.ml`** — `Int32.fromString` and `Float64.fromString` are Java's
  parsers, which reject the `1_000` and `0x10` spellings OCaml's accept. A CSV
  field is text a publisher wrote, so what is not a plain number has to fail.
- **`Util_parse.split_on_char`** — Java's `split` drops the empty pieces a
  trailing separator leaves, so `0:` is one field to Flix and two to OCaml. The
  feed writes a blank large-sector column that way, and read as two fields it is
  a decoding error rather than zero.

Three more, each visible in the output or in the types:

- **Floats** render as the shortest decimal that reads back as the same double,
  which is what the JVM writes. OCaml's `string_of_float` stops at twelve
  significant digits and rounds a track share off in the fifteenth.
- **`util_csv_parser.ml`** keeps one `parse_help` where the Flix source keeps
  three. The two specialised copies are there for parity with elm-csv, whose
  reason was JavaScript codegen; nothing downstream of that survives here.
- **Names the language took**: `class` is a keyword, so a car's is `class_`; a
  record field cannot be shared by two types in one module, so a mini-sector's
  `elapsed` is `mini_elapsed`; `None` belongs to `option`, so an improvement flag
  of none is `No_improvement`.
