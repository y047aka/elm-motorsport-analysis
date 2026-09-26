/// A flag the whole field is shown, as the line first reads it -- the mirror of
/// `Motorsport.Flag` on the Elm side, which reads back the names written here.
mod Motorsport.Flag {

    use Motorsport.Wec
    use Util.Duration.Duration

    /// `GreenFlag` is racing resumed after any of the others.
    pub enum Flag with Eq {
        case FullCourseYellow
        case SafetyCar
        case RedFlag
        case GreenFlag
    }

    /// A flag the line read for the first time since a different one.
    pub type alias FlagShown = {
        flag    = Flag,
        elapsed = Duration
    }

    pub def all(): List[Flag] =
        Flag.FullCourseYellow :: Flag.SafetyCar :: Flag.RedFlag :: Flag.GreenFlag :: Nil

    /// The name a timeline file and a summary give a flag.
    pub def toString(flag: Flag): String =
        match flag {
            case Flag.FullCourseYellow => "fullCourseYellow"
            case Flag.SafetyCar        => "safetyCar"
            case Flag.RedFlag          => "redFlag"
            case Flag.GreenFlag        => "greenFlag"
        }

    pub def fromString(name: String): Option[Flag] =
        List.find(flag -> toString(flag) == name, all())

    /// The flag the field is shown at a crossing the feed flagged. `SlowZone` is a
    /// safety car: every car crosses under it, at a crawl, which no local slow zone
    /// would do. The finish is no flag of the field's: each car's is its own
    /// `Finished`.
    pub def fromFeed(flag: Wec.Flag): Option[Flag] =
        match flag {
            case Wec.Flag.Green            => Some(Flag.GreenFlag)
            case Wec.Flag.SlowZone         => Some(Flag.SafetyCar)
            case Wec.Flag.FullCourseYellow => Some(Flag.FullCourseYellow)
            case Wec.Flag.Red              => Some(Flag.RedFlag)
            case Wec.Flag.Finish           => None
        }

}
