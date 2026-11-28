/// The calendar a test that needs one is handed: a slice of
/// `data/wec/calendar.json`, written out rather than read, so a change to the
/// file cannot quietly rewrite what a test asserts.
///
/// Monza is left out of every season: several tests need a round the calendar
/// does not list.
pub mod Motorsport.TestCalendarSupport {

    use Motorsport.Calendar.Calendar
    use Motorsport.Calendar.Round
    use Motorsport.Calendar.Season
    use Motorsport.Circuit.Circuit

    pub def calendar(): Calendar = {
        series  = "wec",
        seasons = season2026() :: season2025() :: season2024() :: Nil
    }

    def at(id: String, date: String, name: String, circuit: Circuit): Round =
        { id = id, date = date, name = name, circuit = Some(circuit) }

    def season2026(): Season = {
        season = 2026,
        rounds =
            at("imola_6h", "2026-04-19", "6 Hours of Imola", Circuit.Imola) ::
            at("spa_6h", "2026-05-09", "6 Hours of Spa", Circuit.Spa) ::
            at("le_mans_24h", "2026-06-13", "24 Hours of Le Mans", Circuit.LeMans) ::
            at("cota_6h", "2026-09-06", "Lone Star Le Mans", Circuit.Cota) ::
            Nil
    }

    def season2025(): Season = {
        season = 2025,
        rounds =
            at("qatar_1812km", "2025-03-01", "Qatar 1812km", Circuit.Qatar) ::
            at("imola_6h", "2025-04-20", "6 Hours of Imola", Circuit.Imola) ::
            at("spa_6h", "2025-05-10", "6 Hours of Spa", Circuit.Spa) ::
            at("le_mans_24h", "2025-06-14", "24 Hours of Le Mans", Circuit.LeMans) ::
            at("cota_6h", "2025-09-07", "Lone Star Le Mans", Circuit.Cota) ::
            at("fuji_6h", "2025-09-28", "6 Hours of Fuji", Circuit.Fuji) ::
            Nil
    }

    def season2024(): Season = {
        season = 2024,
        rounds =
            at("le_mans_24h", "2024-06-15", "24 Hours of Le Mans", Circuit.LeMans) ::
            at("fuji_6h", "2024-09-15", "6 Hours of Fuji", Circuit.Fuji) ::
            at("bahrain_8h", "2024-11-02", "8 Hours of Bahrain", Circuit.Bahrain) ::
            Nil
    }

}
