module Motorsport.Race.Stint exposing
    ( Stint, Pit
    , fromLaps
    , Index, emptyIndex, indexOf, stopsAt
    )

{-| A car's race read as the runs it made between pit stops.

Nothing in the feed states a stint; what it states is a stop, on the lap the
stop ended on. The runs are the laps cut at those, which is all the data there
is to say how a car is being operated -- no fuel load, no tyre, no strategy call.

A run is cut out of the laps it was given, so laps cut at a clock give the runs
as they stood at that moment. What the last of them _is_ at that moment is the
caller's to settle: a car sitting in the pits leaves the same trace as one out
on the road, and the laps alone cannot tell the two apart. See
[`Race.statusAt`](Motorsport-Race#statusAt).

@docs Stint, Pit
@docs fromLaps


## The field's stops, read at a clock

Cutting a car's laps answers everything about one car and costs a pass over its
race. Reading a count off every car on every frame is a different question, and
[`Index`](#Index) is what makes it cheap.

@docs Index, emptyIndex, indexOf, stopsAt

-}

import Dict exposing (Dict)
import List.Extra
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant exposing (Instant)
import Motorsport.Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car, CarNumber)


{-| One run between stops, numbered from the start of the race.

`pit` is the stop that ended it, and is `Nothing` for the run the laps end on.
`averageLapTime` and `bestLapTime` leave out the lap the stop fell on, whose
time carries the pit lane.

-}
type alias Stint =
    { number : Int
    , driver : Driver
    , firstLap : Int
    , lastLap : Int
    , lapCount : Int
    , averageLapTime : Maybe Duration
    , bestLapTime : Maybe Duration
    , pit : Maybe Pit
    }


{-| A stop, as the lap it ended on records it.
-}
type alias Pit =
    { lapNumber : Int
    , duration : Duration
    }


{-| Read a car's laps as the runs it made between stops.

The laps are put in race order first, so a list read in any order comes out cut
the same way.

-}
fromLaps : List Lap -> List Stint
fromLaps laps =
    laps
        |> List.sortBy .lap
        |> splitAfter (\lap -> lap.pitTime /= Nothing)
        |> List.indexedMap toStint
        |> List.filterMap identity


toStint : Int -> List Lap -> Maybe Stint
toStint index laps =
    case ( List.head laps, List.Extra.last laps ) of
        ( Just first, Just last ) ->
            let
                racingTimes =
                    laps
                        |> List.filter (\lap -> lap.pitTime == Nothing)
                        |> List.filterMap .time
            in
            Just
                { number = index + 1
                , driver = first.driver
                , firstLap = first.lap
                , lastLap = last.lap
                , lapCount = List.length laps
                , averageLapTime = average racingTimes
                , bestLapTime = List.minimum racingTimes
                , pit = last.pitTime |> Maybe.map (\duration -> { lapNumber = last.lap, duration = duration })
                }

        _ ->
            Nothing


{-| Cut the list after every item the test holds for, so the item that ends a
run stays in the run it ended.
-}
splitAfter : (a -> Bool) -> List a -> List (List a)
splitAfter isBoundary =
    List.foldr
        (\item groups ->
            if isBoundary item then
                [ item ] :: groups

            else
                case groups of
                    group :: rest ->
                        (item :: group) :: rest

                    [] ->
                        [ [ item ] ]
        )
        []


average : List Duration -> Maybe Duration
average durations =
    case durations of
        [] ->
            Nothing

        _ ->
            Just (List.sum durations // List.length durations)



-- THE FIELD'S STOPS, READ AT A CLOCK


{-| Every car's stops, indexed by the moment each of them ended.

[`fromLaps`](#fromLaps) counts a car's stops by cutting its laps, which is
affordable for the one car a panel is given over to and not for the field on
every frame: a race is twenty thousand laps. The stops are under two thousand of
them, so collecting those once and reading the count back is a binary search
over a fraction of the data. See
[`ChangePoints`](Motorsport-Internal-ChangePoints).

Keyed by car number, so two cars sharing one -- which the source data
occasionally has -- come to a single entry, as they do in
[`LapHistory`](Motorsport-Race-LapHistory).

-}
type Index
    = Index (Dict CarNumber (ChangePoints Pit))


{-| An index over no race at all. Every car reads back as having stopped never.
-}
emptyIndex : Index
emptyIndex =
    Index Dict.empty


{-| Collect the field's stops, each at the moment the lap it ended on was
completed.
-}
indexOf : List Car -> Index
indexOf cars =
    cars
        |> List.map (\car -> ( car.metadata.carNumber, stopsOf car.laps ))
        |> Dict.fromList
        |> Index


stopsOf : List Lap -> ChangePoints Pit
stopsOf laps =
    laps
        |> List.filterMap
            (\lap ->
                lap.pitTime
                    |> Maybe.map
                        (\duration -> ( lap.elapsed, { lapNumber = lap.lap, duration = duration } ))
            )
        |> ChangePoints.fromList


{-| How many stops a car has completed at a moment of the race.

A car in the pits reads at the stop before the one it is making: a stop is
recorded on the lap it ended on, and that lap is not complete until the car is
back out on the road. A car the race has never heard of has made none.

-}
stopsAt : { elapsed : Instant } -> CarNumber -> Index -> Int
stopsAt { elapsed } carNumber (Index index) =
    Dict.get carNumber index
        |> Maybe.map (ChangePoints.countUpTo elapsed)
        |> Maybe.withDefault 0
