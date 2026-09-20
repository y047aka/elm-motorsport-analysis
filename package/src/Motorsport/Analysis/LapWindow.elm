module Motorsport.Analysis.LapWindow exposing
    ( LapWindow(..)
    , LapRange
    , laps, within
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
@docs LapRange
@docs laps, within

-}

import List.Extra
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Lap exposing (Lap)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Wec.Class exposing (Class)


type LapWindow
    = WholeRace
    | Recent Duration


{-| The lap numbers a window came out as, both ends drawn.

A record and not a pair: two Ints in a row can be swapped at a call site without
a word from the compiler, and the pair a chart's axis spans is the same shape
while meaning something else -- what was drawn rather than what was asked for.
The two are the same value in one chart and not in the other.

-}
type alias LapRange =
    { first : Int
    , last : Int
    }


{-| The window as the lap numbers a chart keeps its laps by.

Both ends are read off the one class rather than off the race: a slower class's
laps run out short of the race leader's and take longer to come round, so a
window measured off that leader would leave a chart's axis running on past where
its lines stop.

-}
laps : LapWindow -> Class -> Snapshot -> LapRange
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
            { first = 1, last = latest }

        Recent stretch ->
            { first = firstLapSince stretch snapshot classCars, last = latest }


{-| One car's laps that the range covers, out of everything it has run.

A range is lap numbers and not a stretch of time by the time it gets here, so a
car is cut at the laps its own class reached rather than at the ones it ran
inside the stretch itself.

-}
within : LapRange -> List Lap -> List Lap
within range =
    List.filter (\lap -> range.first <= lap.lap && lap.lap <= range.last)


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
