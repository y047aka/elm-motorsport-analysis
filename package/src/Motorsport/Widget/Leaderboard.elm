module Motorsport.Widget.Leaderboard exposing
    ( stringColumn, intColumn, floatColumn
    , Model, initialSort
    , Msg, update
    , customColumn, veryCustomColumn
    , sectorTimeColumn, bestTimeColumn
    , histogramColumn, performanceColumn
    , carNumberColumn_Wec
    , driverAndTeamColumn_Wec
    , currentLapColumn_Wec, currentLapColumn_LeMans24h
    , lastLapColumn, lastLapColumn_Wec, lastLapColumn_LeMans24h
    , viewCarNumberColumn_Wec, viewDriverAndTeamColumn_Wec
    , viewCurrentLapColumn_Wec, viewCurrentLapColumn_LeMans24h
    , viewLastLapColumn_Wec, viewLastLapColumn_LeMans24h
    , Config, view
    )

{-|


# Configuration

@docs stringColumn, intColumn, floatColumn


# Model

@docs Model, initialSort


# Update

@docs Msg, update


## Custom Columns

@docs Column, customColumn, veryCustomColumn

@docs sectorTimeColumn, bestTimeColumn
@docs histogramColumn, performanceColumn
@docs carNumberColumn_Wec
@docs driverAndTeamColumn_Wec
@docs currentLapColumn_Wec, currentLapColumn_LeMans24h
@docs lastLapColumn, lastLapColumn_Wec, lastLapColumn_LeMans24h

@docs viewCarNumberColumn_Wec, viewDriverAndTeamColumn_Wec
@docs viewCurrentLapColumn_Wec, viewCurrentLapColumn_LeMans24h
@docs viewLastLapColumn_Wec, viewLastLapColumn_LeMans24h

-}

import Compare
import Css exposing (..)
import Css.Color exposing (oklch)
import Css.Extra exposing (when)
import DataView
import DataView.Options exposing (Options, PaginationOption(..), SelectingOption(..))
import Html.Styled exposing (Html, div, img, span, text)
import Html.Styled.Attributes exposing (alt, css, src)
import Html.Styled.Lazy as Lazy
import Motorsport.BestTimes as BestTimes exposing (Holder)
import Motorsport.Chart.Histogram as Histogram
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (MiniSectorPerformance, RatedTime, SectorPerformance, performanceLevel)
import Motorsport.Manufacturer as Manufacturer exposing (Manufacturer)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, CurrentMiniSectorStates, CurrentSectorStates, Snapshot)
import Motorsport.Sector as Sector
import Motorsport.Status as Status exposing (Status)



-- MODEL


type alias Model =
    DataView.Model


initialSort : String -> Model
initialSort key =
    DataView.init key options


options : Options
options =
    DataView.Options.defaultOptions
        |> (\options_ ->
                { options_
                    | selecting = NoSelecting
                    , pagination = NoPagination
                }
           )



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


{-| One cell of a sector or mini-sector strip: white as far as the car has got
while it is still in that stretch, and its rating's colour once the whole of it
is behind.

Both strips draw from [`Race.Snapshot`](Motorsport-Race-Snapshot)'s reading of
where the car stands, so at three sectors and at fifteen mini-sectors the cell
is the same cell.

-}
progressCell : { a | progress : Float, rated : Maybe RatedTime } -> Html msg
progressCell { progress, rated } =
    div
        [ css
            [ height (px 3)
            , borderRadius (px 1)
            , batch <|
                if progress < 1 then
                    [ width (pct (progress * 100))
                    , backgroundColor (oklch 1 0 0)
                    ]

                else
                    [ width (pct 100)
                    , property "background-color" (colorOfRated rated)
                    ]
            ]
        ]
        []


{-| The seventeen columns of the Le Mans strip: the fifteen mini-sectors in
track order, with a spacer where each of the first two sectors ends.
-}
miniSectorStrip : Snapshot.CurrentMiniSectorStates -> Html msg
miniSectorStrip states =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "2fr 2fr 3fr 0.5fr 5fr 1fr 3fr 3fr 0.5fr 1fr 5fr 3fr 2fr 1fr 1fr 1fr 1fr"
            , property "column-gap" "1px"
            ]
        ]
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
    , sorter : data -> data -> Order
    }
    -> Column data msg
