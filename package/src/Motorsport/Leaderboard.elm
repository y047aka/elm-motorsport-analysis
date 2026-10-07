module Motorsport.Leaderboard exposing
    ( ratedTime
    , viewPositionChange, viewPositionChangeInline
    , viewCarNumber_Wec, viewDriverAndTeam_Wec
    , viewCurrentLap_Wec, viewCurrentLap_LeMans24h
    , viewLastLap_Wec, viewLastLap_LeMans24h
    )

{-| The readings of a classification as a timing screen prints them: a rated
lap time in the colour of its rating, the places moved since the grid as an
arrow, the running lap with the sectors it has reached and the last one under
it.

Which readings a drawing carries, in what order and at what width, is the
drawing's own; how each reading is drawn is held here, so every drawing of
the race says the same number the same way.

@docs ratedTime
@docs viewPositionChange, viewPositionChangeInline
@docs viewCarNumber_Wec, viewDriverAndTeam_Wec
@docs viewCurrentLap_Wec, viewCurrentLap_LeMans24h
@docs viewLastLap_Wec, viewLastLap_LeMans24h

-}

import Html exposing (Html, div, img, span, text)
import Html.Attributes exposing (alt, class, src, style)
import Motorsport.BestTimes as BestTimes exposing (Holder)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap.Performance as Performance exposing (RatedTime, performanceLevel)
import Motorsport.Lap.SegmentStrip as SegmentStrip
import Motorsport.Manufacturer exposing (Manufacturer)
import Motorsport.Position as Position exposing (Movement(..), Position)
import Motorsport.Race.Snapshot as Snapshot exposing (CurrentSectorStates)
import Motorsport.Status as Status exposing (Status)
import Motorsport.Wec.Class exposing (Class)


{-| A rated time as a timing screen prints it: the time in the colour of its
rating, and a `-` in the reader's own colour where nothing is rated — no lap
finished, or one the source data never timed.

Everything that prints a rated time goes through this, so the dash and the
colours cannot drift apart.

    ratedTime Nothing
    --> { color = "", text = "-" }

-}
ratedTime : Maybe RatedTime -> { text : String, color : String }
ratedTime rated =
    case rated of
        Just { time, performance } ->
            { text = Duration.toString time
            , color = Performance.textColorOf performance
            }

        Nothing ->
            { text = "-", color = "" }


{-| A time and colour set centred.
-}
colouredTime : { text : String, color : String } -> Html msg
colouredTime time =
    div [ class "text-center", style "color" time.color ] [ text time.text ]


{-| The car's number on a tile of its manufacturer's colour, the logo above
it where there is one.
-}
viewCarNumber_Wec : { a | carNumber : String, class : Class, manufacturer : Manufacturer } -> Html msg
viewCarNumber_Wec { carNumber, manufacturer } =
    div
        [ class "w-[2.5em] p-1 flex flex-col gap-1 place-items-center text-center text-[12px] font-bold rounded-[5px] leading-none"
        , style "background-color" manufacturer.color
        ]
        (case manufacturer.logoUrl of
            Just logoUrl ->
                [ img
                    [ src logoUrl
                    , alt manufacturer.name
                    , class "object-contain h-[14px]"
                    ]
                    []
                , text carNumber
                ]

            Nothing ->
                [ text carNumber ]
        )


{-| The team, and under it the driving lineup with the current driver in
full weight and the others muted.
-}
viewDriverAndTeam_Wec : { a | metadata : { b | drivers : List Driver, team : String }, currentDriver : Driver } -> Html msg
viewDriverAndTeam_Wec { metadata, currentDriver } =
    let
        isCurrentDriver driver =
            Driver.isSame driver currentDriver
    in
    div [ class "flex flex-col gap-y-[5px]" ]
        [ div [] [ text metadata.team ]
        , div [ class "flex gap-x-2.5" ] <|
            List.map
                (\driver ->
                    div
                        [ class
                            ("text-[10px] italic"
                                ++ (if isCurrentDriver driver then
                                        ""

                                    else
                                        " text-muted-foreground"
                                   )
                            )
                        ]
                        [ text (Driver.toInitialAndSurname driver) ]
                )
                metadata.drivers
        ]


{-| How far the car has moved from where it started, as a timing screen sets
it in its own cell: `↑2`, the arrow green for a gain and red for a loss and
the number always grey, and a grey `-` for a car that has held its place or
whose grid place is not known.

`startPosition` is held by a `Car` and not a `CarAt`, so the caller looks it
up by car number.

-}
viewPositionChange : { startPosition : Maybe Position, position : Position } -> Html msg
viewPositionChange change =
    case movementOf change of
        Held ->
            text "-"

        movement ->
            div [ class "text-center font-bold tabular-nums" ] (arrow movement)


