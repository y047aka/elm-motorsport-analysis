module Motorsport.Analysis.Stint exposing
    ( Summary, summarize
    , all, ended, current, medianStintLength
    , lapsDrivenBy
    )

{-| A car's race read as the runs it made between pit stops.

What a run is, and how the laps are cut into them, is
[`Race.Stint`](Motorsport-Race-Stint)'s. What is here is what a view asks of
those runs: which one the car is on, how the ones behind it compare, and who
has driven how many of the laps.

@docs Summary, summarize
@docs all, ended, current, medianStintLength
@docs lapsDrivenBy

-}

import Internal.Statistics as Statistics
import List.Extra
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Lap exposing (Lap)
import Motorsport.Race.Stint as RaceStint exposing (Stint)


{-| The run the car is on is held apart from the ones that ended, which a car
sitting in the pits does not have: its last lap is the one it came in on.

The median counts only the runs that ended, so the one in progress does not
drag it down as it goes.

-}
type Summary
    = Summary
        { ended : List Stint
        , current : Maybe Stint
        , medianStintLength : Maybe Int
        }


{-| Read a car's completed laps as the runs it made between stops, and the
readings taken over them.
-}
summarize : List Lap -> Summary
summarize laps =
    let
        ( endedStints, currentStint ) =
            split (RaceStint.fromLaps laps)
    in
    Summary
        { ended = endedStints
        , current = currentStint
        , medianStintLength = Statistics.median (List.map .lapCount endedStints)
        }


{-| The run in progress is the last of them and only ever the last: a run is cut
at the lap the car came in on, so every run before the final one ended there.
-}
split : List Stint -> ( List Stint, Maybe Stint )
split stints =
    case List.Extra.unconsLast stints of
        Just ( last, rest ) ->
            if last.end == RaceStint.Running then
                ( rest, Just last )

            else
                ( stints, Nothing )

        Nothing ->
            ( [], Nothing )


{-| Every run the car has made, in the order it made them.
-}
all : Summary -> List Stint
all (Summary summary) =
    case summary.current of
        Just stint ->
            summary.ended ++ [ stint ]

        Nothing ->
            summary.ended


{-| The runs behind the car, which are the ones there is anything to measure
across.
-}
ended : Summary -> List Stint
ended (Summary summary) =
    summary.ended


current : Summary -> Maybe Stint
current (Summary summary) =
    summary.current


medianStintLength : Summary -> Maybe Int
medianStintLength (Summary summary) =
    summary.medianStintLength


{-| How many laps this driver has driven, over every run they took out.
-}
lapsDrivenBy : Driver -> Summary -> Int
lapsDrivenBy driver summary =
    all summary
        |> List.filter (.driver >> Driver.isSame driver)
        |> List.map .lapCount
        |> List.sum
