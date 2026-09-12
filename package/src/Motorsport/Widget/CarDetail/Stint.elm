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
import Motorsport.Status exposing (Status(..))


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


{-| The run the car is on, the runs behind it as a bar of the laps they took,
and who has driven how many of them.

What a stop cost is the stop's own business and is on the run it ended; what the
section is for is the shape of the race the car is running -- how long it goes
between stops, and how the driving has been shared out.

The laps alone cannot say whether the run they end on is still going: a car that
has retired leaves the same trace as one out on the road. `status` is what
settles it.

-}
view : Status -> Car.Metadata -> Summary -> Html msg
view status metadata summary =
    div [ class "grid gap-y-2" ]
        [ lastStint status summary
        , stintBar metadata summary
        , driverShare metadata summary
        , shape summary
        ]


{-| How many laps of the car's race each of its drivers has driven.

Read off the runs rather than the laps, so the share and the bar above it say
the same thing: a run is one driver's, and the colour it is drawn in is theirs.

The drivers come in the order the entry list names them, which is the order
their shades are picked in, so a driver who has yet to drive is listed at nought
rather than left out.

-}
driverShare : Car.Metadata -> Summary -> Html msg
driverShare metadata summary =
    if List.isEmpty summary.stints then
        text ""

    else
        div [ class "flex flex-wrap items-center gap-x-3 gap-y-0.5" ]
            (rowLabel "Laps" :: List.map (driverCell metadata summary) metadata.drivers)


driverCell : Car.Metadata -> Summary -> Driver -> Html msg
driverCell metadata summary driver =
    div [ class "flex items-center gap-x-1 min-w-0" ]
        [ div
            [ class "size-2 shrink-0 rounded-[1px]"
            , style "background-color" (driverShade metadata driver)
            ]
            []
        , div [ class "text-[10px] truncate" ] [ text (Driver.toSurname driver) ]
        , div [ class "text-[10px] tabular-nums text-muted-foreground" ]
            [ text (String.fromInt (lapsDrivenBy driver summary)) ]
        ]


lapsDrivenBy : Driver -> Summary -> Int
lapsDrivenBy driver summary =
    summary.stints
        |> List.filter (.driver >> Driver.isSame driver)
        |> List.map .lapCount
        |> List.sum


{-| The shape of the race the car is running: how often it has stopped, and how
long the runs between the stops have been.
-}
shape : Summary -> Html msg
shape summary =
    div [ class "text-[10px] text-muted-foreground tabular-nums" ]
        [ text (String.join " · " (List.filter ((/=) "") [ stopCount summary, stintLengths summary ])) ]


stopCount : Summary -> String
stopCount summary =
    case List.length summary.pitStops of
        0 ->
            "No stops yet"

        1 ->
            "1 stop"

        count ->
            String.fromInt count ++ " stops"


stintLengths : Summary -> String
stintLengths summary =
    let
        lengths =
            summary.stints |> List.filter (.pit >> (/=) Nothing) |> List.map .lapCount
    in
    case ( List.minimum lengths, List.maximum lengths, summary.medianStintLength ) of
        ( Just shortest, Just longest, Just median_ ) ->
            if shortest == longest then
                "runs of " ++ inLaps shortest

            else
                "runs of "
                    ++ String.fromInt shortest
                    ++ "-"
                    ++ inLaps longest
                    ++ ", median "
                    ++ String.fromInt median_

        _ ->
            ""


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
    , inLaps stint.lapCount
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


{-| The run the car is on, or the one it stopped on.

A car sitting in the pits is on no run, and neither is one that has yet to
complete a lap; between the two the laps say the same thing, so the status is
read first. A run the car will not resume is described as the run it was --
where it ran from and to -- rather than measured against runs it is no longer
trying to match.

-}
lastStint : Status -> Summary -> Html msg
lastStint status summary =
    case ( status, summary.current, List.Extra.last summary.stints ) of
        ( Retired, _, Just final ) ->
            stintLine { isRunning = False } final "retired"

        ( Checkered, _, Just final ) ->
            stintLine { isRunning = False } final "took the flag"

        ( InPit, _, _ ) ->
            note "In the pits"

        ( _, Just stint, _ ) ->
            stintLine { isRunning = True } stint (againstMedian summary stint)

        ( _, _, Just _ ) ->
            -- Every lap the car has completed is behind a stop, so the one it is
            -- driving is the first of a run rather than part of the last.
            note "On an out lap"

        _ ->
            note "No laps completed"


note : String -> Html msg
note label =
    div [ class "text-[11px] text-muted-foreground" ] [ text label ]


stintLine : { isRunning : Bool } -> Stint -> String -> Html msg
stintLine { isRunning } stint trailing =
    div [ class "flex flex-wrap items-baseline gap-x-3 text-[11px] tabular-nums" ]
        [ div []
            [ text
                ("Stint "
                    ++ String.fromInt stint.number
                    ++ " · L"
                    ++ String.fromInt stint.firstLap
                    ++ (if isRunning then
                            "-"

                        else
                            "-L" ++ String.fromInt stint.lastLap
                       )
                    ++ " · "
                    ++ inLaps stint.lapCount
                )
            ]
        , div [ class "text-muted-foreground" ]
            [ text ("avg " ++ durationOr "-" stint.averageLapTime) ]
        , div [ class "text-muted-foreground" ] [ text trailing ]
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
                inLaps remaining ++ " short of the median"

            else
                inLaps (abs remaining) ++ " past the median"

        Nothing ->
            ""


inLaps : Int -> String
inLaps count =
    String.fromInt count
        ++ (if abs count == 1 then
                " lap"

            else
                " laps"
           )


rowLabel : String -> Html msg
rowLabel label =
    div [ class "text-[9px] uppercase tracking-[0.03em] text-muted-foreground" ]
        [ text label ]


durationOr : String -> Maybe Duration -> String
durationOr fallback =
    Maybe.map Duration.toString >> Maybe.withDefault fallback
