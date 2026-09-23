module Motorsport.Leaderboard exposing
    ( stringColumn, intColumn, floatColumn
    , Model, init
    , Msg, update
    , customColumn, veryCustomColumn
    , sectorTimeColumn, bestTimeColumn
    , performanceColumn
    , carNumberColumn_Wec
    , driverAndTeamColumn_Wec
    , positionChangeColumn
    , currentLapColumn_Wec, currentLapColumn_LeMans24h
    , lastLapColumn_Wec, lastLapColumn_LeMans24h
    , viewPositionChange, viewPositionChangeInline
    , viewCarNumberColumn_Wec, viewDriverAndTeamColumn_Wec
    , viewCurrentLapColumn_Wec, viewCurrentLapColumn_LeMans24h
    , viewLastLapColumn_Wec, viewLastLapColumn_LeMans24h
    , Config, view
    )

{-| The field as a timing table, drawn from the columns a classification is
printed in. Which of them, in what order, is the caller's.


# Configuration

@docs stringColumn, intColumn, floatColumn


# Model

@docs Model, init


# Update

@docs Msg, update


## Custom Columns

@docs Column, customColumn, veryCustomColumn

@docs sectorTimeColumn, bestTimeColumn
@docs performanceColumn
@docs carNumberColumn_Wec
@docs driverAndTeamColumn_Wec
@docs positionChangeColumn
@docs currentLapColumn_Wec, currentLapColumn_LeMans24h
@docs lastLapColumn_Wec, lastLapColumn_LeMans24h

@docs viewPositionChange, viewPositionChangeInline
@docs viewCarNumberColumn_Wec, viewDriverAndTeamColumn_Wec
@docs viewCurrentLapColumn_Wec, viewCurrentLapColumn_LeMans24h
@docs viewLastLapColumn_Wec, viewLastLapColumn_LeMans24h

-}

import Html exposing (Html, div, img, span, text)
import Html.Attributes exposing (alt, class, src, style)
import Html.Lazy as Lazy
import Internal.DataView as DataView
import Internal.DataView.Options as Options exposing (Options, PaginationOption(..), SelectingOption(..), SortingOption(..))
import Motorsport.BestTimes as BestTimes exposing (Holder)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (RatedTime, SegmentState, performanceLevel)
import Motorsport.Lap.SegmentStrip as SegmentStrip
import Motorsport.Manufacturer exposing (Manufacturer)
import Motorsport.Position as Position exposing (Movement(..), Position)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, CurrentSectorStates, Snapshot)
import Motorsport.Status as Status exposing (Status)
import Motorsport.Wec.Class exposing (Class)



-- MODEL


type alias Model =
    DataView.Model


init : Model
init =
    DataView.init "" options


options : Options
options =
    Options.defaultOptions
        |> (\options_ ->
                { options_
                    | sorting = NoSorting
                    , selecting = NoSelecting
                    , pagination = NoPagination
                }
           )


{-| The `sorter` every column carries. Sorting is off in `options`, so this is
never consulted; it only fills the field `DataView.Column` requires.
-}
noSorter : data -> data -> Order
noSorter _ _ =
    EQ



-- UPDATE


type alias Msg =
    DataView.Msg


update : Msg -> Model -> Model
update =
    DataView.update


type alias Config data msg =
    DataView.Config data msg



-- COLUMNS


type alias Column data msg =
    DataView.Column data msg


stringColumn : { label : String, getter : data -> String } -> Column data msg
stringColumn =
    DataView.stringColumn


intColumn : { label : String, getter : data -> Int } -> Column data msg
intColumn =
    DataView.intColumn


floatColumn : { label : String, getter : data -> Float } -> Column data msg
floatColumn =
    DataView.floatColumn


customColumn :
    { label : String
    , getter : data -> String
    }
    -> Column data msg
customColumn { label, getter } =
    DataView.customColumn { label = label, getter = getter, sorter = noSorter }


veryCustomColumn :
    { label : String
    , getter : data -> Html msg
    }
    -> Column data msg
veryCustomColumn { label, getter } =
    DataView.veryCustomColumn { label = label, getter = getter, sorter = noSorter }


