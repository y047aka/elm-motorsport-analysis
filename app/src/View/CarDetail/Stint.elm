module View.CarDetail.Stint exposing (view)

{-| [`Analysis.Stint`](Motorsport-Analysis-Stint) drawn as the panel's stints
section.

@docs view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class, style, title)
import List.Extra
import Motorsport.Analysis.Stint as AnalysisStint exposing (Summary)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Manufacturer as Manufacturer exposing (Manufacturer)
import Motorsport.Race.Car as Car
import Motorsport.Race.Stint as RaceStint exposing (Stint)
import Motorsport.Status exposing (Status(..))


{-| The run the car is on, the runs behind it as a bar of the laps they took,
and who has driven how many of them.

What a stop cost is the stop's own business and is on the run it ended; what the
section is for is the shape of the race the car is running -- how long it goes
between stops, and how the driving has been shared out.

Two readings come from the race rather than from the laps, both because the laps
here are cut at the clock. `status` settles whether the run they end on is still
going: a car that has retired leaves the same trace as one out on the road.
`stops` is the count, which the laps fall one short of while the car is driving
away from one -- what a stop took is recorded on the lap it began, and that lap
is not in a list cut at the clock until it is over.

-}
view : { status : Status, stops : Int } -> Car.Metadata -> Summary -> Html msg
view race metadata summary =
    div [ class "grid gap-y-2" ]
        [ lastStint race.status summary
        , stintBar metadata summary
        , driverShare metadata summary
        , shape race.stops summary
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
    if List.isEmpty (AnalysisStint.all summary) then
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
            [ text (String.fromInt (AnalysisStint.lapsDrivenBy driver summary)) ]
        ]


{-| The shape of the race the car is running: how often it has stopped, and how
long the runs between the stops have been.
-}
shape : Int -> Summary -> Html msg
shape stops summary =
    div [ class "text-[10px] text-muted-foreground tabular-nums" ]
        [ text (String.join " · " (List.filter ((/=) "") [ stopCount stops, stintLengths summary ])) ]


stopCount : Int -> String
stopCount stops =
    case stops of
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
            List.map .lapCount (AnalysisStint.ended summary)
    in
    case ( List.minimum lengths, List.maximum lengths, AnalysisStint.medianStintLength summary ) of
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
        stints =
            AnalysisStint.all summary

        totalLaps =
            List.sum (List.map .lapCount stints)
    in
    if totalLaps == 0 then
        text ""

    else
        div [ class "flex gap-x-px h-5 rounded overflow-hidden" ]
            (List.map (stintSegment metadata totalLaps) stints)


stintSegment : Car.Metadata -> Int -> Stint -> Html msg
stintSegment metadata totalLaps stint =
    div
        [ class "grid place-items-center min-w-0 text-[9px] tabular-nums"
        , class
            (if stint.end == RaceStint.Running then
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
    , case stint.end of
        RaceStint.Ended pit ->
            "pit " ++ Duration.toStringToTenths pit.duration

        RaceStint.InPit ->
            -- The length is on a lap the car has not finished.
            "pit -"

        RaceStint.Running ->
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
    "oklch(from " ++ Manufacturer.color manufacturer ++ " l c h / " ++ alpha ++ ")"


{-| The run the car is on, or the one it stopped on.

A car sitting in the pits is on no run, and neither is one that has yet to
complete a lap; between the two the laps say the same thing, so the status is
read first. A run the car will not resume is described as the run it was --
where it ran from and to -- rather than measured against runs it is no longer
trying to match.

-}
lastStint : Status -> Summary -> Html msg
lastStint status summary =
    case ( status, AnalysisStint.current summary, List.Extra.last (AnalysisStint.all summary) ) of
        ( Retired, _, Just final ) ->
            stintLine { isRunning = False } final "retired"

        ( Checkered, _, Just final ) ->
            stintLine { isRunning = False } final "took the flag"

        ( InPit, _, _ ) ->
            note "In the pits"

        ( OutLap, _, _ ) ->
            note "On an out lap"

        ( _, Just stint, _ ) ->
            stintLine { isRunning = True } stint (againstMedian summary stint)

        ( _, _, Just _ ) ->
            -- Every lap the car has completed is behind a stop it has not come
            -- back out of, which the laps have no further word on.
            note "In the pits"

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
    case AnalysisStint.medianStintLength summary of
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
