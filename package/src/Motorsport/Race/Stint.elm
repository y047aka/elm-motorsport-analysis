module Motorsport.Race.Stint exposing
    ( Stint, End(..), Pit
    , fromLaps
    , Index, emptyIndex, indexOf, stopsAt
    )

{-| A car's race read as the runs it made between pit stops.

Nothing in the feed states a stint; what it states is the two ends of a stop,
one lap apart. The runs are the laps cut at the lap the car came in on, so a run
begins on the lap it came back out on and ends on the lap it next came in. That
is all the data there is to say how a car is being operated -- no fuel load, no
tyre, no strategy call.

A run is cut out of the laps it was given, so laps cut at a clock give the runs
as they stood at that moment. Whether the car will resume the run it is on is
still the caller's to settle: a car that has retired leaves the same trace as
one out on the road. See [`Race.statusAt`](Motorsport-Race#statusAt).

@docs Stint, End, Pit
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
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car, CarNumber)


{-| One run between stops, numbered from the start of the race.

`averageLapTime` and `bestLapTime` leave out the laps that touched the pit lane
-- the one the run begins on and the one it ends on -- whose times carry it.

-}
type alias Stint =
    { number : Int
    , driver : Driver
    , firstLap : Int
    , lastLap : Int
    , lapCount : Int
    , averageLapTime : Maybe Duration
    , bestLapTime : Maybe Duration
    , end : End
    }


{-| How a run finished.

`InPit` is a run that is over as much as `Ended` is: `lastLap` is the lap the
car came in on either way. What separates them is that a stop is not timed until
the car is back out, so the run it ended reads as `InPit` for as long as the car
is stationary.

-}
type End
    = Running
    | InPit
    | Ended Pit


{-| A stop, as the lap the car came back out on records it.
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
    let
        runs =
            laps
                |> List.sortBy .lap
                |> splitAfter Lap.isInLap

        {- The stop that ended a run is recorded on the first lap of the run
           after it, which is the lap the car came back out on.
        -}
        ends =
            (List.drop 1 runs |> List.map (List.head >> Maybe.andThen stopEnding)) ++ [ Nothing ]
    in
    List.map2 Tuple.pair runs ends
        |> List.indexedMap toStint
        |> List.filterMap identity


stopEnding : Lap -> Maybe Pit
stopEnding outLap =
    Lap.stopOf outLap
        |> Maybe.map (\duration -> { lapNumber = outLap.lap, duration = duration })


toStint : Int -> ( List Lap, Maybe Pit ) -> Maybe Stint
toStint index ( laps, stop ) =
    case ( List.head laps, List.Extra.last laps ) of
        ( Just first, Just last ) ->
            let
                racingTimes =
                    laps
                        |> List.filter Lap.isRacingLap
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
                , end =
                    case ( Lap.isInLap last, stop ) of
                        ( False, _ ) ->
                            Running

                        ( True, Nothing ) ->
                            InPit

                        ( True, Just pit ) ->
                            Ended pit
                }

        _ ->
            Nothing


{-| Cut the list after every item the test holds for, so the lap the car came in
on stays in the run it ended.
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


{-| Collect the field's stops, each at the moment the car drove away from it.
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
        |> List.filterMap (\lap -> Maybe.map2 Tuple.pair (Lap.stopEndedAt lap) (stopEnding lap))
        |> ChangePoints.fromList


{-| How many stops a car has completed at a moment of the race.

A car standing in its box reads at the stop before the one it is making, and
goes up the moment it drives away rather than when the lap it drove away on is
completed -- the same moment [`Race.statusAt`](Motorsport-Race#statusAt) has it
back out on the road. A car the race has never heard of has made none.

-}
stopsAt : { elapsed : Instant } -> CarNumber -> Index -> Int
stopsAt { elapsed } carNumber (Index index) =
    Dict.get carNumber index
        |> Maybe.map (ChangePoints.countUpTo elapsed)
        |> Maybe.withDefault 0
