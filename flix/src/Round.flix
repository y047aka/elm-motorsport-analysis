mod Round {

    use Motorsport.Calendar.Entry

    /// A round is loaded when both tables hold it. Asked of the laps alone, a
    /// round only half in the database reads as a race whose grid was empty
    /// rather than as one that never ran.
    pub def loaded(entry: Entry): Result[String, Bool] \ DbRead =
        forM(
            hasLaps <- Round.Laps.loaded(entry);
            hasCars <- if (hasLaps) Round.Cars.loaded(entry) else Ok(false)
        ) yield hasCars

}
