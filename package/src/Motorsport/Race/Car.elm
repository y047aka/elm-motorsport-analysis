module Motorsport.Race.Car exposing
    ( Car, Metadata, CarNumber
    , fromStartingGrid
    )

{-| A car as the entry list knows it.

Who the car is, where it started, and every lap it turned. None of it moves as
the clock does. What the car is _doing_ at a moment of the race is worked out
from one of these and an elapsed time, in
[`Race.Snapshot`](Motorsport-Race-Snapshot).

@docs Car, Metadata, CarNumber
@docs fromStartingGrid

-}

import Motorsport.Driver exposing (Driver)
import Motorsport.Lap exposing (Lap)
import Motorsport.Wec.Class exposing (Class)
import Motorsport.Wec.Manufacturer exposing (Manufacturer)


type alias Car =
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


{-| A car that has yet to turn a lap, from its place on the grid.

The grid is estimated from the race itself, so how much the place is worth is
the file's `basis` to say, not this type's.

-}
fromStartingGrid : { position : Int, car : Metadata } -> Car
fromStartingGrid item =
    { metadata = item.car
    , startPosition = item.position
    , laps = []
    }
