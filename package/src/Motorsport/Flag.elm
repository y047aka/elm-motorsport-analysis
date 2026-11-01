module Motorsport.Flag exposing (Flag(..), fromString, toString)

{-| A flag the whole field is shown, as the line first reads it.

`Lap.Flag` is the other reading of the same column in the feed: it keeps every
code the feed spells, where this one reads `SF` as `SafetyCar` and has no state at
all for the chequered flag, which is no flag on the field.

@docs Flag, fromString, toString

-}


{-| `SafetyCar` is the feed's `SF`; `GreenFlag` is racing resumed after any of
the others.
-}
type Flag
    = FullCourseYellow
    | SafetyCar
    | RedFlag
    | GreenFlag


{-| The flag a timeline file names, spelled as the Flix `Motorsport.Flag` writes it.

    fromString "safetyCar"
    --> Just SafetyCar

    fromString "SF"
    --> Nothing

-}
fromString : String -> Maybe Flag
fromString name =
    case name of
        "fullCourseYellow" ->
            Just FullCourseYellow

        "safetyCar" ->
            Just SafetyCar

        "redFlag" ->
            Just RedFlag

        "greenFlag" ->
            Just GreenFlag

        _ ->
            Nothing


{-| The name race control gives a flag. For display only.

    toString FullCourseYellow
    --> "Full Course Yellow"

-}
toString : Flag -> String
toString flag =
    case flag of
        FullCourseYellow ->
            "Full Course Yellow"

        SafetyCar ->
            "Safety Car"

        RedFlag ->
            "Red Flag"

        GreenFlag ->
            "Green Flag"
