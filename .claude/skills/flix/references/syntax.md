# Parsing, names, modules, records, Java

## Seen in this repository

### A parse error travels

A parse error inside a module swallows the declarations after it, and what the
compiler then reports is somewhere else entirely:

```
E6629  src/Round/Cars.flix   Expected <expression> before 'pub'.
E0237  src/Round/Laps.flix   Definition 'Round.Cars.read' is not accessible
                             from the module 'Round.Laps'.
```

Nothing is wrong with visibility. `Round.Cars.read` lost its `pub` because the
parser never reached it. **Fix the first parse error and re-run before reading
any resolution error.**

### `not` is not a function value

`|> not` fails with `Unable to unify the function type 'Bool -> Bool' with the
non-function type 'Bool'`. Write `not List.isEmpty(found)`, binding the pipeline
to a `let` first if it is long — which is what `Round.Laps.loaded` and
`Round.Cars.loaded` do.

### Reserved words are not usable as identifiers

`select`, `where`, `run`, `and`, `or`, `not`, `query`, `from`, `into`, `region`,
`spawn`, `handler`, `discard`, `force` and friends. The workarounds already in
the tree: three `where_` (`Round.Summary`, `Round.Index`, `Cli.Load.Validation`)
and `Sql.selectOne`, whose docstring says it is named for `select` being a
keyword.

The error is usually a parse error at a distance rather than anything naming the
word.

### A doc comment cannot go inside a record type alias

```
E6289  Misplaced doc-comment(s).  Hint: doc-comments must annotate declarations.
```

Put the note above the alias and name the field in it, as `Server.Api.Response`
does for `cause`.

### A module is declared in one place, and there is no wildcard `use`

`mod Sql { ... }` cannot span two files. Splitting it means submodules, and
since Flix has no wildcard `use`, every call site would grow a segment or a
`use` line per name. That is why `src/Sql.flix` is one 600-line file, and the
reason belongs in `flix/README.md` rather than in a comment.

### Java interop

- `import` goes inside the module, not at the top of the file.
- A Java call's return value needs a type annotation where Flix has to know it:
  `let code: Int32 = e.getErrorCode();`.
- Catch clauses name the imported class (`case e: SQLException`), not `##java...`.

### Standard library names that catch people out

The names this tree reaches for, when the obvious one is not there:
`Option.getWithDefault`, `Option.toOk`, `Int32.remainder`, `Result.traverse`,
`List.forEachWithIndex`. Check `https://api.flix.dev/` before guessing at a
name — a wrong guess reads as a type error somewhere else.

## Reported elsewhere, not hit here

From `ababup1192/sqlfx`'s `docs/flix-conventions.md` and `docs/spikes.md`:

- **A reserved word as a record field name can hang the type checker.** Flix
  does not stop at the parse error; it carries a broken tree into type checking,
  which can then run without terminating and without printing anything. The
  report is six hours lost to `{ into = ..., from = ... }`. If a build produces
  no output and does not finish, suspect a field name before anything else.
- Records do not derive `Eq`, so a test comparing two of them maps to tuples or
  to an enum first.
- A dotted module (`mod Example.Users`) can fail to resolve both its types and
  its functions; top-level `def`s share one namespace across files.
- `BigDecimal` literals are written `1.5ff`.
