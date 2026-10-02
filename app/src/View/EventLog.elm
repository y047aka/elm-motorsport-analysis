module View.EventLog exposing (rows)

{-| The Log section of a car detail panel: one car's lines, told stint by stint.

What a line is is [`CarLog`](Motorsport-Analysis-CarLog)'s, read off the
timeline and the car's own laps; what a run is, and where the runs cut the laps,
is [`Race.Stint`](Motorsport-Race-Stint)'s. This module is only how the two are
ruled together: the newest run first, its lines newest first under it, and a
run with no lines still named.

@docs rows

-}

import Html exposing (Html, div, span, text)
import Html.Attributes exposing (class, style)
import List.Extra
import Motorsport.Analysis.CarLog as CarLog
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap
import Motorsport.Lap.Performance as Performance
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Race.Stint as RaceStint exposing (Stint)
import Motorsport.Race.Timeline exposing (Timeline)


{-| One car's lines by the panel's clock, newest first, grouped under the run
each was set on, at most `recentLimit` of them in all.

The laps are cut at the same clock as the lines before the runs are cut from
them, so no run appears that the clock has not reached, and the run in progress
is the newest one on top.
-}
rows : List Car -> Timeline -> Snapshot -> CarNumber -> Html msg
rows cars timeline snapshot carNumber =
    case List.Extra.find (\car -> car.metadata.carNumber == carNumber) cars of
        Nothing ->
            nothingYet

        Just car ->
            let
                elapsed =
                    Snapshot.elapsed snapshot

                stints =
                    car.laps
                        |> Lap.completedLapsAt { elapsed = elapsed }
                        |> RaceStint.fromLaps

                lines =
                    CarLog.lines { elapsed = elapsed } car timeline
                        |> List.take recentLimit
            in
            case stints of
                [] ->
                    nothingYet

                _ ->
                    stints
                        |> List.map (\stint -> ( stint, linesOf stints stint lines ))
                        |> List.reverse
                        |> List.map stintBlock
                        |> div [ class "grid gap-y-3" ]


{-| The lines a run took.

A line belongs to the last run that had reached its lap, so the stop that ended
a run is told under that run — `CarLog` already dates a stop to the lap the car
entered the lane on, which is the run's last lap. A line about a lap no run
covers, or about no lap at all, falls to the first run or the last rather than
being dropped.

-}
linesOf : List Stint -> Stint -> List CarLog.Line -> List CarLog.Line
linesOf stints stint lines =
    List.filter (holderOf stints >> (==) stint.number) lines


holderOf : List Stint -> CarLog.Line -> Int
holderOf stints line =
    case line.lap of
        Nothing ->
            1

        Just lap ->
            stints
                |> List.filter (.firstLap >> (<=) lap)
                |> List.Extra.last
                |> Maybe.map .number
                |> Maybe.withDefault 1


stintBlock : ( Stint, List CarLog.Line ) -> Html msg
stintBlock ( stint, lines ) =
    div [ class "grid gap-y-px" ]
        [ stintHead stint
        , if List.isEmpty lines then
            div [ class bodyClass ]
                [ text "Nothing logged" ]

          else
            div [ class bodyClass ] (List.map lineRow lines)
        ]


{-| The run the lines under it were set on: which of the car's drivers took it,
and the laps it covers. The open right edge of a run still going matches the
panel's own Stints section.
-}
stintHead : Stint -> Html msg
stintHead stint =
    div [ class "grid grid-cols-[1fr_auto] items-baseline gap-x-2 py-0.5" ]
        [ div [ class "text-[10px] uppercase tracking-[0.03em] text-muted-foreground truncate" ]
            [ text ("Stint " ++ String.fromInt stint.number ++ " · " ++ Driver.toInitialAndSurname stint.driver) ]
        , div [ class "text-[10px] tabular-nums text-muted-foreground" ]
            [ text (lapSpan stint) ]
        ]


lapSpan : Stint -> String
lapSpan stint =
    let
        last =
            case stint.end of
                RaceStint.Running ->
                    ""

                _ ->
                    String.fromInt stint.lastLap
    in
    "L" ++ String.fromInt stint.firstLap ++ "-" ++ last


bodyClass : String
bodyClass =
    "ml-[3px] border-l border-border pl-2 grid gap-y-px"


nothingYet : Html msg
nothingYet =
    div [ class "p-5 text-center italic text-muted-foreground" ]
        [ text "Nothing has happened to this car yet" ]


recentLimit : Int
recentLimit =
    100


lineRow : CarLog.Line -> Html msg
lineRow line =
    div [ class "grid grid-cols-[2rem_1fr_auto] gap-x-2 items-baseline py-0.5" ]
        [ div [ class "text-right tabular-nums text-muted-foreground" ]
            [ text (Maybe.map String.fromInt line.lap |> Maybe.withDefault "-") ]
        , div [ class "truncate", style "color" (Performance.textColorOf line.level) ]
            [ text line.label

            -- The colour the row carries is the rating, which rates the lap time and
            -- not the driver beside it.
            , case line.by of
                Just second ->
                    span [ class "text-foreground" ] [ text (" · " ++ second) ]

                Nothing ->
                    text ""
            ]
        , div [ class "tabular-nums text-muted-foreground" ]
            [ text (line.at |> Instant.toDuration |> Duration.toStringToSeconds) ]
        ]