customColumn =
    DataView.customColumn


{-| -}
veryCustomColumn :
    { label : String
    , getter : data -> Html msg
    , sorter : data -> data -> Order
    }
    -> Column data msg
veryCustomColumn =
    DataView.veryCustomColumn


sectorTimeColumn :
    { label : String
    , getter : data -> Maybe { time : Duration, personalBest : Maybe Duration, fastest : Maybe Duration, progress : Float }
    }
    -> Column data msg
sectorTimeColumn { label, getter } =
    { name = label
    , view =
        getter
            >> Maybe.map
                (\sector ->
                    div
                        [ css
                            [ height (px 18)
                            , borderRadius (px 1)
                            , property "background-color" <|
                                if sector.progress < 1 then
                                    "oklch(1 0 0 / 0.9)"

                                else
                                    performanceLevel sector
                                        |> Performance.toColorVariable
                            ]
                        ]
                        []
                )
            >> Maybe.withDefault (text "")
    , sorter = Compare.by (getter >> Maybe.map .time >> Maybe.withDefault 0)
    , filter = \_ _ -> True
    }


bestTimeColumn : { getter : data -> Maybe RatedTime } -> Column data msg
bestTimeColumn { getter } =
    DataView.customColumn
        { label = "Best"
        , getter = getter >> Maybe.map (.time >> Duration.toString) >> Maybe.withDefault "-"
        , sorter = Compare.by (getter >> Maybe.map .time >> Maybe.withDefault 0)
        }


histogramColumn :
    { getter : data -> List Lap
    , sorter : data -> data -> Order
    , bestTimes : { a | fastestLapTime : Maybe Holder, slowestLapTime : Maybe Holder }
    , coefficient : Float
    }
    -> Column data msg
histogramColumn { getter, sorter, bestTimes, coefficient } =
    { name = "Histogram"
    , view = getter >> Lazy.lazy3 Histogram.view bestTimes coefficient
    , sorter = sorter
    , filter = \_ _ -> True
    }


performanceColumn :
    { getter : data -> List Lap
    , sorter : data -> data -> Order
    , bestTimes : { a | fastestLapTime : Maybe Holder }
    }
    -> Column data msg
performanceColumn { getter, sorter, bestTimes } =
    { name = "Performance"
    , view = getter >> performanceHistory bestTimes
    , sorter = sorter
    , filter = \_ _ -> True
    }


carNumberColumn_Wec : { getter : data -> { a | carNumber : String, class : Class, manufacturer : Manufacturer } } -> Column data msg
carNumberColumn_Wec { getter } =
    { name = "#"
    , view = getter >> Lazy.lazy viewCarNumberColumn_Wec
    , sorter = \a b -> Class.compare (getter a).class (getter b).class
    , filter = \data query -> getter data |> .carNumber |> String.startsWith query
    }