{-| A full-height block for one sector of a lap, coloured by how that sector
went.

`Nothing` is a car with no sector to report at all, and draws nothing. A sector
the car has not finished is white; one it has is painted by its rating -- which
is the same reading [`Lap.SegmentStrip`](Motorsport-Lap-SegmentStrip) draws the
thin strip from, told apart the same way.

-}
sectorTimeColumn :
    { label : String
    , getter : data -> Maybe SegmentState
    }
    -> Column data msg
sectorTimeColumn { label, getter } =
    { name = label
    , view =
        getter
            >> Maybe.map
                (\state ->
                    div
                        [ class "h-[18px] rounded-[1px]"
                        , style "background-color"
                            (case state of
                                Performance.Completed rated ->
                                    SegmentStrip.colorOfRated rated

                                Performance.InProgress _ ->
                                    "oklch(1 0 0 / 0.9)"

                                Performance.NotEntered ->
                                    "oklch(1 0 0 / 0.9)"
                            )
                        ]
                        []
                )
            >> Maybe.withDefault (text "")
    , sorter = noSorter
    , filter = DataView.noFiltering
    }


bestTimeColumn : { getter : data -> Maybe RatedTime } -> Column data msg
bestTimeColumn { getter } =
    DataView.customColumn
        { label = "Best"
        , getter = getter >> Maybe.map (.time >> Duration.toString) >> Maybe.withDefault "-"
        , sorter = noSorter
        }


performanceColumn :
    { getter : data -> List Lap
    , bestTimes : { a | fastestLapTime : Maybe Holder }
    }
    -> Column data msg
performanceColumn { getter, bestTimes } =
    { name = "Performance"
    , view = getter >> performanceHistory bestTimes
    , sorter = noSorter
    , filter = DataView.noFiltering
    }


carNumberColumn_Wec : { getter : data -> { a | carNumber : String, class : Class, manufacturer : Manufacturer } } -> Column data msg
carNumberColumn_Wec { getter } =
    { name = "#"
    , view = getter >> Lazy.lazy viewCarNumberColumn_Wec
    , sorter = noSorter
    , filter = DataView.noFiltering
    }


viewCarNumberColumn_Wec : { a | carNumber : String, class : Class, manufacturer : Manufacturer } -> Html msg
viewCarNumberColumn_Wec { carNumber, manufacturer } =
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


driverAndTeamColumn_Wec : { getter : data -> { a | metadata : { b | drivers : List Driver, team : String }, currentDriver : Driver } } -> Column data msg
driverAndTeamColumn_Wec { getter } =
    { name = "Team / Driver"
    , view = getter >> Lazy.lazy viewDriverAndTeamColumn_Wec
    , sorter = noSorter
    , filter = DataView.noFiltering
    }


viewDriverAndTeamColumn_Wec : { a | metadata : { b | drivers : List Driver, team : String }, currentDriver : Driver } -> Html msg
viewDriverAndTeamColumn_Wec { metadata, currentDriver } =
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


{-| How far the car has moved from where it started, and no more than that.

`startPosition` is held by a `Car` and not a `CarAt`, so the caller looks it up
by car number.

-}
positionChangeColumn : { getter : data -> { startPosition : Maybe Position, position : Position } } -> Column data msg
positionChangeColumn { getter } =
    { name = "Pos"
    , view = getter >> Lazy.lazy viewPositionChange
    , sorter = noSorter
    , filter = DataView.noFiltering
    }


