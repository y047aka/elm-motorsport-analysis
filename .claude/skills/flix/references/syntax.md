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
`use` line per name. That is why `src/Sql.flix` is one long file, and the
reason belongs in `flix/README.md` rather than in a comment.

### Java interop

- `import` goes inside the module, not at the top of the file.
- A Java call's return value needs a type annotation where Flix has to know it:
  `let code: Int32 = e.getErrorCode();`.
- Catch clauses name the imported class (`case e: SQLException`), not `##java...`.

### A literal does not widen to the integer the parameter wants

```
E7685  Unexpected argument: expected 'Int64', got 'Int32'.
```

An OpenStreetMap id is an `Int64` and a test writes `List#{way(1, 100.0)}`, which
reads as a number and is not one of the type the parameter asks for. Every literal
feeding an `Int64` field or argument carries the suffix: `way(1i64, 100.0)`,
`{ id = 7i64, ... }`. Seen in `circuits/test/TestCandidates.flix`.

### Only a labelled-record parameter is passed by name

`String.replace` is `replace(src: {src = String}, dst: {dst = String}, s: String)`.
Its first two parameters are records wearing a label and are passed `src = "'"`;
the third is a plain `String` and stays positional. Passing `s = text` gives:

```
E7685  Unexpected argument: expected 'String', got '{ s = String }'.
```

which reads like a string-vs-record confusion and is a call-site mistake. Write
`String.replace(src = "'", dst = "\"", text)` — as `circuits/test/TestOverpass.flix`
does to keep a JSON fixture readable. The same shape is why
`Assert.assertTrueWithMsg(cond, msg)` takes its message second and unlabelled, and
why `Assert.assertTrue` takes no message at all.

### Records do not have `Eq`

```
E7027  Equality is not defined on { lat = Float64, lon = Float64 }. Define or derive an
       instance of Eq.
```

`==` on tuples and on primitives is built in; on a record it is not, and so neither is
it on a `List` of records — `line == Nil` fails, not because the list is compared but
because its item is. `List.isEmpty(line)` says the same thing without asking for an
`Eq` the domain has no use for, and comparing the fields (`line#lat == 47.9`) is what a
test of a reading actually wants. Seen in `circuits/test/TestOverpass.flix`; the
alternative — an `Eq` instance per record — would say two places are the same place
without saying what that means.

### A record update is not written with `with`

The `{ r with field = v }` spelling — and the unbraced `r with field = v` — does not
parse in 0.79.0. The parser stops at the word `with` and the errors that follow point at
the record accessors a line or two later, so a failed update reads as trouble with `#` or
`${}` rather than with the update:

```
E6629  Expected '}' before 'with'.
E6629  Expected <declaration> before 'with'.
```

Write the whole record out instead: `Write.complete` builds its `{ circuit = ..., answer
= ..., asked = ..., fetch = ..., write = ... }` field by field rather than updating a
defaults record in place. All three spellings
were tried against the flake's own 0.79.0 compiler; none parses, so there is no `with`
form to fall back to — only the whole record.

### Standard library names that catch people out

The names this tree reaches for, when the obvious one is not there:
`Option.getWithDefault`, `Option.toOk`, `Int32.remainder`, `Result.traverse`,
`List.forEachWithIndex`, `List.range` (there is no `rangeTo`, and `range(b, e)` runs
from `b` inclusive to `e` exclusive, so the attempts a run makes are
`List.range(1, tries() + 1)`), `Result.flatMap` (there is no `andThen`), `Map.empty`
with `Map.insert` (there is no `Map.fromKeyValue`). Check
`https://api.flix.dev/` before guessing at a name — a wrong guess reads as a type
error somewhere else.

## Reported elsewhere, not hit here

From `ababup1192/sqlfx`'s `docs/flix-conventions.md` and `docs/spikes.md`:

- **A reserved word as a record field name can hang the type checker.** Flix
  does not stop at the parse error; it carries a broken tree into type checking,
  which can then run without terminating and without printing anything. The
  report is six hours lost to `{ into = ..., from = ... }`. If a build produces
  no output and does not finish, suspect a field name before anything else.
- A dotted module (`mod Example.Users`) can fail to resolve both its types and
  its functions; top-level `def`s share one namespace across files.
- `BigDecimal` literals are written `1.5ff`.