viewCarNumberColumn_Wec : { a | carNumber : String, class : Class, manufacturer : Manufacturer } -> Html msg
viewCarNumberColumn_Wec { carNumber, manufacturer } =
    div
        [ css
            [ width (em 2.5)
            , property "padding" "4px"
            , displayFlex
            , flexDirection column
            , property "gap" "4px"
            , property "place-items" "center"
            , textAlign center
            , fontSize (px 12)
            , fontWeight bold
            , backgroundColor (Manufacturer.toColor manufacturer)
            , borderRadius (px 5)
            , property "line-height" "1"
            ]
        ]
        (case Manufacturer.toLogoUrl manufacturer of
            Just logoUrl ->
                [ img
                    [ src logoUrl
                    , alt (Manufacturer.toString manufacturer)
                    , css
                        [ property "object-fit" "contain"
                        , height (px 14)
                        ]
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
    , sorter = Compare.by (getter >> .metadata >> .team)
    , filter = \data query -> getter data |> (.metadata >> .team) |> String.startsWith query
    }


viewDriverAndTeamColumn_Wec : { a | metadata : { b | drivers : List Driver, team : String }, currentDriver : Driver } -> Html msg
viewDriverAndTeamColumn_Wec { metadata, currentDriver } =
    let
        isCurrentDriver driver =
            Driver.isSame driver currentDriver
    in
    div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
        [ div [] [ text metadata.team ]
        , div [ css [ displayFlex, property "column-gap" "10px" ] ] <|
            List.map
                (\driver ->
                    div
                        [ css
                            [ fontSize (px 10)
                            , fontStyle italic
                            , when (not (isCurrentDriver driver))
                                (color (hsl 0 0 0.75))
                            ]
                        ]
                        [ text (Driver.toInitialAndSurname driver) ]
                )
                metadata.drivers
        ]


lastLapColumn :
    { getter : data -> { a | lastLap : { b | rated : Maybe RatedTime } }
    , sorter : data -> data -> Order
    }
    -> Column data msg
lastLapColumn { getter, sorter } =
    { name = "Last Lap"
    , view =
        getter
            >> .lastLap
            >> .rated
            >> Maybe.map
                (\{ time, performance } ->
                    span
                        [ css
                            [ if Performance.isStandard performance then
                                batch []

                              else
                                Performance.toColorVariable performance
                                    |> property "color"
                            ]
                        ]
                        [ text (Duration.toString time) ]
                )
            >> Maybe.withDefault (text "-")
    , sorter = sorter
    , filter = \_ _ -> True
    }


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
    , sorter : data -> data -> Order
    }
    -> Column data msg
currentLapColumn_Wec { getter, sorter } =
    { name = "Current Lap"
    , view = getter >> Lazy.lazy viewCurrentLapColumn_Wec
    , sorter = sorter
    , filter = \_ _ -> True
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
                [ css
                    [ textAlign center
                    , if Performance.isStandard performance then
                        batch []

                      else
                        Performance.toColorVariable performance
                            |> property "color"
                    ]
                ]
                [ text (Duration.toString time) ]
    in
    if Status.hasRetired status then
        div [ css [ textAlign center ] ] [ text "Retired" ]

    else
        div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
            [ lapTime { time = currentLap.elapsed, performance = currentLap.performance }
            , div
                [ css
                    [ property "display" "grid"
                    , property "grid-template-columns" "1fr 1fr 1fr"
                    , property "column-gap" "4px"
                    ]
                ]
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
                        , miniSectorStates : Maybe CurrentMiniSectorStates
                    }
            }
    , sorter : data -> data -> Order
    , bestTimes : { b | fastestLapTime : Maybe Holder }
    }
    -> Column data msg
currentLapColumn_LeMans24h { getter, sorter, bestTimes } =
    { name = "Current Lap"
    , view = getter >> Lazy.lazy2 viewCurrentLapColumn_LeMans24h bestTimes
    , sorter = sorter
    , filter = \_ _ -> True
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
                    , miniSectorStates : Maybe CurrentMiniSectorStates
                }
        }
    -> Html msg
viewCurrentLapColumn_LeMans24h bestTimes { status, bestLap, currentLap } =
    let
        lapTime { time, personalBest } =
            div
                [ css
                    [ textAlign center
                    , let
                        status_ =
                            performanceLevel
                                { time = time
                                , personalBest = personalBest
                                , fastest = BestTimes.timeOf bestTimes.fastestLapTime
                                }
                      in
                      if Performance.isStandard status_ then
                        batch []

                      else
                        Performance.toColorVariable status_
                            |> property "color"
                    ]
                ]
                [ text (Duration.toString time) ]
    in
    if Status.hasRetired status then
        div [ css [ textAlign center ] ] [ text "Retired" ]

    else
        bestLap
            |> Maybe.map
                (\best ->
                    div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                        [ lapTime { time = currentLap.elapsed, personalBest = Just best.time }
                        , currentLap.miniSectorStates
                            |> Maybe.map miniSectorStrip
                            |> Maybe.withDefault (text "")
                        ]
                )
            |> Maybe.withDefault (text "-")


lastLapColumn_Wec :
    { getter : data -> { a | lastLap : { b | rated : Maybe RatedTime, sectors : Maybe SectorPerformance } }
    , sorter : data -> data -> Order
    }
    -> Column data msg
lastLapColumn_Wec { getter, sorter } =
    { name = "Last Lap"
    , view = getter >> Lazy.lazy viewLastLapColumn_Wec
    , sorter = sorter
    , filter = \_ _ -> True
    }