{-| The same change set in a line of text: in the weight of the text around it,
and nothing at all where the cell prints `-`, which beside a position reads as
part of the position.
-}
viewPositionChangeInline : { startPosition : Maybe Position, position : Position } -> Html msg
viewPositionChangeInline change =
    case movementOf change of
        Held ->
            text ""

        movement ->
            span [ class "tabular-nums" ] (arrow movement)


{-| A grid place that is not known reads as one held: there is no movement to
draw either way.
-}
movementOf : { startPosition : Maybe Position, position : Position } -> Movement
movementOf { startPosition, position } =
    startPosition
        |> Maybe.map (\start -> Position.movement { from = start, to = position })
        |> Maybe.withDefault Held


arrow : Movement -> List (Html msg)
arrow movement =
    let
        printed =
            Position.toArrow movement

        color =
            case movement of
                Gained _ ->
                    "text-green-500"

                Held ->
                    ""

                Lost _ ->
                    "text-red-500"
    in
    [ span [ class color ] [ text printed.arrow ], text printed.places ]


{-| The lap running: the clock in the colour of how it is going, and under it
the sectors as reached. A retired car reads Retired.
-}
viewCurrentLap_Wec :
    { a
        | status : Status
        , currentLap :
            { b
                | elapsed : Duration
                , performance : Performance.PerformanceLevel
                , sectorStates : CurrentSectorStates
            }
    }
    -> Html msg
viewCurrentLap_Wec { status, currentLap } =
    let
        lapTime { time, performance } =
            div
                [ class "text-center", style "color" (Performance.textColorOf performance) ]
                [ text (Duration.toStringToTenths time) ]
    in
    if Status.hasRetired status then
        div [ class "text-center" ] [ text "Retired" ]

    else
        div [ class "flex flex-col gap-y-[5px]" ]
            [ lapTime { time = currentLap.elapsed, performance = currentLap.performance }
            , SegmentStrip.sectors currentLap.sectorStates
            ]


{-| The running lap on a circuit timed to the mini-sector — Le Mans's grain.
The clock is rated against the race's record and the car's own best, which is
why the lap being run needs both beside it.
-}
viewCurrentLap_LeMans24h :
    { b | fastestLapTime : Maybe Holder }
    ->
        { a
            | status : Status
            , bestLap : Maybe RatedTime
            , currentLap :
                { c
                    | elapsed : Duration
                    , miniSectors : Snapshot.MiniSectorReading
                }
        }
    -> Html msg
viewCurrentLap_LeMans24h bestTimes { status, bestLap, currentLap } =
    let
        lapTime { time, personalBest } =
            let
                status_ =
                    performanceLevel
                        { time = time
                        , personalBest = personalBest
                        , fastest = BestTimes.timeOf bestTimes.fastestLapTime
                        }
            in
            div
                [ class "text-center", style "color" (Performance.textColorOf status_) ]
                [ text (Duration.toStringToTenths time) ]
    in
    if Status.hasRetired status then
        div [ class "text-center" ] [ text "Retired" ]

    else
        bestLap
            |> Maybe.map
                (\best ->
                    div [ class "flex flex-col gap-y-[5px]" ]
                        [ lapTime { time = currentLap.elapsed, personalBest = Just best.time }
                        , case currentLap.miniSectors of
                            Snapshot.Recorded { states } ->
                                SegmentStrip.miniSectors states

                            Snapshot.NotRecorded ->
                                text ""
                        ]
                )
            |> Maybe.withDefault (text "-")


{-| The last lap finished: the time in the colour of its rating, and under it
the segments the circuit timed it in.
-}
viewLastLap_Wec : Snapshot.LastLap -> Html msg
viewLastLap_Wec lastLap =
    case lastLap of
        Snapshot.Completed { rated, sectors } ->
            case rated of
                Just _ ->
                    div [ class "flex flex-col gap-y-[5px]" ]
                        [ colouredTime (ratedTime rated)
                        , SegmentStrip.sectorsRated sectors
                        ]

                Nothing ->
                    text "-"

        Snapshot.NoLapYet ->
            text "-"


{-| The last lap at Le Mans's grain: the time, and under it the mini-sectors
it ran through.
-}
viewLastLap_LeMans24h : Snapshot.LastLap -> Html msg
viewLastLap_LeMans24h lastLap =
    case lastLap of
        Snapshot.Completed { rated, miniSectors } ->
            case rated of
                Just _ ->
                    div [ class "flex flex-col gap-y-[5px]" ]
                        [ colouredTime (ratedTime rated)
                        , miniSectors
                            |> Maybe.map SegmentStrip.miniSectorsRated
                            |> Maybe.withDefault (text "-")
                        ]

                Nothing ->
                    text "-"

        Snapshot.NoLapYet ->
            text "-"
