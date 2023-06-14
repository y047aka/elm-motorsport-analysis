module Motorsport.Summary exposing
    ( Summary, init
    , calcLapTotal
    )

{-|

@docs Summary, init
@docs calcLapTotal

-}

import Motorsport.Lap exposing (Lap)


type alias Summary =
    { lapTotal : Int }


init : Summary
init =
    { lapTotal = 0 }


calcLapTotal : List (List Lap) -> Int
calcLapTotal =
    List.map List.length
        >> List.maximum
        >> Maybe.withDefault 0
