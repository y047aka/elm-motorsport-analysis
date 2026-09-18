module Motorsport.Race.LapWindow exposing
    ( LapWindow(..)
    , laps
    )

{-| How much of the race to read: all of it run so far, or the last stretch of
it.

The stretch is a length of time rather than a count of laps, because that is
what a race is read in -- an hour of it is an hour of it whether the cars spent
it lapping under a safety car or flat out. Turning one into lap numbers is the
race's to do rather than a chart's: which laps an hour covers depends on who was
running and how quickly they went round.

@docs LapWindow
@docs laps

-}

import List.Extra
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Wec.Class exposing (Class)


type LapWindow
    = WholeRace
    | Recent Duration


{-| The window as the lap numbers `( first, last )` a chart keeps its laps by.

Both ends are read off the one class rather than off the race: a slower class's
laps run out short of the race leader's and take longer to come round, so a
window measured off that leader would leave a chart's axis running on past where
its lines stop.

-}
laps : LapWindow -> Class -> Snapshot -> ( Int, Int )
laps window class snapshot =
    let
        classCars =
            Snapshot.inClass class snapshot

        latest =
            classCars
                |> List.map (.standing >> .lapsCompleted)
                |> List.maximum
                |> Maybe.withDefault 1
                |> max 1
    in
    case window of
        WholeRace ->
            ( 1, latest )

        Recent stretch ->
            ( firstLapSince stretch snapshot classCars, latest )


{-| The class leader's first lap completed no earlier than `stretch` ago, which
is where a chart drawn over that stretch starts. Lap 1 where the class has not
been running that long yet.
-}
firstLapSince : Duration -> Snapshot -> List CarAt -> Int
firstLapSince stretch snapshot classCars =
    let
        threshold =
            Instant.subtract stretch (Snapshot.elapsed snapshot)
    in
    classCars
        |> List.head
        |> Maybe.map (\leading -> LapHistory.get leading.metadata.carNumber (Snapshot.lapHistory snapshot))
        |> Maybe.andThen (List.Extra.find (\lap -> Instant.compare lap.elapsed threshold /= LT))
        |> Maybe.map .lap
        |> Maybe.withDefault 1
