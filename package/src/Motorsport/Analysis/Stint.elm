module Motorsport.Analysis.Stint exposing
    ( Summary, summarize
    , endedLengths, lapsDrivenBy
    )

{-| A car's race read as the runs it made between pit stops.

What a run is, and how the laps are cut into them, is
[`Race.Stint`](Motorsport-Race-Stint)'s. What is here is what a view asks of
those runs: which one the car is on, how the ones behind it compare, and who
has driven how many of the laps.

@docs Summary, summarize
@docs endedLengths, lapsDrivenBy

-}

import Internal.Statistics as Statistics
import List.Extra
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Lap exposing (Lap)
import Motorsport.Race.Stint as RaceStint exposing (Stint)


{-| `current` is the run the car is on, which a car sitting in the pits does not
have: its last lap is the one it came in on.

`medianStintLength` counts only the runs that ended, so the one in progress does
not drag it down as it goes.

-}
type alias Summary =
    { stints : List Stint
    , current : Maybe Stint
    , medianStintLength : Maybe Int
    }


{-| Read a car's completed laps as the runs it made between stops, and the
readings taken over them.
-}
summarize : List Lap -> Summary
summarize laps =
    let
        stints =
            RaceStint.fromLaps laps
    in
    { stints = stints
    , current = List.Extra.find (.end >> (==) RaceStint.Running) stints
    , medianStintLength = Statistics.median (endedLengths stints)
    }


{-| The laps each completed run took. The run in progress is left out: how long
it comes to is not settled until it ends.
-}
endedLengths : List Stint -> List Int
endedLengths =
    List.filter hasEnded >> List.map .lapCount


hasEnded : Stint -> Bool
hasEnded stint =
    stint.end /= RaceStint.Running


{-| How many laps this driver has driven, over every run they took out.
-}
lapsDrivenBy : Driver -> Summary -> Int
lapsDrivenBy driver summary =
    summary.stints
        |> List.filter (.driver >> Driver.isSame driver)
        |> List.map .lapCount
        |> List.sum
