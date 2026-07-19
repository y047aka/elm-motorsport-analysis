///
/// The process boundary: reading stdin, and describing what a subcommand
/// wants written where.
///
/// Every subcommand returns an `Output` instead of printing as it goes, so
/// "what happened" stays data until the single `emit` call in `main`. That
/// keeps the decision of *what* to report separate from *how* it reaches
/// the terminal, and makes command results comparable in tests without
/// capturing a stream.
///
/// `Output` is opaque: it can only be built through the constructors below,
/// so an exit code never disagrees with the streams it came with. Combining
/// outputs is `append`/`empty` — a monoid — and the `SemiGroup`/`Monoid`
/// instances make that structure available to the stdlib's combinators.
///
mod DepsAudit.Cli {

    use Sys.Console

    /// Lines destined for each stream, plus the exit code. Values in
    /// `stdout`/`stderr` may themselves be multi-line.
    pub enum Output({
        stdout = List[String],
        stderr = List[String],
        exitCode = Int32
    })

    // --- constructing ---

    pub def empty(): Output =
        Output.Output({ stdout = Nil, stderr = Nil, exitCode = 0 })

    pub def ok(lines: List[String]): Output =
        Output.Output({ stdout = lines, stderr = Nil, exitCode = 0 })

    pub def okText(text: String): Output =
        ok(text :: Nil)

    pub def fail(message: String): Output =
        failLines(message :: Nil)

    pub def failLines(lines: List[String]): Output =
        Output.Output({ stdout = Nil, stderr = lines, exitCode = 1 })

    // --- combining ---

    /// Concatenate both streams in order. A non-zero exit code from the
    /// left wins, so a failure is never masked by later success.
    pub def append(a: Output, b: Output): Output =
        Output.Output({
            stdout = stdout(a) ::: stdout(b),
            stderr = stderr(a) ::: stderr(b),
            exitCode = if (exitCode(a) != 0) exitCode(a) else exitCode(b)
        })

    /// Lift a `Result` whose `Ok` is the text to print.
    pub def fromResult(r: Result[String, String]): Output =
        fromResultWith(okText, r)

    /// Lift a `Result`, deciding the output from the `Ok` value.
    pub def fromResultWith(f: a -> Output \ ef, r: Result[String, a]): Output \ ef =
        match r {
            case Err(e) => fail(e)
            case Ok(v)  => f(v)
        }

    /// Run `next` only if what came before succeeded, appending its output.
    pub def andThen(next: Unit -> Output \ ef, out: Output): Output \ ef =
        if (exitCode(out) != 0) out else append(out, next())

    /// Apply `f` to each element in order, concatenating the outputs and
    /// skipping the remainder once one fails. Output already produced by
    /// earlier elements is kept — a partial run reports what it managed.
    pub def traverseUntilFailure(f: a -> Output \ ef, xs: List[a]): Output \ ef =
        List.foldLeft((acc, x) -> if (exitCode(acc) != 0) acc else append(acc, f(x)), empty(), xs)

    // --- observing ---

    pub def stdout(out: Output): List[String] =
        let Output.Output(r) = out;
        r#stdout

    pub def stderr(out: Output): List[String] =
        let Output.Output(r) = out;
        r#stderr

    pub def exitCode(out: Output): Int32 =
        let Output.Output(r) = out;
        r#exitCode

    // --- process boundary ---

    /// Read all of stdin as one string (lines joined with '\n').
    pub def readStdin(): String \ Console =
        def loop(acc) = match Console.readln() {
            case Some(line) => loop(line :: acc)
            case None       => acc
        };
        loop(Nil) |> List.reverse |> List.join("\n")

    /// Write an `Output` to the real streams and return its exit code.
    /// The only place in the program that prints.
    pub def emit(out: Output): Int32 \ Console =
        List.forEach(Console.println, stdout(out));
        List.forEach(Console.eprintln, stderr(out));
        exitCode(out)

}

instance SemiGroup[DepsAudit.Cli.Output] {
    pub def combine(a: DepsAudit.Cli.Output, b: DepsAudit.Cli.Output): DepsAudit.Cli.Output =
        DepsAudit.Cli.append(a, b)
}

instance Monoid[DepsAudit.Cli.Output] {
    pub def empty(): DepsAudit.Cli.Output =
        DepsAudit.Cli.empty()
}
