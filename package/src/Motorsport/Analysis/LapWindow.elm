module Motorsport.Analysis.LapWindow exposing
    ( LapWindow(..)
    , range
    )

{-| How much of the race to read: all of it run so far, or the last stretch of
it.

The stretch is a length of time rather than a count of laps, because that is
what a race is read in -- an hour of it is an hour of it whether the cars spent
it lapping under a safety car or flat out. Turning one into lap numbers is the
race's to do rather than a chart's: which laps an hour covers depends on who was
running and how quickly they went round.

A reading under `Motorsport/Analysis/`: derived from a snapshot and the
primitives, holding nothing of its own.

@docs LapWindow
@docs range

-}

import List.Extra
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.LapRange exposing (LapRange)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Wec.Class exposing (Class)


type LapWindow
    = WholeRace
    | Recent Duration


{-| The window as the lap numbers a chart keeps its laps by.

Both ends are read off the one class rather than off the race: a slower class's
laps run out short of the race leader's and take longer to come round, so a
window measured off that leader would leave a chart's axis running on past where
its lines stop.

What comes out is lap numbers and no longer a stretch of time, so a car is cut
at the laps its own class reached rather than at the ones it ran inside the
stretch itself.

-}
range : LapWindow -> Class -> Snapshot -> LapRange
range window class snapshot =
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
            { first = 1, last = latest }

        Recent stretch ->
            { first = firstLapSince stretch snapshot classCars, last = latest }


{-| Where a chart drawn over `stretch` starts: the lap the car furthest through
the race was on when the stretch began. Lap 1 where the class has not been
running that long yet.

Every car of the class is asked, and the furthest through answers, rather than
asking the one at the front of the order. They are usually the same car, but not
always: a car that retired while leading keeps the laps it had and so keeps its
place in the order for as long as it takes the rest to pass it, and asked on its
own it has nothing inside the stretch at all -- the window would quietly open
out to the whole race while the toggle still said otherwise. Cars with nothing
in the stretch say nothing about where it starts.

-}
firstLapSince : Duration -> Snapshot -> List CarAt -> Int
firstLapSince stretch snapshot classCars =
    let
        threshold =
            Instant.subtract stretch (Snapshot.elapsed snapshot)

        firstLapOf car =
            LapHistory.get car.metadata.carNumber (Snapshot.lapHistory snapshot)
                |> List.Extra.find (\lap -> Instant.compare lap.elapsed threshold /= LT)
                |> Maybe.map .lap
    in
    classCars
        |> List.filterMap firstLapOf
        |> List.maximum
        |> Maybe.withDefault 1
