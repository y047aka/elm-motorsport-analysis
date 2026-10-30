/// The report's timing map, read as the derivation it is. `circuits/src/Circuit.flix`
/// authors a circuit's timing figures once, for the drawing, and derives the
/// report's answer from them with its own `timingMap`; the report's
/// `Motorsport.Circuit` holds only the shapes of that answer — so what is
/// tested here is the derivation itself: that a config's published stretches
/// reach the report unchanged, that a re-issued map is refused with the
/// config's own words, and that the enum and the config answer to one
/// another's names. The two word lists no compiler compares — this project's
/// enum and the export's copy in `flix/src/Motorsport/Circuit.flix` — are laid
/// together by `test/check-sources.mjs`, the reading no `@Test` can make from
/// inside one project.
pub mod TestTimingMap {

    use Motorsport.Circuit.TimingMap

    /// Every case the summaries can be sent for, whether or not this project
    /// surveys it. A new case of the enum has to join this list, and then be
    /// answered `Unsurveyed` — which, the map being derived, it is until a
    /// config authors its word.
    def cases(): List[Motorsport.Circuit.Circuit] =
        Motorsport.Circuit.Circuit.Qatar ::
        Motorsport.Circuit.Circuit.Imola    ::
        Motorsport.Circuit.Circuit.Spa      ::
        Motorsport.Circuit.Circuit.LeMans   ::
        Motorsport.Circuit.Circuit.Cota     ::
        Motorsport.Circuit.Circuit.Fuji     ::
        Motorsport.Circuit.Circuit.Bahrain  ::
        Motorsport.Circuit.Circuit.SaoPaulo ::
        Motorsport.Circuit.Circuit.Barcelona ::
        Nil

    /// The report's answer for the case whose word a config's word is, if any
    /// case answers to that word at all.
    def mapOf(word: String): Option[TimingMap] =
        Option.map(
            _ -> Circuit.timingMap(word),
            List.find(circuit -> Motorsport.Circuit.jsonValue(circuit) == word, cases())
        )

    /// A circuit's answer, said as a kind. The derivation spells the config's
    /// three sector answers as its own three.
    def kindOfMap(map: TimingMap): String =
        match map {
            case TimingMap.Published(_) => "published"
            case TimingMap.PerSeason(_) => "perSeason"
            case TimingMap.Unsurveyed   => "unsurveyed"
        }

    /// The derivation carries COTA's authored figures whole: the lap the survey
    /// is stretched to and the stretches the circuit's own map gives, in order.
    /// These are the numbers the drawing was laid from and the report places its
    /// shares against — one reading authors both, so equality here is the
    /// derivation keeping what it was handed, not two authors agreeing.
    @Test
    def testTheDerivedMapCarriesCotasAuthoredFigures(): Unit \ Assert =
        match (Circuit.byWord("cota"), mapOf("cota")) {
            case (Some(cota), Some(TimingMap.Published(map))) =>
                Assert.assertTrueWithMsg(
                    map#lapLength == cota#lap,
                    "the derivation lost the lap the config stretches its survey to"
                );
                match cota#sectors#published {
                    case Some(publishes) =>
                        Assert.assertTrueWithMsg(
                            map#stretches == publishes#stretches,
                            "the derivation lost a stretch, or reordered them"
                        )
                    case None =>
                        Assert.assertTrueWithMsg(
                            false,
                            "COTA's config publishes no stretches for the derivation to carry"
                        )
                }
            case (Some(_), Some(_)) =>
                Assert.assertTrueWithMsg(
                    false,
                    "the derivation answers a circuit whose config publishes a map with something other than that map"
                )
            case _ =>
                Assert.assertTrueWithMsg(false, "no COTA is authored, or no case answers the word it authors")
        }

    /// A re-issued map is refused with the config's own reason: the report
    /// quotes it, which is what makes the refusal readable as the circuit's
    /// claim rather than the report's invention.
    @Test
    def testTheDerivedMapRefusesLeMansWithTheAuthoredReason(): Unit \ Assert =
        match (Circuit.byWord("le_mans"), mapOf("le_mans")) {
            case (Some(leMans), Some(TimingMap.PerSeason(reason))) =>
                match leMans#sectors#eachSeason {
                    case Some(authored) =>
                        Assert.assertTrueWithMsg(
                            reason == authored,
                            "the derivation quotes a different refusal from the one the config states"
                        )
                    case None =>
                        Assert.assertTrueWithMsg(false, "Le Mans's config names no reason for re-issuing")
                }
            case (Some(_), Some(_)) =>
                Assert.assertTrueWithMsg(
                    false,
                    "the derivation answers Le Mans with something other than a refusal"
                )
            case _ =>
                Assert.assertTrueWithMsg(false, "no Le Mans is authored, or no case answers the word it authors")
        }

    /// The words a config authors and the cases a report answers for name each
    /// other exactly: a word with no case behind it is a circuit the export can
    /// send a summary for that this project surveys in silence, and a case
    /// answering a word no config authors must publish nothing — the derivation
    /// has nothing to derive, and saying so is the whole of its duty there.
    @Test
    def testEveryAuthoredWordIsAnsweredAndEveryUnauthoredCasePublishesNothing(): Unit \ Assert =
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
            circuit -> kindOfMap(Circuit.timingMap(Motorsport.Circuit.jsonValue(circuit))) != "unsurveyed",
            unsurveyed
        );
        Assert.assertTrueWithMsg(
            List.isEmpty(wrong),
            "a circuit with no config here is derived into a map no config authored"
        )

    /// A config's answer and the derivation's are the same kind of answer for
    /// every circuit this project surveys — which the derivation gives by
    /// construction, and which fails the day an edit gives it a branch that
    /// reads one side of a config's sectors alone.
    @Test
    def testEveryConfiguredCircuitIsAnsweredTheKindItsConfigClaims(): Unit \ Assert =
        let disagreements = List.filter(circuit -> not kindsAgree(circuit), Circuit.circuits());
        Assert.assertTrueWithMsg(
            List.isEmpty(disagreements),
            "a circuit's config and the derivation's answer for it are not the same kind of answer"
        )

    def kindsAgree(circuit: Circuit.Circuit): Bool =
        match mapOf(circuit#word) {
            case None        => false
            case Some(map)   =>
                let claimed =
                    if (not Option.isEmpty(circuit#sectors#published))
                        "published"
                    else if (not Option.isEmpty(circuit#sectors#eachSeason))
                        "perSeason"
                    else
                        "unsurveyed";
                kindOfMap(map) == claimed
        }

    /// `timingMap` answers every word, its enum side by construction; what nothing
    /// else catches is a new case missing from *this* file's list, which would
    /// leave the checks above reading a smaller enum than the module holds — and
    /// the export's copy of the enum has no project left that compiles both.
    @Test
    def testEveryCaseOfTheEnumIsListedHere(): Unit \ Assert =
        Assert.assertTrueWithMsg(
            List.length(cases()) == 9,
            "cases() no longer names every case Motorsport.Circuit.Circuit has"
        )

}
