/// The three questions asked of OpenStreetMap, held to what each reader can work with:
/// the survey's relation with its ways' node refs and their nodes, the probe's box of
/// candidate relations tags only, and the candidate's ways with their geometry.
///
/// Both questions that walk a relation recurse through `way(r)` — the difference between
/// drawing a lap and lengthening one is that only the survey asks the nodes themselves.
/// What the answers come back as is `Overpass.TestAnswer`'s.
pub mod Overpass.TestQuery {

    use Overpass.Query.{candidates, survey, ways}

    @Test
    def testTheSurveyNamesTheRelationAndTheBodySpelling(): Unit \ Assert =
        let asked = survey(6537729i64);
        Assert.assertTrue(String.startsWith({prefix = "[out:json][timeout:120];"}, asked));
        // `out body` for the ways, so a way carries its node refs, and `out skel` for
        // the nodes, which is all a chain needs of them.
        Assert.assertTrue(String.contains({substr = "way(r);out body;"}, asked));
        Assert.assertTrue(String.contains({substr = "node(w);out skel;"}, asked));
        Assert.assertTrue(String.contains({substr = "relation(6537729);"}, asked))

    /// The probe's second question recurses to the relation's ways the way the
    /// survey's does — `way(r)` is what brings the ways a role's length is
    /// measured out of, and a question that stops short of it names a circuit
    /// nobody can measure — and stops at the geometry the runner hands inline:
    /// nodes are a survey's question, the one that chains a lap.
    @Test
    def testTheProbeAsksTheWaysAndNotTheirNodes(): Unit \ Assert =
        let asked = ways(6537729i64);
        Assert.assertTrue(String.contains({substr = "relation(6537729);out body;"}, asked));
        Assert.assertTrue(String.contains({substr = "way(r);out geom;"}, asked));
        Assert.assertTrue(String.contains({substr = "node(w)"}, asked) == false)

    /// The probe's first question asks for tags and nothing else, and catches every way
    /// a relation's tags could name: a circuit relation, a motor-sport route, a raceway.
    /// Which of them is the circuit is the next question's answer.
    @Test
    def testTheCandidatesAskTagsAloneOverTheWholeBox(): Unit \ Assert =
        let asked = candidates("47.9,0.1,48.0,0.3");
        Assert.assertTrue(String.startsWith({prefix = "[out:json][timeout:90];("}, asked));
        Assert.assertTrue(String.endsWith({suffix = "out tags;"}, asked));
        // Every selector is asked of the same box, in the one union: a circuit relation,
        // a motor-sport route, a raceway, and the two tags a road carries without either.
        let box = "(47.9,0.1,48.0,0.3);";
        Assert.assertTrue(String.contains({substr = "relation[\"type\"=\"circuit\"]${box}"}, asked));
        Assert.assertTrue(String.contains({substr = "relation[\"sport\"~\"^motor\"]${box}"}, asked));
        Assert.assertTrue(String.contains({substr = "relation[\"motorsport\"]${box}"}, asked));
        Assert.assertTrue(String.contains({substr = "relation[\"route\"~\"^(raceway|motorsport|racing)$\"]${box}"}, asked));
        Assert.assertTrue(String.contains({substr = "relation[\"highway\"=\"raceway\"]${box}"}, asked));
        // Tags only: no selector recurses, because a candidate is picked before its line
        // is measured at all — neither the survey's body nor the measurement's geometry.
        Assert.assertTrue(String.contains({substr = "out body"}, asked) == false);
        Assert.assertTrue(String.contains({substr = "out geom"}, asked) == false)
}
