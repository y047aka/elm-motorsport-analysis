module Motorsport.Analysis.RelativeGap exposing
    ( Baseline, baseline, isEmpty
    , Point, against
    )

{-| Each car's cumulative time measured against a group's, lap by lap.

Subtracting the group magnifies what separates cars that are close together:
ahead of it is time in hand and behind it is time lost, so what a car's points
do from one lap to the next is the pace between them.

Which cars the baseline is taken from is the caller's, and need not be the cars
measured against it; they are separate arguments for that reason.

A reading under `Motorsport/Analysis/`: derived from a snapshot's laps and the
primitives, holding nothing of its own.

@docs Baseline, baseline, isEmpty
@docs Point, against

-}

import Dict exposing (Dict)
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)


{-| The moment the group crossed the line, per lap number.
-}
type Baseline
    = Baseline (Dict Int Instant)


type alias Point =
    { lap : Int
    , gap : Duration
    }


{-| The mean cumulative time per lap number, over the non-pit laps only --
including the pit laps would make the baseline jump.
-}
baseline : List Lap -> Baseline
baseline groupLaps =
    groupLaps
        |> List.filter Lap.isRacingLap
        |> List.foldl
            (\lap ->
                let
                    -- Summing moments is meaningless on its own; the mean of
                    -- them is the moment the group crossed the line.
                    elapsed =
                        Instant.toDuration lap.elapsed
                in
                Dict.update lap.lap
                    (\existing ->
                        case existing of
                            Just ( sum, count ) ->
                                Just ( sum + elapsed, count + 1 )

                            Nothing ->
                                Just ( elapsed, 1 )
                    )
            )
            Dict.empty
        |> Dict.map (\_ ( sum, count ) -> Instant.fromDuration (sum // count))
        |> Baseline


{-| Whether the group ran any lap the baseline could be taken off.
-}
isEmpty : Baseline -> Bool
isEmpty (Baseline byLap) =
    Dict.isEmpty byLap


{-| One car's laps against the baseline. A lap the group has no moment for
produces no point.
-}
against : Baseline -> List Lap -> List Point
against (Baseline byLap) laps =
    laps
        |> List.filterMap
            (\lap ->
                Dict.get lap.lap byLap
                    |> Maybe.map
                        (\crossed ->
                            { lap = lap.lap
                            , gap = Instant.since { from = crossed, to = lap.elapsed }
                            }
                        )
            )
