/// The report's timing map, read as the derivation it is. A circuit's config says how
/// it is surveyed and whether its organiser re-issues its map, its map record gives the
/// lap and the stretches, and `Circuit.timingMapOf` derives the report's answer from the
/// two; the report's `Motorsport.Circuit` holds only the shapes of that answer — so what
/// is tested here is the derivation itself: that a map's published stretches reach the
/// report unchanged, that a re-issued map is refused with the config's own words, that a
/// map placing no intermediate lines publishes nothing, and that the enum and the configs
/// answer to one another's names. The records themselves are read by the regeneration
/// fence, which no `@Test` can be. The two word lists no compiler compares — this
/// project's enum and the export's copy in `backend/src/Motorsport/Circuit.flix` — are
/// laid together by `test/check-sources.mjs`.
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

    /// Figures as a map record gives them: a lap and, where it places both intermediate
    /// lines, three stretches.
    def figures(): Circuit.Figures = {
        lap = 5513.0,
        published = Some({source = "the 2026 circuit map", stretches = 1311.0 :: 2257.0 :: 1945.0 :: Nil})
    }

    def unplaced(): Circuit.Figures = {lap = 5513.0, published = None}

    /// A circuit whose organiser re-issues its map every season, which no config here is.
    def reissued(reason: String): Circuit.Circuit = {
        relation = Some(1i64),
        box = None,
        pit = None,
        word = "reissued",
        timedFrom = "start-finish",
        timingLine = None,
        eachSeason = Some(reason),
        file = "nowhere.geojson",
        survey = "A circuit"
    }

    /// The derivation carries the map's figures whole: the lap the survey is stretched to
    /// and the stretches, in order. These are the numbers the drawing was laid from and
    /// the report places its shares against, so equality here is the derivation keeping
    /// what it was handed.
    @Test
    def testTheDerivedMapCarriesTheMapsFigures(): Unit \ Assert =
        match Circuit.byWord("cota") {
            case None => Assert.assertTrueWithMsg(false, "no COTA is authored")
            case Some(cota) =>
                match Circuit.timingMapOf(cota, figures()) {
                    case TimingMap.Published(map) =>
                        Assert.assertTrueWithMsg(map#lapLength == 5513.0, "the derivation lost the lap the map gives");
                        Assert.assertTrueWithMsg(
                            map#stretches == 1311.0 :: 2257.0 :: 1945.0 :: Nil,
                            "the derivation lost a stretch, or reordered them"
                        )
                    case _ => Assert.assertTrueWithMsg(false, "the derivation answers a map that publishes stretches with something other than them")
                }
        }

    /// A re-issued map is refused with the config's own reason: the report
    /// quotes it, which is what makes the refusal readable as the circuit's
    /// claim rather than the report's invention.
    @Test
    def testTheDerivedMapRefusesAReissuedMapWithTheAuthoredReason(): Unit \ Assert =
        let reason = "the map is re-issued every season";
        match Circuit.timingMapOf(reissued(reason), figures()) {
            case TimingMap.PerSeason(quoted) =>
                Assert.assertTrueWithMsg(
                    quoted == reason,
                    "the derivation quotes a different refusal from the one the config states"
                )
            case _ =>
                Assert.assertTrueWithMsg(false, "the derivation answers a re-issued map with something other than a refusal")
        }

    @Test
    def testAMapPlacingNoIntermediateLinesPublishesNothing(): Unit \ Assert =
        match Circuit.byWord("cota") {
            case None       => Assert.assertTrueWithMsg(false, "no COTA is authored")
            case Some(cota) => Assert.assertTrue(kindOfMap(Circuit.timingMapOf(cota, unplaced())) == "unsurveyed")
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

    /// A circuit's answer, said as a kind. The derivation spells the config's
    /// three sector answers as its own three.
    def kindOfMap(map: TimingMap): String =
        match map {
            case TimingMap.Published(_) => "published"
            case TimingMap.PerSeason(_) => "perSeason"
            case TimingMap.Unsurveyed   => "unsurveyed"
        }

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
