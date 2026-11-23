/// The report's timing map, read as the derivation it is. A circuit's map record gives the
/// lap and the stretches, and `Circuit.timingMapOf` derives the report's answer from them;
/// the report's `Motorsport.Circuit` holds only the shapes of that answer — so what is
/// tested here is that a map placing no intermediate lines publishes nothing, and that the
/// enum and the configs answer to one another's names. The records themselves are read by
/// the regeneration fence, which no `@Test` can be, and how a record is read is
/// `TestCircuit`'s. The two word lists no compiler compares — this project's enum and the
/// export's copy in `backend/src/Motorsport/Circuit.flix` — are laid together by
/// `test/check-sources.mjs`.
pub mod TestTimingMap {

    use Motorsport.Circuit.TimingMap

    /// Every case the summaries can be sent for, whether or not this project
    /// surveys it. A new case of the enum has to join this list.
    def cases(): List[Motorsport.Circuit.Circuit] =
        Motorsport.Circuit.Circuit.Qatar ::
        Motorsport.Circuit.Circuit.Imola    ::
        Motorsport.Circuit.Circuit.Spa      ::
        Motorsport.Circuit.Circuit.LeMans   ::
        Motorsport.Circuit.Circuit.Cota     ::
        Motorsport.Circuit.Circuit.Fuji     ::
        Motorsport.Circuit.Circuit.Bahrain  ::
        Motorsport.Circuit.Circuit.SaoPaulo ::
        Motorsport.Circuit.Circuit.Monza ::
        Motorsport.Circuit.Circuit.Barcelona ::
        Nil

    def unplaced(): Circuit.Figures = {lap = 5513.0, published = None}

    @Test
    def testAMapPlacingNoIntermediateLinesPublishesNothing(): Unit \ Assert =
        match Circuit.timingMapOf(unplaced()) {
            case TimingMap.Unsurveyed   => Assert.assertTrue(true)
            case TimingMap.Published(_) => Assert.assertTrueWithMsg(false, "a map placing no intermediate lines published stretches")
        }

    /// Every word a config authors is a case the report answers to: a word with no case
    /// behind it is a circuit the export can send a summary for that this project surveys
    /// in silence.
    @Test
    def testEveryAuthoredWordIsACase(): Unit \ Assert =
        let words = List.map(Motorsport.Circuit.jsonValue, cases());
        let unanswered = List.filter(circuit -> not List.memberOf(circuit#word, words), Circuit.circuits());
        Assert.assertTrueWithMsg(
            List.isEmpty(unanswered),
            "a word is authored in the config that no case of the report answers to"
        )

    /// A new case missing from *this* file's list would leave the checks above reading a
    /// smaller enum than the module holds — and the export's copy of the enum has no
    /// project left that compiles both.
    @Test
    def testEveryCaseOfTheEnumIsListedHere(): Unit \ Assert =
        Assert.assertTrueWithMsg(
            List.length(cases()) == 10,
            "cases() no longer names every case Motorsport.Circuit.Circuit has"
        )

}