viewLastLapColumn_Wec : { a | lastLap : { b | rated : Maybe RatedTime, sectors : Maybe SectorPerformance } } -> Html msg
viewLastLapColumn_Wec { lastLap } =
    let
        lapTimeView { time, performance } =
            div
                [ css
                    [ textAlign center
                    , if Performance.isStandard performance then
                        batch []

                      else
                        Performance.toColorVariable performance
                            |> property "color"
                    ]
                ]
                [ text (Duration.toString time) ]

        sectorCell rated =
            div
                [ css
                    [ height (px 3)
                    , borderRadius (px 1)
                    , property "background-color" (colorOfRated rated)
                    ]
                ]
                []
    in
    case lastLap.rated of
        Just lapTime ->
            div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                [ lapTimeView lapTime
                , case lastLap.sectors of
                    Just slots ->
                        div
                            [ css
                                [ property "display" "grid"
                                , property "grid-template-columns" "1fr 1fr 1fr"
                                , property "column-gap" "4px"
                                ]
                            ]
                            (List.map sectorCell (Sector.values slots))

                    Nothing ->
                        text ""
                ]

        Nothing ->
            text "-"


lastLapColumn_LeMans24h :
    { getter : data -> { a | lastLap : { b | rated : Maybe RatedTime, miniSectors : Maybe MiniSectorPerformance } }
    , sorter : data -> data -> Order
    }
    -> Column data msg
lastLapColumn_LeMans24h { getter, sorter } =
    { name = "Last Lap"
    , view = getter >> Lazy.lazy viewLastLapColumn_LeMans24h
    , sorter = sorter
    , filter = \_ _ -> True
    }


viewLastLapColumn_LeMans24h : { a | lastLap : { b | rated : Maybe RatedTime, miniSectors : Maybe MiniSectorPerformance } } -> Html msg
viewLastLapColumn_LeMans24h { lastLap } =
    let
        lapTimeView { time, performance } =
            div
                [ css
                    [ textAlign center
                    , if Performance.isStandard performance then
                        batch []

                      else
                        Performance.toColorVariable performance
                            |> property "color"
                    ]
                ]
                [ text (Duration.toString time) ]

        sectorCell rated =
            div
                [ css
                    [ height (px 3)
                    , borderRadius (px 1)
                    , property "background-color" (colorOfRated rated)
                    ]
                ]
                []
    in
    case lastLap.rated of
        Just lapTime ->
            div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                [ lapTimeView lapTime
                , lastLap.miniSectors
                    |> Maybe.map
                        (\ms ->
                            div [ css [ property "display" "grid", property "grid-template-columns" "2fr 2fr 3fr 0.5fr 5fr 1fr 3fr 3fr 0.5fr 1fr 5fr 3fr 2fr 1fr 1fr 1fr 1fr", property "column-gap" "1px" ] ]
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



-- VIEW


view : Config CarAt msg -> Model -> Snapshot -> Html msg
view config state standings =
    DataView.view config state (Snapshot.toList standings)



-- VIEW


performanceHistory : { a | fastestLapTime : Maybe Holder } -> List Lap -> Html msg
performanceHistory bestTimes laps =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "repeat(7, auto)"
            ]
        ]
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
        [ css
            [ property "padding-inline" "0.3vw"
            , property "display" "grid"
            , property "grid-auto-flow" "column"
            , property "grid-auto-columns" "max(5px, 0.3vw)"
            , property "grid-template-rows" "repeat(5, max(5px, 0.3vw))"
            , property "gap" "1.5px"
            , firstChild
                [ property "padding-inline-start" "0" ]
            , nthChild "n+2"
                [ borderLeft3 (px 1) solid (hsl 0 0 0) ]
            , lastChild
                [ property "padding-inline-end" "0" ]
            ]
        ]
        (List.map (\lap -> coloredCell (toCssColor lap)) laps)


coloredCell : String -> Html msg
coloredCell backgroundColor_ =
    div
        [ css
            [ width (pct 100)
            , height (pct 100)
            , borderRadius (pct 10)
            , property "background-color" backgroundColor_
            ]
        ]
        []
