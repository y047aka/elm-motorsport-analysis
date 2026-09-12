module Motorsport.Widget.CarDetail.Stint exposing
    ( Stint, Pit, Summary
    , summarize
    )

{-| A car's race read as the runs it made between pit stops.

Nothing in the feed states a stint; what it states is a stop, on the lap the
stop ended on. The runs are the laps cut at those, which is all the data there
is to say how a car is being operated -- no fuel load, no tyre, no strategy call.

@docs Stint, Pit, Summary
@docs summarize

-}

import List.Extra
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)


{-| One run between stops, numbered from the start of the race.

`pit` is the stop that ended it, and is `Nothing` for the run the car is on.
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


{-| `current` is the run the car is on, which a car sitting in the pits does not
have: its last lap is the one the stop ended on.

`medianStintLength` counts only the runs that ended, so the one in progress does
not drag it down as it goes.

-}
type alias Summary =
    { stints : List Stint
    , current : Maybe Stint
    , pitStops : List Pit
    , totalPitTime : Duration
    , medianStintLength : Maybe Int
    }


{-| Read a car's completed laps as the runs it made between stops.
-}
summarize : List Lap -> Summary
summarize laps =
    let
        stints =
            laps
                |> List.sortBy .lap
                |> splitAfter (\lap -> lap.pitTime /= Nothing)
                |> List.indexedMap toStint
                |> List.filterMap identity

        pitStops =
            List.filterMap .pit stints
    in
    { stints = stints
    , current = List.filter (.pit >> (==) Nothing) stints |> List.head
    , pitStops = pitStops
    , totalPitTime = List.sum (List.map .duration pitStops)
    , medianStintLength =
        stints
            |> List.filter (.pit >> (/=) Nothing)
            |> List.map .lapCount
            |> median
    }


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


median : List Int -> Maybe Int
median values =
    let
        sorted =
            List.sort values

        count =
            List.length sorted
    in
    if count == 0 then
        Nothing

    else
        sorted |> List.drop ((count - 1) // 2) |> List.head
