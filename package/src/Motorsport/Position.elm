module Motorsport.Position exposing (toOrdinal)

{-| Where a car stands, written the way it is said.

@docs toOrdinal

-}


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
toOrdinal : Int -> String
toOrdinal position =
    String.fromInt position ++ suffix position


suffix : Int -> String
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
