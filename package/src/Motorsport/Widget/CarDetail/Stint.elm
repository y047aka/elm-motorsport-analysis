module Motorsport.Widget.CarDetail.Stint exposing
    ( Stint, Pit, Summary
    , summarize
    , view
    )

{-| A car's race read as the runs it made between pit stops.

Nothing in the feed states a stint; what it states is a stop, on the lap the
stop ended on. The runs are the laps cut at those, which is all the data there
is to say how a car is being operated -- no fuel load, no tyre, no strategy call.

@docs Stint, Pit, Summary
@docs summarize
@docs view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class, style, title)
import List.Extra
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.Manufacturer exposing (Manufacturer)
import Motorsport.Race.Car as Car


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



-- VIEW


{-| The runs the car has made, as a bar of them over the laps of the race, above
what the stops have cost and where the run in progress stands against the ones
before it.
-}
view : Car.Metadata -> Summary -> Html msg
view metadata summary =
    div [ class "grid gap-y-2" ]
        [ pitStats summary
        , stintBar metadata summary
        , currentStint summary
        ]


pitStats : Summary -> Html msg
pitStats summary =
    div [ class "border border-border rounded-lg grid grid-cols-4" ]
        [ statCell "Stops" (String.fromInt (List.length summary.pitStops))
        , statCell "Pit total" (durationOr "-" (Just summary.totalPitTime))
        , statCell "Last stop"
            (case List.Extra.last summary.pitStops of
                Just pit ->
                    "L" ++ String.fromInt pit.lapNumber ++ " " ++ Duration.toStringToTenths pit.duration

                Nothing ->
                    "-"
            )
        , statCell "Median stint"
            (case summary.medianStintLength of
                Just laps ->
                    String.fromInt laps ++ " laps"

                Nothing ->
                    "-"
            )
        ]


{-| Each run as a segment of the race so far, the widths in laps. The car's own
drivers are told apart by how solidly the manufacturer's colour is laid down,
and the run in progress is left open on its right-hand edge.
-}
stintBar : Car.Metadata -> Summary -> Html msg
stintBar metadata summary =
    let
        totalLaps =
            List.sum (List.map .lapCount summary.stints)
    in
    if totalLaps == 0 then
        text ""

    else
        div [ class "flex gap-x-px h-5 rounded overflow-hidden" ]
            (List.map (stintSegment metadata totalLaps) summary.stints)


stintSegment : Car.Metadata -> Int -> Stint -> Html msg
stintSegment metadata totalLaps stint =
    div
        [ class "grid place-items-center min-w-0 text-[9px] tabular-nums"
        , class
            (if stint.pit == Nothing then
                "rounded-r-sm outline outline-1 -outline-offset-1 outline-foreground/40"

             else
                ""
            )
        , style "flex-grow" (String.fromInt stint.lapCount)
        , style "flex-basis" (String.fromFloat (100 * toFloat stint.lapCount / toFloat totalLaps) ++ "%")
        , style "background-color" (driverShade metadata stint.driver)
        , title (stintTitle stint)
        ]
        [ text (String.fromInt stint.lapCount) ]


stintTitle : Stint -> String
stintTitle stint =
    [ "Stint " ++ String.fromInt stint.number
    , "L" ++ String.fromInt stint.firstLap ++ "-L" ++ String.fromInt stint.lastLap
    , String.fromInt stint.lapCount ++ " laps"
    , Driver.toFullName stint.driver
    , "avg " ++ durationOr "-" stint.averageLapTime
    , case stint.pit of
        Just pit ->
            "pit " ++ Duration.toStringToTenths pit.duration

        Nothing ->
            "running"
    ]
        |> String.join " · "


{-| How much of the manufacturer's colour a driver's runs are laid down in.
There is no colour of a driver's own in the data, and which of the car's own
drivers is out is the only thing the bar has to tell apart.
-}
driverShade : Car.Metadata -> Driver -> String
driverShade metadata driver =
    let
        alpha =
            case List.Extra.findIndex (Driver.isSame driver) metadata.drivers of
                Just 0 ->
                    "0.9"

                Just 1 ->
                    "0.6"

                Just 2 ->
                    "0.35"

                _ ->
                    "0.2"
    in
    shadeOf metadata.manufacturer alpha


shadeOf : Manufacturer -> String -> String
shadeOf manufacturer alpha =
    "oklch(from " ++ manufacturer.color ++ " l c h / " ++ alpha ++ ")"


currentStint : Summary -> Html msg
currentStint summary =
    case summary.current of
        Nothing ->
            div [ class "text-[11px] text-muted-foreground" ] [ text "In the pits" ]

        Just stint ->
            div [ class "flex flex-wrap items-baseline gap-x-3 text-[11px] tabular-nums" ]
                [ div []
                    [ text
                        ("Stint "
                            ++ String.fromInt stint.number
                            ++ " · L"
                            ++ String.fromInt stint.firstLap
                            ++ "- · "
                            ++ String.fromInt stint.lapCount
                            ++ " laps"
                        )
                    ]
                , div [ class "text-muted-foreground" ]
                    [ text ("avg " ++ durationOr "-" stint.averageLapTime) ]
                , div [ class "text-muted-foreground" ]
                    [ text (againstMedian summary stint) ]
                ]


{-| How the run in progress stands against the ones that ended, which is as far
as this data reaches towards when the car stops next: nothing in it says how
much fuel is left or what the plan is.
-}
againstMedian : Summary -> Stint -> String
againstMedian summary stint =
    case summary.medianStintLength of
        Just median_ ->
            let
                remaining =
                    median_ - stint.lapCount
            in
            if remaining > 0 then
                String.fromInt remaining ++ " laps short of the median"

            else
                String.fromInt (abs remaining) ++ " laps past the median"

        Nothing ->
            ""


statCell : String -> String -> Html msg
statCell label value =
    div
        [ class "grid gap-y-px justify-items-center py-1 px-0.5 border-l border-l-border first:border-l-0" ]
        [ div [ class "text-[8px] uppercase tracking-[0.03em] text-muted-foreground" ] [ text label ]
        , div [ class "text-[12px] tabular-nums" ] [ text value ]
        ]


durationOr : String -> Maybe Duration -> String
durationOr fallback =
    Maybe.map Duration.toString >> Maybe.withDefault fallback
