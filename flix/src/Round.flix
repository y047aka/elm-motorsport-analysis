mod Round {

    use Motorsport.Calendar.Entry

    /// A round is loaded when both tables hold it. Asked of the laps alone, a
    /// round only half in the database reads as a race whose grid was empty
    /// rather than as one that never ran.
    pub def loaded(entry: Entry): Bool \ DbRead =
        Round.Laps.loaded(entry) and Round.Cars.loaded(entry)

}
