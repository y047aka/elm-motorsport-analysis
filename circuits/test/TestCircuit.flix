/// The layout of this repository's own files, held to one spelling. The pipeline
/// writes into three directories and lists two of them looking for what no config
/// names, so the directories and the names inside them are stated once, in
/// `Circuit.flix`; the config still authors its own geometry path, the way it authors
/// its timing line, and this is where those authored paths are laid
/// against the words that name them, and where the map record a circuit's figures are
/// read from is read.
///
/// What is not tested here is the bytes a path leads to: that is the byte fence's and
/// `app/tests/geometry-contract.spec.ts`'s, each of which reads a real file.
pub mod TestCircuit {

    /// A config's geometry file is the file the app reaches for: the app asks
    /// `app/static/geometry/<word>.geojson` by the word the summary sends, and the
    /// fence compares the bytes at the config's `file`. One word and two paths is a
    /// fence over bytes nobody reads, and both stay green.
    @Test
    def testEveryConfigFilesItsOwnWordUnderTheServedDirectory(): Unit \ Assert =
        foreach (circuit <- Circuit.circuits())
            Assert.assertTrueWithMsg(
                circuit#file == "${Circuit.servedDir()}/${circuit#word}${Geometry.extension()}",
                "${circuit#word}: its geometry is served at ${circuit#file}, not under its own word"
            )

    /// The warning that calls out a directory no circuit answers to looks for
    /// `keptNames` in a directory and prints paths under `evidenceDir`; the evidence
    /// itself is written by `keptAnswer`. That path is made from that name here, so a
    /// name authored a second time — beside the writer of the file, say — is the
    /// directory the warning stops calling out.
    @Test
    def testTheWarningLooksForTheFilesTheBuildersWrite(): Unit \ Assert =
        foreach (circuit <- Circuit.circuits()) {
            Assert.assertTrue(
                List.memberOf(Circuit.lastPart(Circuit.keptAnswer(circuit)), Circuit.keptNames())
            );
            Assert.assertTrue(
                String.startsWith({prefix = "${Circuit.evidenceDir()}/${circuit#word}/"}, Circuit.keptAnswer(circuit))
            )
        }

    /// Kept evidence and served bytes stand apart: the answer is never served, and no served file is kept evidence. A name shared between the
    /// two is a fence reading its own evidence as the drawing, or a warning calling a
    /// served file an unmapped circuit.
    @Test
    def testKeptEvidenceIsNamedApartFromWhatIsServed(): Unit \ Assert =
        let served = List.map(circuit -> Circuit.lastPart(circuit#file), Circuit.circuits());
        Assert.assertTrue(List.isEmpty(List.filter(name -> List.memberOf(name, served), Circuit.keptNames())))

    /// The words the configs are authored for are the words a run can name, which is
    /// what `Regenerate` walks and what a wrong one is refused by. A config whose word
    /// answers to no word — a duplicate, say — is a circuit the fence never reaches.
    @Test
    def testEveryCircuitAnswersToItsOwnWord(): Unit \ Assert =
        foreach (circuit <- Circuit.circuits())
            Assert.assertTrue(
                Option.map(found -> found#word, Circuit.byWord(circuit#word)) == Some(circuit#word)
            );
        Assert.assertTrue(
            List.length(Circuit.circuits()) == List.length(List.map(c -> c#word, Circuit.circuits()) |> List.distinct)
        )

    /// Exactly one grounding, and a box's two extras come with it: the readers each
    /// dispatch on one of the pair, and a config authoring both or neither is an
    /// ambiguity those readers each resolve a different way. A box names no member to
    /// time from, so its `timingLine` is the only thing its zero can stand on.
    @Test
    def testEveryCircuitAuthorsExactlyOneGrounding(): Unit \ Assert =
        foreach (circuit <- Circuit.circuits()) {
            let grounded = match (circuit#relation, circuit#box) {
                case (Some(_), None) => true
                case (None, Some(_)) => Option.nonEmpty(circuit#timingLine)
                case _               => false
            };
            Assert.assertTrueWithMsg(
                grounded,
                "${circuit#word}: relation and box are not exactly one, or a box authors no line"
            )
        }

    /// A record as a map gives it: the centreline, and the two intermediate lines.
    def record(lines: String): String =
        "{\"circuit\": \"A circuit\", \"season\": 2026, \"lengths\": {\"centerline\": {\"metres\": 13625.70, \"printed\": \"Centerline: 13.625,70 m\"}}, \"lines\": {${lines}}}"

    @Test
    def testTheStretchesAreTheDistancesBetweenTheLinesAsTheMapPrintsThem(): Unit \ Assert =
        let both = "\"intermediate1\": {\"metres\": 1900.70}, \"intermediate2\": {\"metres\": 7672.13}";
        match Circuit.figuresOf(record(both)) {
            case Err(problem) => Assert.assertTrueWithMsg(false, problem)
            case Ok(figures) =>
                Assert.assertTrue(figures#lap == 13625.7);
                // To the hundredth the map prints, not to the double a subtraction leaves.
                Assert.assertTrue(
                    Option.map(published -> published#stretches, figures#published) == Some(1900.7 :: 5771.43 :: 5953.57 :: Nil)
                );
                Assert.assertTrue(
                    Option.map(published -> published#source, figures#published) == Some("the 2026 circuit map")
                )
        }

    @Test
    def testAMapPlacingOneIntermediateLinePublishesNoStretches(): Unit \ Assert =
        match Circuit.figuresOf(record("\"intermediate1\": {\"metres\": 1900.70}")) {
            case Err(problem) => Assert.assertTrueWithMsg(false, problem)
            case Ok(figures)  => Assert.assertTrue(Option.isEmpty(figures#published))
        }

    @Test
    def testARecordWithNoCentrelineIsRefused(): Unit \ Assert =
        match Circuit.figuresOf("{\"season\": 2026, \"lengths\": {}, \"lines\": {}}") {
            case Err(problem) => Assert.assertTrue(String.contains({substr = "lengths.centerline.metres"}, problem))
            case Ok(_)        => Assert.assertTrue(false)
        }

    @Test
    def testARecordWhoseLinesStandOutOfOrderIsRefused(): Unit \ Assert =
        let swapped = "\"intermediate1\": {\"metres\": 7672.13}, \"intermediate2\": {\"metres\": 1900.70}";
        let past = "\"intermediate1\": {\"metres\": 1900.70}, \"intermediate2\": {\"metres\": 13700.0}";
        Assert.assertTrue(Result.isErr(Circuit.figuresOf(record(swapped))));
        Assert.assertTrue(Result.isErr(Circuit.figuresOf(record(past))))
}
