module Motorsport.Widget.Leaderboard exposing
    ( stringColumn, intColumn, floatColumn
    , Model, init
    , Msg, update
    , customColumn, veryCustomColumn
    , sectorTimeColumn, bestTimeColumn
    , histogramColumn, performanceColumn
    , carNumberColumn_Wec
    , driverAndTeamColumn_Wec
    , currentLapColumn_Wec, currentLapColumn_LeMans24h
    , lastLapColumn_Wec, lastLapColumn_LeMans24h
    , viewCarNumberColumn_Wec, viewDriverAndTeamColumn_Wec
    , viewCurrentLapColumn_Wec, viewCurrentLapColumn_LeMans24h
    , viewLastLapColumn_Wec, viewLastLapColumn_LeMans24h
    , Config, view
    )

{-|


# Configuration

@docs stringColumn, intColumn, floatColumn


# Model

@docs Model, init


# Update

@docs Msg, update


## Custom Columns

@docs Column, customColumn, veryCustomColumn

@docs sectorTimeColumn, bestTimeColumn
@docs histogramColumn, performanceColumn
@docs carNumberColumn_Wec
@docs driverAndTeamColumn_Wec
@docs currentLapColumn_Wec, currentLapColumn_LeMans24h
@docs lastLapColumn_Wec, lastLapColumn_LeMans24h

@docs viewCarNumberColumn_Wec, viewDriverAndTeamColumn_Wec
@docs viewCurrentLapColumn_Wec, viewCurrentLapColumn_LeMans24h
@docs viewLastLapColumn_Wec, viewLastLapColumn_LeMans24h

-}

import DataView
import DataView.Options exposing (Options, PaginationOption(..), SelectingOption(..), SortingOption(..))
import Html exposing (Html, div, img, text)
import Html.Attributes exposing (alt, class, src, style)
import Html.Lazy as Lazy
import Motorsport.BestTimes as BestTimes exposing (Holder)
import Motorsport.Chart.Histogram as Histogram
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (RatedTime, SegmentState, performanceLevel)
import Motorsport.Manufacturer exposing (Manufacturer)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, CurrentSectorStates, Snapshot)
import Motorsport.Sector as Sector
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
    DataView.Options.defaultOptions
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


{-| The `filter` every column carries. No view fires `DataView.Msg.Filter`, so
this is never consulted either; it only fills the field `DataView.Column`
requires.
-}
noFilter : data -> String -> Bool
noFilter _ _ =
    True



-- UPDATE


type alias Msg =
    DataView.Msg


update : Msg -> Model -> Model
update =
    DataView.update


type alias Config data msg =
    DataView.Config data msg



-- RATING COLOURS


{-| The colour of a rating that may not exist.

A sector, mini-sector or lap the source data has no time for has no rating
either, and takes the standard colour: there is nothing to rate it against.
Every cell that paints a rating goes through one of these two, so the fallback
is decided in one place rather than at each of them.

-}
colorOfRated : Maybe RatedTime -> String
colorOfRated =
    Maybe.map .performance >> colorOfPerformance


colorOfPerformance : Maybe Performance.PerformanceLevel -> String
colorOfPerformance =
    Maybe.withDefault Performance.Standard >> Performance.toColorVariable


{-| The text colour for a performance rating, `inherit` for a standard one so
it takes whatever colour the surrounding text already has.
-}
colorOfPerformanceText : Performance.PerformanceLevel -> String
colorOfPerformanceText performance =
    if Performance.isStandard performance then
        "inherit"

    else
        Performance.toColorVariable performance


{-| One cell of a sector or mini-sector strip: white as far as the car has got
while it is still in that stretch, and its rating's colour once the whole of it
is behind.

Both strips draw from [`Race.Snapshot`](Motorsport-Race-Snapshot)'s reading of
where the car stands, so at three sectors and at fifteen mini-sectors the cell
is the same cell.

A stretch the car has not reached draws nothing, which is what a zero-width fill
came to anyway -- the difference is that the reading now says so, rather than
leaving the cell to read it back out of a number.

-}
progressCell : SegmentState -> Html msg
progressCell state =
    let
        ( widthPercent, backgroundColor_ ) =
            case state of
                Performance.NotEntered ->
                    ( "0%", "transparent" )

                Performance.InProgress progress ->
                    ( String.fromFloat (progress * 100) ++ "%", "oklch(1 0 0)" )

                Performance.Completed rated ->
                    ( "100%", colorOfRated rated )
    in
    div
        [ class "h-[3px] rounded-[1px]"
        , style "width" widthPercent
        , style "background-color" backgroundColor_
        ]
        []


{-| The seventeen columns of the Le Mans strip: the fifteen mini-sectors in
track order, with a spacer where each of the first two sectors ends.
-}
miniSectorStrip : Snapshot.CurrentMiniSectorStates -> Html msg
miniSectorStrip states =
    div
        [ class "grid grid-cols-[2fr_2fr_3fr_0.5fr_5fr_1fr_3fr_3fr_0.5fr_1fr_5fr_3fr_2fr_1fr_1fr_1fr_1fr] gap-x-px" ]
        [ progressCell states.scl2
        , progressCell states.z4
        , progressCell states.ip1
        , div [] []
        , progressCell states.z12
        , progressCell states.sclc
        , progressCell states.a7_1
        , progressCell states.ip2
        , div [] []
        , progressCell states.a8_1
        , progressCell states.sclb
        , progressCell states.porin
        , progressCell states.porout
        , progressCell states.pitref
        , progressCell states.scl1
        , progressCell states.fordout
        , progressCell states.fl
        ]