{-| The places gained or lost since the start: `↑2`, the arrow green for a gain
and red for a loss and the number always grey, and a grey `-` for a car that has
held its place or whose grid place is not known.
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


currentLapColumn_Wec :
    { getter :
        data
        ->
            { a
                | status : Status
                , currentLap :
                    { b
                        | elapsed : Duration
                        , performance : Performance.PerformanceLevel
                        , sectorStates : CurrentSectorStates
                    }
            }
    }
    -> Column data msg
currentLapColumn_Wec { getter } =
    { name = "Current Lap"
    , view = getter >> Lazy.lazy viewCurrentLapColumn_Wec
    , sorter = noSorter
    , filter = DataView.noFiltering
    }


viewCurrentLapColumn_Wec :
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
viewCurrentLapColumn_Wec { status, currentLap } =
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


currentLapColumn_LeMans24h :
    { getter :
        data
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
    , bestTimes : { b | fastestLapTime : Maybe Holder }
    }
    -> Column data msg
currentLapColumn_LeMans24h { getter, bestTimes } =
    { name = "Current Lap"
    , view = getter >> Lazy.lazy2 viewCurrentLapColumn_LeMans24h bestTimes
    , sorter = noSorter
    , filter = DataView.noFiltering
    }


viewCurrentLapColumn_LeMans24h :
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
viewCurrentLapColumn_LeMans24h bestTimes { status, bestLap, currentLap } =
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


lastLapColumn_Wec :
    { getter : data -> Snapshot.LastLap
    }
    -> Column data msg
lastLapColumn_Wec { getter } =
    { name = "Last Lap"
    , view = getter >> Lazy.lazy viewLastLapColumn_Wec
    , sorter = noSorter
    , filter = DataView.noFiltering
    }


viewLastLapColumn_Wec : Snapshot.LastLap -> Html msg
viewLastLapColumn_Wec lastLap =
    let
        lapTimeView { time, performance } =
            div
                [ class "text-center", style "color" (Performance.textColorOf performance) ]
                [ text (Duration.toString time) ]
    in
    case lastLap of
        Snapshot.Completed { rated, sectors } ->
            case rated of
                Just lapTime ->
                    div [ class "flex flex-col gap-y-[5px]" ]
                        [ lapTimeView lapTime
                        , SegmentStrip.sectorsRated sectors
                        ]

                Nothing ->
                    text "-"

        Snapshot.NoLapYet ->
            text "-"


lastLapColumn_LeMans24h :
    { getter : data -> Snapshot.LastLap
    }
    -> Column data msg
lastLapColumn_LeMans24h { getter } =
    { name = "Last Lap"
    , view = getter >> Lazy.lazy viewLastLapColumn_LeMans24h
    , sorter = noSorter
    , filter = DataView.noFiltering
    }


viewLastLapColumn_LeMans24h : Snapshot.LastLap -> Html msg
viewLastLapColumn_LeMans24h lastLap =
    let
        lapTimeView { time, performance } =
            div
                [ class "text-center", style "color" (Performance.textColorOf performance) ]
                [ text (Duration.toString time) ]
    in
    case lastLap of
        Snapshot.Completed { rated, miniSectors } ->
            case rated of
                Just lapTime ->
                    div [ class "flex flex-col gap-y-[5px]" ]
                        [ lapTimeView lapTime
                        , miniSectors
                            |> Maybe.map SegmentStrip.miniSectorsRated
                            |> Maybe.withDefault (text "-")
                        ]

                Nothing ->
                    text "-"

        Snapshot.NoLapYet ->
            text "-"



-- VIEW


view : Config CarAt msg -> Model -> Snapshot -> Html msg
view config state standings =
    DataView.view config state (Snapshot.toList standings)


performanceHistory : { a | fastestLapTime : Maybe Holder } -> List Lap -> Html msg
performanceHistory bestTimes laps =
    div
        [ class "grid grid-cols-[repeat(7,auto)]" ]
        [ Lazy.lazy2 performanceHistory_ bestTimes laps ]


performanceHistory_ : { a | fastestLapTime : Maybe Holder } -> List Lap -> Html msg
performanceHistory_ bestTimes laps =
    let
        fastestLapTime =
            BestTimes.timeOf bestTimes.fastestLapTime

        toCssColor lap =
            lap.time
                |> Maybe.map
                    (\time ->
                        performanceLevel
                            { time = time
                            , personalBest = lap.best
                            , fastest = fastestLapTime
                            }
                    )
                |> Performance.colorOf
    in
    div
        [ class "px-[0.3vw] grid grid-flow-col auto-cols-[max(5px,0.3vw)] grid-rows-[repeat(5,max(5px,0.3vw))] gap-[1.5px] first:ps-0 last:pe-0 [&:nth-child(n+2)]:[border-left:1px_solid_hsl(0_0%_0%)]" ]
        (List.map (\lap -> coloredCell (toCssColor lap)) laps)


coloredCell : String -> Html msg
coloredCell backgroundColor_ =
    div
        [ class "w-full h-full rounded-[10%]"
        , style "background-color" backgroundColor_
        ]
        []
