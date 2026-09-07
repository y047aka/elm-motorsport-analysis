/// Names numbered from one, which is how the three tables keyed by a name --
/// `drivers`, `teams`, `manufacturers` -- get their ids.
///
/// A run walks the rounds one at a time and a name turns up in several, so the
/// numbering is carried between them rather than read back between them. An id
/// means nothing outside the database a run put it in.
mod Db.Numbering {

    pub type alias Numbering = Map[String, Int32]

    pub def none(): Numbering = Map.empty()

    /// The names not already numbered, numbered after the ones that are, in
    /// the order given and once each.
    pub def add(numbering: Numbering, names: List[String]): (Numbering, List[(Int32, String)]) =
        List.foldLeft((acc, name) -> {
            let (known, added) = acc;
            if (Map.memberOf(name, known))
                acc
            else
                let id = Map.size(known) + 1;
                (Map.insert(name, id, known), (id, name) :: added)
        }, (numbering, Nil), names)
            |> match (known, added) -> (known, List.reverse(added))

    pub def idIn(numbering: Numbering, name: String): Option[Int32] =
        Map.get(name, numbering)

}