-- COLUMNS


type alias Column data msg =
    DataView.Column data msg


{-| -}
stringColumn : { label : String, getter : data -> String } -> Column data msg
stringColumn =
    DataView.stringColumn


{-| -}
intColumn : { label : String, getter : data -> Int } -> Column data msg
intColumn =
    DataView.intColumn


{-| -}
floatColumn : { label : String, getter : data -> Float } -> Column data msg
floatColumn =
    DataView.floatColumn


{-| -}
customColumn :
    { label : String
    , getter : data -> String
    }
    -> Column data msg
customColumn { label, getter } =
    DataView.customColumn { label = label, getter = getter, sorter = noSorter }


{-| -}
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
is the same reading [`progressCell`](#progressCell) draws the thin strip from,
told apart the same way.

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
                                    colorOfRated rated

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
    , filter = noFilter
    }


bestTimeColumn : { getter : data -> Maybe RatedTime } -> Column data msg
bestTimeColumn { getter } =
    DataView.customColumn
        { label = "Best"
        , getter = getter >> Maybe.map (.time >> Duration.toString) >> Maybe.withDefault "-"
        , sorter = noSorter
        }


histogramColumn :
    { getter : data -> List Lap
    , bestTimes : { a | fastestLapTime : Maybe Holder, slowestLapTime : Maybe Holder }
    , coefficient : Float
    }
    -> Column data msg
histogramColumn { getter, bestTimes, coefficient } =
    { name = "Histogram"
    , view = getter >> Lazy.lazy3 Histogram.view bestTimes coefficient
    , sorter = noSorter
    , filter = noFilter
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
    , filter = noFilter
    }


carNumberColumn_Wec : { getter : data -> { a | carNumber : String, class : Class, manufacturer : Manufacturer } } -> Column data msg
carNumberColumn_Wec { getter } =
    { name = "#"
    , view = getter >> Lazy.lazy viewCarNumberColumn_Wec
    , sorter = noSorter
    , filter = noFilter
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
    , filter = noFilter
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
    , filter = noFilter
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
                [ class "text-center", style "color" (colorOfPerformanceText performance) ]
                [ text (Duration.toStringToSeconds time) ]
    in
    if Status.hasRetired status then
        div [ class "text-center" ] [ text "Retired" ]

    else
        div [ class "flex flex-col gap-y-[5px]" ]
            [ lapTime { time = currentLap.elapsed, performance = currentLap.performance }
            , div
                [ class "grid grid-cols-[1fr_1fr_1fr] gap-x-1" ]
                (List.map progressCell (Sector.values currentLap.sectorStates))
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
    , filter = noFilter
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
                [ class "text-center", style "color" (colorOfPerformanceText status_) ]
                [ text (Duration.toStringToSeconds time) ]
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
                                miniSectorStrip states

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
    , filter = noFilter
    }


viewLastLapColumn_Wec : Snapshot.LastLap -> Html msg
viewLastLapColumn_Wec lastLap =
    let
        lapTimeView { time, performance } =
            div
                [ class "text-center", style "color" (colorOfPerformanceText performance) ]
                [ text (Duration.toString time) ]

        sectorCell rated =
            div
                [ class "h-[3px] rounded-[1px]"
                , style "background-color" (colorOfRated rated)
                ]
                []
    in
    case lastLap of
        Snapshot.Completed { rated, sectors } ->
            case rated of
                Just lapTime ->
                    div [ class "flex flex-col gap-y-[5px]" ]
                        [ lapTimeView lapTime
                        , div
                            [ class "grid grid-cols-[1fr_1fr_1fr] gap-x-1" ]
                            (List.map sectorCell (Sector.values sectors))
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
    , filter = noFilter
    }


viewLastLapColumn_LeMans24h : Snapshot.LastLap -> Html msg
viewLastLapColumn_LeMans24h lastLap =
    let
        lapTimeView { time, performance } =
            div
                [ class "text-center", style "color" (colorOfPerformanceText performance) ]
                [ text (Duration.toString time) ]

        sectorCell rated =
            div
                [ class "h-[3px] rounded-[1px]"
                , style "background-color" (colorOfRated rated)
                ]
                []
    in
    case lastLap of
        Snapshot.Completed { rated, miniSectors } ->
            case rated of
                Just lapTime ->
                    div [ class "flex flex-col gap-y-[5px]" ]
                        [ lapTimeView lapTime
                        , miniSectors
                            |> Maybe.map
                                (\ms ->
                                    div [ class "grid grid-cols-[2fr_2fr_3fr_0.5fr_5fr_1fr_3fr_3fr_0.5fr_1fr_5fr_3fr_2fr_1fr_1fr_1fr_1fr] gap-x-px" ]
                                        [ sectorCell ms.scl2
                                        , sectorCell ms.z4
                                        , sectorCell ms.ip1
                                        , div [] [] -- spacer
                                        , sectorCell ms.z12
                                        , sectorCell ms.sclc
                                        , sectorCell ms.a7_1
                                        , sectorCell ms.ip2
                                        , div [] [] -- spacer
                                        , sectorCell ms.a8_1
                                        , sectorCell ms.sclb
                                        , sectorCell ms.porin
                                        , sectorCell ms.porout
                                        , sectorCell ms.pitref
                                        , sectorCell ms.scl1
                                        , sectorCell ms.fordout
                                        , sectorCell ms.fl
                                        ]
                                )
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



-- VIEW


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
                |> colorOfPerformance
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
