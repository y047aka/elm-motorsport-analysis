module Motorsport.Race.Entrant exposing
    ( Entrant, Metadata, CarNumber
    , fromStartingGrid
    )

{-| A car as the entry list knows it.

Who the car is, where it started, and every lap it turned. None of it moves as
the clock does. What the car is _doing_ at a moment of the race is worked out
from an entrant and an elapsed time, in
[`ViewModel.Standings`](Motorsport-ViewModel-Standings).

@docs Entrant, Metadata, CarNumber
@docs fromStartingGrid

-}

import Motorsport.Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Lap exposing (Lap)
import Motorsport.Manufacturer exposing (Manufacturer)


type alias Entrant =
    { metadata : Metadata
    , startPosition : Int
    , laps : List Lap
    }


type alias Metadata =
    { carNumber : CarNumber
    , drivers : List Driver
    , class : Class
    , group : String
    , team : String
    , manufacturer : Manufacturer
    }


type alias CarNumber =
    String


{-| An entrant that has yet to turn a lap, from its place on the grid.
-}
fromStartingGrid : { position : Int, car : Metadata } -> Entrant
fromStartingGrid item =
    { metadata = item.car
    , startPosition = item.position
    , laps = []
    }
