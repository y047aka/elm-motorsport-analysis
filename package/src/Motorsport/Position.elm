module Motorsport.Position exposing
    ( Position
    , toOrdinal
    , Movement(..), movement, toArrow
    )

{-| Where a car stands in a classification, and how that is said.

@docs Position
@docs toOrdinal
@docs Movement, movement, toArrow

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


{-| Places made up or dropped since the start. Never by nought: a car that holds
its place has no movement.
-}
type Movement
    = Gained Int
    | Lost Int


{-| How far a car has come from where it started. Nothing where it holds that
place, or where the place it started from is not known.

    movement { startPosition = Just 5, position = 3 }
    --> Just (Gained 2)

    movement { startPosition = Just 3, position = 5 }
    --> Just (Lost 2)

    movement { startPosition = Just 4, position = 4 }
    --> Nothing

    movement { startPosition = Nothing, position = 4 }
    --> Nothing

-}
movement : { startPosition : Maybe Position, position : Position } -> Maybe Movement
movement { startPosition, position } =
    startPosition
        |> Maybe.andThen
            (\start ->
                if start > position then
                    Just (Gained (start - position))

                else if start < position then
                    Just (Lost (position - start))

                else
                    Nothing
            )


{-| A movement as a timing screen prints it, in two parts so that the arrow can
be drawn apart from the number.

    toArrow (Gained 2)
    --> { arrow = "↑", places = "2" }

    toArrow (Lost 3)
    --> { arrow = "↓", places = "3" }

-}
toArrow : Movement -> { arrow : String, places : String }
toArrow m =
    case m of
        Gained places ->
            { arrow = "↑", places = String.fromInt places }

        Lost places ->
            { arrow = "↓", places = String.fromInt places }
