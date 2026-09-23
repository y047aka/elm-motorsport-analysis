module Motorsport.Analysis.ClassPositions exposing
    ( Point
    , byCar
    )

{-| The places each car of a class held, lap by lap.

The population is the class and not the cars being compared: a position only
means anything against everyone it could have been gained from or lost to.

@docs Point
@docs byCar

-}

import Motorsport.LapRange as LapRange exposing (LapRange)
import Motorsport.Position exposing (Position)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Wec.Class exposing (Class)


type alias Point =
    { lap : Int
    , position : Position
    }


{-| A lap the feed gave no position for produces no point, and a car that was
not running in the range answers with nothing rather than dropping out.
-}
byCar : LapRange -> Class -> Snapshot -> List ( CarAt, List Point )
byCar range class snapshot =
    let
        lapHistory =
            Snapshot.lapHistory snapshot

        pointsOf car =
            LapHistory.get car.metadata.carNumber lapHistory
                |> LapRange.within range
                |> List.filterMap
                    (\lap -> lap.position |> Maybe.map (\position -> { lap = lap.lap, position = position }))
    in
    Snapshot.inClass class snapshot
        |> List.map (\car -> ( car, pointsOf car ))
