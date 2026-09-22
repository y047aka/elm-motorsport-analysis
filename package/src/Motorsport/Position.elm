module Motorsport.Position exposing
    ( Position
    , toOrdinal
    )

{-| Where a car stands in a classification, and how that is said.

@docs Position
@docs toOrdinal

-}


{-| A place in a classification, counted from 1. The field's or a class's,
depending on which the caller asked the standing for -- the number does not
carry which, and at Le Mans an LMGT3 car is 3rd and 41st at the same moment.
-}
type alias Position =
    Int


{-| An English ordinal, suffix and all.

    toOrdinal 1
    --> "1st"

    toOrdinal 2
    --> "2nd"

    toOrdinal 3
    --> "3rd"

    toOrdinal 4
    --> "4th"

The teens take `th` whatever digit they end in, which is the whole of what the
last digit alone gets wrong:

    toOrdinal 11
    --> "11th"

    toOrdinal 12
    --> "12th"

    toOrdinal 13
    --> "13th"

    toOrdinal 21
    --> "21st"

A grid of 62 never reaches them, but every hundred repeats the pattern:

    toOrdinal 101
    --> "101st"

    toOrdinal 111
    --> "111th"

-}
toOrdinal : Position -> String
toOrdinal position =
    String.fromInt position ++ suffix position


suffix : Position -> String
suffix position =
    if modBy 100 position // 10 == 1 then
        "th"

    else
        case modBy 10 position of
            1 ->
                "st"

            2 ->
                "nd"

            3 ->
                "rd"

            _ ->
                "th"
