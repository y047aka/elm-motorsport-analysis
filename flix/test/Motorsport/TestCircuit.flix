/// The published timing maps the report reads, frozen at the figures the circuits
/// publish. `app/tests/circuit-timing-map.spec.ts` ties these to the numbers
/// `circuits/src/Circuit.flix` authors the drawing from; what is pinned here is
/// what the report would otherwise only find out while printing: that a circuit's
/// stretches add up to the lap it publishes, and that a circuit re-mapped every
/// season says so rather than standing silent.
pub mod Motorsport.TestCircuit {

    use Motorsport.Circuit.Circuit
    use Motorsport.Circuit.TimingMap

    def mapOf(circuit: Circuit): TimingMap = Motorsport.Circuit.timingMap(circuit)

    /// COTA's three stretches are the distances the circuit's own sector map gives,
    /// and they add up to the lap it publishes -- the one thing the stretches are
    /// ever compared against, since the shares place a line some 170 m from these by
    /// the method's own error.
    @Test
    def testPublishedStretchesAddUpToThePublishedLap(): Unit \ Assert =
        match mapOf(Circuit.Cota) {
            case TimingMap.Published(published) =>
                let added = List.foldLeft((acc, x) -> acc + x, 0.0, published#stretches);
                Assert.assertTrue(List.length(published#stretches) == 3);
                // The tenth of a metre the geometry is written at, which is the
                // distance the pipeline that lays the drawing reproduces.
                Assert.assertTrue(Float64.abs(added - published#lapLength) <= 0.15)
            case _ => Assert.assertTrue(false)
        }

    /// Le Mans re-issues its map every season, which is a reason and not a hole: its
    /// figures are not redistributed, so no set of lines answers for two seasons and
    /// the report refuses to lay one season against another there.
    @Test
    def testLeMansIsReissuedEverySeason(): Unit \ Assert =
        match mapOf(Circuit.LeMans) {
            case TimingMap.PerSeason(reason) =>
                Assert.assertTrue(String.contains({substr = "re-issued"}, reason))
            case _ => Assert.assertTrue(false)
        }

    /// A circuit no geometry is surveyed for publishes no lines, and says which.
    @Test
    def testCircuitsNothingIsSurveyedForSaySo(): Unit \ Assert =
        let unsurveyed = circuit -> match Motorsport.Circuit.timingMap(circuit) {
            case TimingMap.Unsurveyed => true
            case _                    => false
        };
        Assert.assertTrue(unsurveyed(Circuit.Qatar));
        Assert.assertTrue(unsurveyed(Circuit.Fuji));
        Assert.assertTrue(unsurveyed(Circuit.SaoPaulo));
        Assert.assertTrue(unsurveyed(Circuit.Bahrain))

    /// Every circuit `Motorsport.Events` can name a round's circuit for is answered
    /// for: a report handed a round of a circuit added to that list without adding a
    /// timing map gets the one message that says what is missing.
    @Test
    def testEveryCircuitIsAnsweredFor(): Unit \ Assert =
        let named = List#{
            Circuit.Qatar,
            Circuit.Imola,
            Circuit.Spa,
            Circuit.LeMans,
            Circuit.Cota,
            Circuit.Fuji,
            Circuit.Bahrain,
            Circuit.SaoPaulo
        };
        let mapped = circuit -> match Motorsport.Circuit.timingMap(circuit) {
            case TimingMap.Published(published) => List.length(published#stretches) == 3
            case TimingMap.PerSeason(reason)    => String.length(reason) > 0
            case TimingMap.Unsurveyed           => true
        };
        Assert.assertTrue(List.foldLeft((acc, circuit) -> acc and mapped(circuit), true, named))

}
