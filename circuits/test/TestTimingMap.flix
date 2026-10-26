/// The two copies of a circuit's timing figures, laid together where both are
/// compiled. This project's `Circuit.flix` authors the figures the drawing is
/// laid from; the linked `Motorsport.Circuit` holds them again for the report,
/// which reads no geometry file. One project compiles both and no compiler
/// compares what they state: a stretch moved on one side alone leaves a report
/// measuring one lap while the drawing shows another. The bytes the figures
/// were written into are the byte fence's to judge; these are the copies' own
/// reading, handed no fixture because they read the real authors.
pub mod TestTimingMap {

    use Circuit.Circuit
    use Motorsport.Circuit.TimingMap

    /// Every case the summaries can be sent for, whether or not this project
    /// surveys it. A new case of the enum has to join this list, and then be
    /// answered `Unsurveyed` until a config authors it.
    def cases(): List[Motorsport.Circuit.Circuit] =
        Motorsport.Circuit.Circuit.Qatar ::
        Motorsport.Circuit.Circuit.Imola ::
        Motorsport.Circuit.Circuit.Spa ::
        Motorsport.Circuit.Circuit.LeMans ::
        Motorsport.Circuit.Circuit.Cota ::
        Motorsport.Circuit.Circuit.Fuji ::
        Motorsport.Circuit.Circuit.Bahrain ::
        Motorsport.Circuit.Circuit.SaoPaulo ::
        Nil

    /// The report's answer for the case whose word a config's word is, if any
    /// case answers to that word at all.
    def mapOf(word: String): Option[TimingMap] =
        Option.flatMap(
            circuit -> Some(Motorsport.Circuit.timingMap(circuit)),
            List.find(circuit -> Motorsport.Circuit.jsonValue(circuit) == word, cases())
        )

    /// The stretches a config publishes, and the ones a report publishes, in one
    /// comparable shape: nothing for either side's kinds that publish none.
    def authoredStretches(circuit: Circuit): Option[List[Float64]] =
        Option.map(publishes -> publishes#stretches, circuit#sectors#published)

    /// Which kind of answer a config's sectors claim for their circuit: one map
    /// published for every season, a map the organiser re-issues, or nothing
    /// surveyed. The report spells the same three answers, and a circuit whose
    /// two answers are different kinds is a report measuring a lap no drawing
    /// shows.
    def kindOf(circuit: Circuit): String =
        if (not Option.isEmpty(circuit#sectors#published))
            "published"
        else if (not Option.isEmpty(circuit#sectors#eachSeason))
            "perSeason"
        else
            "unsurveyed"

    def kindOfMap(map: TimingMap): String =
        match map {
            case TimingMap.Published(_) => "published"
            case TimingMap.PerSeason(_) => "perSeason"
            case TimingMap.Unsurveyed   => "unsurveyed"
        }

    /// The report's figures for a circuit are the config's figures: the same lap,
    /// the same stretches in the same order, and the word the config names its
    /// directory by — which is the word its kept answer and its served file are
    /// named by too.
    @Test
    def testTheReportLaysCotaOnTheAuthoredLap(): Unit \ Assert =
        match (Circuit.byWord("cota"), mapOf("cota")) {
            case (Some(cota), Some(TimingMap.Published(map))) =>
                Assert.assertTrueWithMsg(
                    map#lapLength == cota#lap,
                    "the report and the drawing are given different laps"
                );
                Assert.assertTrueWithMsg(
                    Some(map#stretches) == authoredStretches(cota),
                    "the report and the drawing divide the lap differently"
                );
                Assert.assertTrue(Motorsport.Circuit.jsonValue(Motorsport.Circuit.Circuit.Cota) == cota#word)
            case (Some(_), Some(_)) =>
                Assert.assertTrueWithMsg(
                    false,
                    "Circuit.timingMap holds no published map for a circuit whose config publishes one"
                )
            case _ =>
                Assert.assertTrueWithMsg(false, "no COTA is authored, or no case answers the word it authors")
        }

    /// A re-issued map is refused in both copies, and in one reason: the report
    /// quotes the config's own words, which is what makes the refusal readable
    /// as the circuit's claim rather than the report's invention.
    @Test
    def testTheReportRefusesLeMansWithTheAuthoredReason(): Unit \ Assert =
        match (Circuit.byWord("le_mans"), mapOf("le_mans")) {
            case (Some(leMans), Some(TimingMap.PerSeason(reason))) =>
                match leMans#sectors#eachSeason {
                    case Some(authored) =>
                        Assert.assertTrueWithMsg(
                            reason == authored,
                            "the report quotes a different refusal from the one the config states"
                        );
                        Assert.assertTrueWithMsg(
                            Option.isEmpty(authoredStretches(leMans)),
                            "a circuit whose map is re-issued every season publishes no stretches to quote"
                        )
                    case None =>
                        Assert.assertTrueWithMsg(false, "Le Mans's config names no reason for re-issuing")
                }
            case (Some(_), Some(_)) =>
                Assert.assertTrueWithMsg(
                    false,
                    "Circuit.timingMap answers Le Mans with something other than a refusal"
                )
            case _ =>
                Assert.assertTrueWithMsg(false, "no Le Mans is authored, or no case answers the word it authors")
        }

    /// The words a config authors and the cases a report answers for are two
    /// lists, and the ones between them are circuits nothing is surveyed for —
    /// which the report has to say, rather than stand for a map that was never
    /// authored.
    @Test
    def testEveryConfiguredCircuitIsAnsweredTheKindItsConfigClaims(): Unit \ Assert =
        let disagreements = List.filter(circuit -> not kindsAgree(circuit), Circuit.circuits());
        Assert.assertTrueWithMsg(
            List.isEmpty(disagreements),
            "a circuit's config and the report's answer for it are not the same kind of answer"
        )

    @Test
    def testEveryCircuitWithoutAConfigPublishesNothing(): Unit \ Assert =
        let authoredWords = List.map(circuit -> circuit#word, Circuit.circuits());
        let answered = List.filter(
            circuit -> List.memberOf(Motorsport.Circuit.jsonValue(circuit), authoredWords),
            cases()
        );
        Assert.assertTrueWithMsg(
            List.length(answered) == List.length(authoredWords),
            "a word is authored in the config that no case of the report answers to"
        );
        let unsurveyed = List.filter(
            circuit -> not List.memberOf(Motorsport.Circuit.jsonValue(circuit), authoredWords),
            cases()
        );
        let wrong = List.filter(
            circuit -> kindOfMap(Motorsport.Circuit.timingMap(circuit)) != "unsurveyed",
            unsurveyed
        );
        Assert.assertTrueWithMsg(
            List.isEmpty(wrong),
            "a circuit with no config here is answered with a map no config authored"
        )

    /// A circuit's two answers, said as kinds. Configs and reports disagree by
    /// kind before they disagree by figures, and no caller reads which one a
    /// round was drawn from.
    def kindsAgree(circuit: Circuit): Bool =
        match mapOf(circuit#word) {
            case None        => false
            case Some(map)   => kindOfMap(map) == kindOf(circuit)
        }

    /// `timingMap` is total by its own match, so a new case fails to compile
    /// there; what nothing catches is a new case missing from *this* file's
    /// list, which would leave the checks above reading a smaller enum than
    /// `Motorsport.Circuit` holds.
    @Test
    def testEveryCaseOfTheEnumIsListedHere(): Unit \ Assert =
        Assert.assertTrueWithMsg(
            List.length(cases()) == 8,
            "cases() no longer names every case Motorsport.Circuit.Circuit has"
        )

}
