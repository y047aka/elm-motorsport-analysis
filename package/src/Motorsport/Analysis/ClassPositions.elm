module Motorsport.Analysis.ClassPositions exposing
    ( Point
    , held
    )

{-| The places each car of a class held, lap by lap.

The population is the class and not the cars being compared: a position only
means anything against everyone it could have been gained from or lost to.

A reading under `Motorsport/Analysis/`: derived from a snapshot and the
primitives, holding nothing of its own.

@docs Point
@docs held

-}

import Motorsport.Analysis.LapWindow as LapWindow exposing (Laps)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Wec.Class exposing (Class)


type alias Point =
    { lap : Int
    , position : Int
    }


{-| Every car of the class, each with the places it held inside the window. A
lap the feed gave no position for is not one of them, and a car that was not
running in the window answers with nothing.
-}
held : Laps -> Class -> Snapshot -> List ( CarAt, List Point )
held window class snapshot =
    let
        lapHistory =
            Snapshot.lapHistory snapshot

        pointsOf car =
            LapHistory.get car.metadata.carNumber lapHistory
                |> LapWindow.within window
                |> List.filterMap
                    (\lap -> lap.position |> Maybe.map (\position -> { lap = lap.lap, position = position }))
    in
    Snapshot.inClass class snapshot
        |> List.map (\car -> ( car, pointsOf car ))
