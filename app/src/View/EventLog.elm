module View.EventLog exposing (rows)

{-| The Log section of a car detail panel: one car's lines, told stint by stint.

What a line is is [`CarLog`](Motorsport-Analysis-CarLog)'s, read off the
timeline and the car's own laps; what a run is, and where the runs cut the laps,
is [`Race.Stint`](Motorsport-Race-Stint)'s. This module is only how the two are
ruled together: the runs oldest first, their lines oldest first under them, and
a run with no lines still named.

@docs rows

-}

import Html exposing (Html, details, div, span, summary, text)
import Html.Attributes exposing (attribute, class, style)
import List.Extra
import Motorsport.Analysis.CarLog as CarLog
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap
import Motorsport.Lap.Performance as Performance
import Motorsport.Position as Position
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Race.Stint as RaceStint exposing (Stint)
import Motorsport.Race.Timeline exposing (Timeline)


{-| One car's lines by the panel's clock, the runs oldest first and the lines
within a run oldest first.

The laps are cut at the same clock as the lines before the runs are cut from
them, so no run appears that the clock has not reached, and the run in progress
is the last one, at the bottom.

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

                laps =
                    Lap.completedLapsAt { elapsed = elapsed } car.laps

                stints =
                    RaceStint.fromLaps laps

                lines =
                    CarLog.lines { elapsed = elapsed } car timeline

                baselines =
                    { personalBest = List.filterMap .best laps |> List.minimum
                    , fastest =
                        snapshot
                            |> Snapshot.bestTimes
                            |> .fastestLapTime
                            |> BestTimes.timeOf
                    }
            in
            case stints of
                [] ->
                    -- An announcement can arrive before the first crossing does,
                    -- and there is no run yet to tell it by.
                    if List.isEmpty lines then
                        nothingYet

                    else
                        div [ class "grid gap-y-px text-[11px]" ]
                            (List.map lineRow (List.reverse lines))

                _ ->
                    let
                        last =
                            List.length stints
                    in
                    stints
                        |> List.map
                            (\stint ->
                                stintBlock baselines (stint.number == last) ( stint, linesOf stint lines )
                            )
                        |> div [ class "grid gap-y-1" ]


{-| The lines a run took.

A line belongs to the run whose laps cover its lap — the run it was recorded
in. A stop belongs to the run it ended, not the one whose out-lap times the
lane — where the feed parks the lane's time is the feed's bookkeeping.

The runs cut the completed laps with no gap and no overlap, so one reading of
the run alone places a line: a lap holds to at most one run, and a lap behind
the first run's own — lap 0, where the car crossed into the lane before it had
completed a lap — or no lap at all belongs to the first.

-}
linesOf : Stint -> List CarLog.Line -> List CarLog.Line
linesOf stint =
    List.filter (recordedBy stint)


recordedBy : Stint -> CarLog.Line -> Bool
recordedBy stint line =
    case line.lap of
        Nothing ->
            stint.number == 1

        Just lap ->
            if lap < stint.firstLap then
                stint.number == 1

            else
                lap <= stint.lastLap


{-| One run: its head, and under it the lines it took, shut behind the head
until the reader opens them.

Open or shut is the element's own; the model remembers nothing. The newest
run arrives open, where playback's news lands, and the render that sees the
next run begin takes this one's opening back.

-}
stintBlock : { personalBest : Maybe Duration, fastest : Maybe Duration } -> Bool -> ( Stint, List CarLog.Line ) -> Html msg
stintBlock baselines isMostRecent ( stint, lines ) =
    details
        [ class "group grid gap-y-px"
        , if isMostRecent then
            attribute "open" ""

          else
            class ""
        ]
        [ summary [ class "flex items-baseline gap-x-1.5 py-1 cursor-pointer list-none select-none" ]
            [ span [ class "text-[9px] leading-none text-muted-foreground transition-transform duration-150 group-open:rotate-90 shrink-0" ]
                [ text "▸" ]
            , div [ class "grid gap-y-0.5 flex-grow min-w-0" ]
                [ div [ class "flex items-baseline gap-x-2" ]
                    [ div [ class "text-[11px] uppercase tracking-[0.03em] text-muted-foreground shrink-0" ]
                        [ text ("Stint " ++ String.fromInt stint.number) ]
                    , div [ class "text-[11px] text-foreground/90 truncate" ]
                        [ text (Driver.toInitialAndSurname stint.driver) ]
                    , placeTally stint
                    ]
                , div [ class "text-[11px] tabular-nums text-muted-foreground" ]
                    [ text (inLaps stint.lapCount ++ " · best ")
                    , bestCell baselines stint.bestLapTime
                    ]
                ]
            ]
        , if List.isEmpty lines then
            div [ class (bodyClass ++ " italic text-muted-foreground") ]
                [ text "Nothing logged" ]

          else
            -- CarLog hands its lines over newest first; a run is told in
            -- the order it happened.
            div [ class bodyClass ] (List.map lineRow (List.reverse lines))
        ]


{-| Where the run leaves the car, and what it did to the place, in the
Leaderboard's arrow colouring. The places are the run's two crossings, so a
stop's own cost is the drop to the next head's place, at the boundary where
the Pit line sits. The feed's lap place is the field's, whatever class the
car runs in.
-}
placeTally : Stint -> Html msg
placeTally stint =
    case ( stint.firstPlace, stint.lastPlace ) of
        ( Just first, Just last ) ->
            let
                movement =
                    Position.movement { from = first, to = last }

                printed =
                    Position.toArrow movement
            in
            div [ class "ms-auto shrink-0 flex items-baseline gap-x-1 text-[13px] text-muted-foreground tabular-nums" ]
                [ text ("P" ++ String.fromInt last)
                , case movement of
                    Position.Gained _ ->
                        span [ class "text-green-500" ] [ text printed.arrow ]

                    Position.Lost _ ->
                        span [ class "text-red-500" ] [ text printed.arrow ]

                    Position.Held ->
                        text ""
                , text printed.places
                ]

        _ ->
            text ""


{-| The run's best, rated as every lap time in the panel is rated — against
the car's own best and the race's record as the clock stands on them, not as
they stood when the run ended. So one run at most wears the car's mark, and
it is the run holding the car's best lap so far.
-}
bestCell : { personalBest : Maybe Duration, fastest : Maybe Duration } -> Maybe Duration -> Html msg
bestCell baselines best =
    span
        [ Performance.rateTime baselines.fastest { time = best, personalBest = baselines.personalBest }
            |> Maybe.map (.performance >> Performance.toColorVariable)
            |> Maybe.withDefault "inherit"
            |> style "color"
        ]
        [ text (bestOrDash best) ]


bestOrDash : Maybe Duration -> String
bestOrDash =
    Maybe.map Duration.toString >> Maybe.withDefault "-"


inLaps : Int -> String
inLaps count =
    String.fromInt count
        ++ (if count == 1 then
                " lap"

            else
                " laps"
           )


bodyClass : String
bodyClass =
    "ml-[3px] border-l border-border pl-2 grid gap-y-px text-[11px]"


nothingYet : Html msg
nothingYet =
    div [ class "p-5 text-center italic text-muted-foreground" ]
        [ text "Nothing has happened to this car yet" ]


lineRow : CarLog.Line -> Html msg
lineRow line =
    div [ class "grid grid-cols-[2rem_1fr_auto] gap-x-2 items-baseline py-0.5" ]
        [ div [ class "text-right tabular-nums text-muted-foreground" ]
            [ text (Maybe.map String.fromInt line.lap |> Maybe.withDefault "-") ]
        , div [ class "truncate", style "color" (Performance.textColorOf line.level) ]
            [ text line.label ]
        , div [ class "tabular-nums text-muted-foreground" ]
            [ text (line.at |> Instant.toDuration |> Duration.toStringToSeconds) ]
        ]
