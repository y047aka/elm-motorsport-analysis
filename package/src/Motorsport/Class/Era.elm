module Motorsport.Class.Era exposing
    ( Era(..)
    , fromSeason
    )

{-|

@docs Era
@docs fromSeason

-}


{-| A stretch of seasons over which the grid keeps the same shape.

Seasons arrive every year; the grid does not change with them. Keying on the
season number would mean revisiting it each January, so `Motorsport.Class` keys
the classes, their order and their colors on the era instead.

An era ends when a category is added, dropped, or moves in the order:

  - `GteProAndAm` -- 2021 to 2022. Hypercar took the top place over from LMP1,
    with LMGTE Pro third and LMGTE Am fourth.
  - `GteAmAsFourthClass` -- 2023. LMGTE Pro was dropped and third stood empty;
    LMGTE Am kept fourth rather than moving up.
  - `Gt3AsFourthClass` -- 2024. LMGT3 replaced LMGTE Am and inherited its
    place, fourth.
  - `Gt3AsThirdClass` -- 2025 onwards. With no GTE field left, LMGT3 moved up
    to third.

Only eras the app has data for are named: inventing one for a season nobody can
load would mean guessing at its grid. The LMP1 era, before 2021, is not one.

-}
type Era
    = GteProAndAm
    | GteAmAsFourthClass
    | Gt3AsFourthClass
    | Gt3AsThirdClass


{-| The era a season belongs to, if the app knows that season's grid.

    fromSeason 2020
    --> Nothing

The most recent era has no end, so seasons the calendar has not reached resolve
too -- 2027 will cost nothing here:

    Maybe.map2 (==) (fromSeason 2025) (fromSeason 2030)
    --> Just True

-}
fromSeason : Int -> Maybe Era
fromSeason season =
    if season >= 2025 then
        Just Gt3AsThirdClass

    else if season == 2024 then
        Just Gt3AsFourthClass

    else if season == 2023 then
        Just GteAmAsFourthClass

    else if season >= 2021 then
        Just GteProAndAm

    else
        Nothing
