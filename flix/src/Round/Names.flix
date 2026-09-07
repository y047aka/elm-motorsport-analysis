/// The teams and manufacturers, read back by id.
///
/// Neither table is scoped by a round -- a team is a team in whichever round
/// names it -- and both are small enough to read whole: 72 teams and a
/// manufacturer's spellings against the 579 cars that name them.
mod Round.Names {

    use Db.Manufacturers
    use Db.Teams

    pub type alias Names = {
        teams = Map[Int32, String],
        manufacturers = Map[Int32, String]
    }

    pub def read(): Names \ DbRead =
        {
            teams = Teams.rows()
                |> Sql.map(c -> (c#teamId, c#name))
                |> Sql.selectAll
                |> List.toMap,
            manufacturers = Manufacturers.rows()
                |> Sql.map(c -> (c#manufacturerId, c#name))
                |> Sql.selectAll
                |> List.toMap
        }

    /// A car naming a team or a manufacturer no row answers to is a round
    /// loaded by halves, which is the one thing the car's row cannot say for
    /// itself.
    pub def nameOf(names: Map[Int32, String], what: String, id: Int32): String \ DbErr =
        match Map.get(id, names) {
            case Some(name) => name
            case None       => DbErr.fail(Db.Error.Incomplete(
                "a car names ${what} ${id}, which is not one of the round's ${what}s"))
        }

}
