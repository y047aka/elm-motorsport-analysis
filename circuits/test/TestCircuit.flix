/// The layout of this repository's own files, held to one spelling. The pipeline
/// writes into three directories and lists two of them looking for what no config
/// names, so the directories and the names inside them are stated once, in
/// `Circuit.flix`; the config still authors its own geometry path, the way it authors
/// its timing figures twice over, and this is where those authored paths are laid
/// against the words that name them.
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
    /// itself is written by `keptAnswer` and `keptAtlas`. Those two paths are made
    /// from those two names here, so a name authored a third time — beside the writer
    /// of one file, say — is the directory the warning stops calling out.
    @Test
    def testTheWarningLooksForTheFilesTheBuildersWrite(): Unit \ Assert =
        foreach (circuit <- Circuit.circuits()) {
            Assert.assertTrue(
                List.memberOf(Circuit.lastPart(Circuit.keptAnswer(circuit)), Circuit.keptNames())
            );
            Assert.assertTrue(
                List.memberOf(Circuit.lastPart(Circuit.keptAtlas(circuit)), Circuit.keptNames())
            );
            Assert.assertTrue(
                String.startsWith({prefix = "${Circuit.evidenceDir()}/${circuit#word}/"}, Circuit.keptAnswer(circuit))
            )
        }

    /// Kept evidence and served bytes stand apart: the answer and the atlas line are
    /// never served, and no served file is kept evidence. A name shared between the
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
}
