# Effects, handlers and signatures

## Seen in this repository

### There is no subeffecting in argument position

A `\ DbRead` function is not accepted where `\ Db` is expected, even though
`Db` is the larger set.

```
E6218  Mismatched effect(s): expected '{SqlRead, SqlWrite}', but got 'SqlRead'.
       function expected argument with effect(s) '{SqlRead, SqlWrite}'
       function argument with effect(s) 'SqlRead' was passed
```

Two fixes, and which one is right depends on whether the callee cares:

- **The parameter is effect-polymorphic.** Take `f: Unit -> a \ ef` and subtract
  in the return type: `\ (ef - {SqlRead, SqlWrite}) + IO`. This is what
  `Main.onRoot` does — its stage may be a load (both halves) or an export (reads
  only) — and what `Round.TestSupport.onRound` does for the same reason.
- **The parameter is narrowed to the half the callers use.** `Server.Api.answer`
  takes `Entry -> String \ DbRead`.

Do not widen the caller to fit. A reader that declares `\ Db` to satisfy a
parameter has given up what the split was for.

### `E6217 Unused effect` points at the alias, not at the def

The error is reported at the line where the effect *name* appears — which, when
signatures use an alias, is the alias declaration in `src/Db.flix`:

```
E6217  src/Db.flix
30 | pub type alias Db = {SqlRead, SqlWrite}
                                   ^^^^^^^^  Unused effect: 'SqlWrite'
```

That file is fine. The def at fault is somewhere else: it declares an effect
(usually by naming an alias) that its body no longer performs. Both times this
happened here, a function had become read-only while still saying `\ Db`
(`Cli.Export.runAll`), or had stopped raising (`Db.rollback`, which discards the
op's failure and so is `\ SqlWrite` rather than `\ DbWrite`).

Grep for the alias to get the candidates; the compiler will not narrow it for
you.

### A handler body runs outside the `run` it belongs to

An operation raised inside a handler body does not reach the handlers the
caller installed inside that `run` — it passes them and lands outside. So an
operation that can fail cannot raise the failure from the handler.

The way out, which is the shape of `Db`: the operation **answers with a
`Result`**, and a thin wrapper raises it in the caller's own context.

```flix
pub eff SqlRead {
    def fetch(sql: String, params: List[Db.Value]): Result[Db.Error, ...]
}

// mod Db -- the caller reaches this, never the op
pub def fetch(sql: String, params: List[Value]): ... \ DbRead =
    SqlRead.fetch(sql, params) |> orRaise
```

`Db.orRaise` is that step. Nothing outside `mod Db` calls an operation.

### Subtraction takes a set or an alias

`ef - DbErr`, `ef - {SqlRead, SqlWrite}` and `ef - Db` (an alias of a set) all
work. Prefer the alias where one exists, and remember that a boundary that
handles the error effect too has to subtract it as well: `withConnection` is
`(ef - {SqlRead, SqlWrite, DbErr}) + IO + DbErr`, and leaving `DbErr` out of the
subtraction fails as `E6469 Unable to unify the effect formulas` with two
formulas that differ only by that term.

### A failure effect wants one op, not one per kind

`DbErr` has a single `fail(error: Db.Error): Void`. An operation returning
`Void` does not resume, so the caller's code is written as though it always
succeeds, and `Db.runWithError` turns it back into a `Result` at the boundary.

An op per error kind buys partial handling — catching one kind and letting the
rest fly. Nothing here does that, so nothing here has one.

### `bug!` takes a `String`

`bug!(cause)` where `cause` is a `Db.Error` does not compile; `bug!("${cause}")`
does.

## Reported elsewhere, not hit here

From `ababup1192/sqlfx`'s `docs/spikes.md` (same compiler version):

- `spawn`'s body is limited to `(Chan + IO + NonDet) & e0`; a custom effect
  cannot be raised inside one.
- Handlers can be chained on one `run` — `run { } with handler A { } with
  handler B { }` — rather than nested. `Db.runRecording` nests two `run`s and
  compiles; the chained form is untried here.
- Measured handler overhead: a recording handler costs ~0.6µs per operation and
  a logging handler that forwards ~1.3µs, both two orders below a JDBC round
  trip. Layering handlers is not a performance question.
