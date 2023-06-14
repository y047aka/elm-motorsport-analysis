module Motorsport.Summary exposing
    ( Summary, init
    , calcLapTotal
    )

{-|

@docs Summary, init
@docs calcLapTotal

-}

import Motorsport.Car exposing (Car)


type alias Summary =
    { lapTotal : Int }


init : Summary
init =
    { lapTotal = 0 }


calcLapTotal : List Car -> Int
calcLapTotal =
    List.map (.laps >> List.length)
        >> List.maximum
        >> Maybe.withDefault 0
