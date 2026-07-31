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

import Css exposing (..)
import Css.Color exposing (oklch)
import Css.Extra exposing (when)
import DataView
import DataView.Options exposing (Options, PaginationOption(..), SelectingOption(..))
import Html.Styled exposing (Html, div, img, span, text)
import Html.Styled.Attributes exposing (alt, css, src)
import Html.Styled.Lazy as Lazy
import Motorsport.Chart.Histogram as Histogram
import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap, MiniSectorProgress, MiniSectors, SectorProgress)
import Motorsport.Lap.Performance as Performance exposing (RatedTime, performanceLevel)
import Motorsport.Manufacturer as Manufacturer exposing (Manufacturer)
import Motorsport.Sector as Sector
import Motorsport.Status as Status exposing (Status)
import Motorsport.Utils exposing (compareBy)
import Motorsport.ViewModel.Standings as Standings exposing (CurrentSectorStates, Entry, MiniSectorPerformance, SectorPerformance, Standings)



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
    , getter : data -> Maybe { time : Duration, personalBest : Duration, fastest : Duration, progress : Float }
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
    , sorter = compareBy (getter >> Maybe.map .time >> Maybe.withDefault 0)
    , filter = \_ _ -> True
    }


bestTimeColumn : { getter : data -> Maybe RatedTime } -> Column data msg
bestTimeColumn { getter } =
    DataView.customColumn
        { label = "Best"
        , getter = getter >> Maybe.map (.time >> Duration.toString) >> Maybe.withDefault "-"
        , sorter = compareBy (getter >> Maybe.map .time >> Maybe.withDefault 0)
        }


histogramColumn :
    { getter : data -> List Lap
    , sorter : data -> data -> Order
    , bestTimes : { a | fastestLapTime : Duration, slowestLapTime : Duration }
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
    , bestTimes : { a | fastestLapTime : Duration }
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


driverAndTeamColumn_Wec : { getter : data -> { a | metadata : { b | drivers : List Driver, team : String }, currentDriver : Maybe Driver } } -> Column data msg
driverAndTeamColumn_Wec { getter } =
    { name = "Team / Driver"
    , view = getter >> Lazy.lazy viewDriverAndTeamColumn_Wec
    , sorter = compareBy (getter >> .metadata >> .team)
    , filter = \data query -> getter data |> (.metadata >> .team) |> String.startsWith query
    }


viewDriverAndTeamColumn_Wec : { a | metadata : { b | drivers : List Driver, team : String }, currentDriver : Maybe Driver } -> Html msg
viewDriverAndTeamColumn_Wec { metadata, currentDriver } =
    let
        isCurrentDriver driver =
            currentDriver
                |> Maybe.map (Driver.isSame driver)
                |> Maybe.withDefault False
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
    { getter : data -> { a | lastLapRated : Maybe RatedTime }
    , sorter : data -> data -> Order
    }
    -> Column data msg
lastLapColumn { getter, sorter } =
    { name = "Last Lap"
    , view =
        getter
            >> .lastLapRated
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
                , currentLapRated : Maybe RatedTime
                , currentLapSectorStates : Maybe CurrentSectorStates
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
        , currentLapRated : Maybe RatedTime
        , currentLapSectorStates : Maybe CurrentSectorStates
    }
    -> Html msg
viewCurrentLapColumn_Wec { status, currentLapRated, currentLapSectorStates } =
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

        sectorCell { progress, rated } =
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
                            , property "background-color" (Performance.toColorVariable rated.performance)
                            ]
                    ]
                ]
                []
    in
    if Status.hasRetired status then
        div [ css [ textAlign center ] ] [ text "Retired" ]

    else
        Maybe.map2
            (\rated slots ->
                div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                    [ lapTime rated
                    , div
                        [ css
                            [ property "display" "grid"
                            , property "grid-template-columns" "1fr 1fr 1fr"
                            , property "column-gap" "4px"
                            ]
                        ]
                        (List.map sectorCell (Sector.values slots))
                    ]
            )
            currentLapRated
            currentLapSectorStates
            |> Maybe.withDefault (text "-")


currentLapColumn_LeMans24h :
    { getter :
        data
        ->
            { a
                | status : Status
                , currentLapElapsed : Duration
                , currentLapBest : Maybe Duration
                , currentLapMiniSectors : Maybe MiniSectors
                , sector : Maybe SectorProgress
                , miniSector : Maybe MiniSectorProgress
            }
    , sorter : data -> data -> Order
    , bestTimes : { b | fastestLapTime : Duration, fastestMiniSectors : ByMiniSector Duration }
    }
    -> Column data msg
currentLapColumn_LeMans24h { getter, sorter, bestTimes } =
    { name = "Current Lap"
    , view = getter >> Lazy.lazy2 viewCurrentLapColumn_LeMans24h bestTimes
    , sorter = sorter
    , filter = \_ _ -> True
    }


viewCurrentLapColumn_LeMans24h :
    { b | fastestLapTime : Duration, fastestMiniSectors : ByMiniSector Duration }
    ->
        { a
            | status : Status
            , currentLapElapsed : Duration
            , currentLapBest : Maybe Duration
            , currentLapMiniSectors : Maybe MiniSectors
            , sector : Maybe SectorProgress
            , miniSector : Maybe MiniSectorProgress
        }
    -> Html msg
viewCurrentLapColumn_LeMans24h bestTimes { status, currentLapElapsed, currentLapBest, currentLapMiniSectors, miniSector } =
    let
        lapTime { time, personalBest } =
            div
                [ css
                    [ textAlign center
                    , let
                        status_ =
                            performanceLevel { time = time, personalBest = personalBest, fastest = bestTimes.fastestLapTime }
                      in
                      if Performance.isStandard status_ then
                        batch []

                      else
                        Performance.toColorVariable status_
                            |> property "color"
                    ]
                ]
                [ text (Duration.toString time) ]

        sectorCell sector_ =
            div
                [ css
                    [ height (px 3)
                    , borderRadius (px 1)
                    , batch <|
                        if sector_.progress < 1 then
                            [ width (pct (sector_.progress * 100))
                            , backgroundColor (oklch 1 0 0)
                            ]

                        else
                            [ width (pct 100)
                            , property "background-color"
                                (performanceLevel { time = Maybe.withDefault 1000000 sector_.time, personalBest = Maybe.withDefault 1000000 sector_.personalBest, fastest = sector_.fastest }
                                    |> Performance.toColorVariable
                                )
                            ]
                    ]
                ]
                []
    in
    if Status.hasRetired status then
        div [ css [ textAlign center ] ] [ text "Retired" ]

    else
        currentLapBest
            |> Maybe.map
                (\best ->
                    div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                        [ lapTime { time = currentLapElapsed, personalBest = best }
                        , let
                            progressMap =
                                LeMans.calculateMiniSectorProgress miniSector
                          in
                          div [ css [ property "display" "grid", property "grid-template-columns" "2fr 2fr 3fr 0.5fr 5fr 1fr 3fr 3fr 0.5fr 1fr 5fr 3fr 2fr 1fr 1fr 1fr 1fr", property "column-gap" "1px" ] ]
                            [ sectorCell { time = Maybe.andThen (.scl2 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.scl2 >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.scl2, progress = progressMap.scl2 }
                            , sectorCell { time = Maybe.andThen (.z4 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.z4 >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.z4, progress = progressMap.z4 }
                            , sectorCell { time = Maybe.andThen (.ip1 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.ip1 >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.ip1, progress = progressMap.ip1 }
                            , div [] [] -- spacer
                            , sectorCell { time = Maybe.andThen (.z12 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.z12 >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.z12, progress = progressMap.z12 }
                            , sectorCell { time = Maybe.andThen (.sclc >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.sclc >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.sclc, progress = progressMap.sclc }
                            , sectorCell { time = Maybe.andThen (.a7_1 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.a7_1 >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.a7_1, progress = progressMap.a7_1 }
                            , sectorCell { time = Maybe.andThen (.ip2 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.ip2 >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.ip2, progress = progressMap.ip2 }
                            , div [] [] -- spacer
                            , sectorCell { time = Maybe.andThen (.a8_1 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.a8_1 >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.a8_1, progress = progressMap.a8_1 }
                            , sectorCell { time = Maybe.andThen (.sclb >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.sclb >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.sclb, progress = progressMap.sclb }
                            , sectorCell { time = Maybe.andThen (.porin >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.porin >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.porin, progress = progressMap.porin }
                            , sectorCell { time = Maybe.andThen (.porout >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.porout >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.porout, progress = progressMap.porout }
                            , sectorCell { time = Maybe.andThen (.pitref >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.pitref >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.pitref, progress = progressMap.pitref }
                            , sectorCell { time = Maybe.andThen (.scl1 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.scl1 >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.scl1, progress = progressMap.scl1 }
                            , sectorCell { time = Maybe.andThen (.fordout >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.fordout >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.fordout, progress = progressMap.fordout }
                            , sectorCell { time = Maybe.andThen (.fl >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.fl >> .best) currentLapMiniSectors, fastest = bestTimes.fastestMiniSectors.fl, progress = progressMap.fl }
                            ]
                        ]
                )
            |> Maybe.withDefault (text "-")


lastLapColumn_Wec :
    { getter : data -> { a | lastLapRated : Maybe RatedTime, lastLapSectors : Maybe SectorPerformance }
    , sorter : data -> data -> Order
    }
    -> Column data msg
lastLapColumn_Wec { getter, sorter } =
    { name = "Last Lap"
    , view = getter >> Lazy.lazy viewLastLapColumn_Wec
    , sorter = sorter
    , filter = \_ _ -> True
    }


viewLastLapColumn_Wec : { a | lastLapRated : Maybe RatedTime, lastLapSectors : Maybe SectorPerformance } -> Html msg
viewLastLapColumn_Wec { lastLapRated, lastLapSectors } =
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

        sectorCell { performance } =
            div
                [ css
                    [ height (px 3)
                    , borderRadius (px 1)
                    , property "background-color" (Performance.toColorVariable performance)
                    ]
                ]
                []
    in
    case lastLapRated of
        Just lapTime ->
            div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                [ lapTimeView lapTime
                , case lastLapSectors of
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
    { getter : data -> { a | lastLapRated : Maybe RatedTime, lastLapMiniSectors : Maybe MiniSectorPerformance }
    , sorter : data -> data -> Order
    }
    -> Column data msg
lastLapColumn_LeMans24h { getter, sorter } =
    { name = "Last Lap"
    , view = getter >> Lazy.lazy viewLastLapColumn_LeMans24h
    , sorter = sorter
    , filter = \_ _ -> True
    }


viewLastLapColumn_LeMans24h : { a | lastLapRated : Maybe RatedTime, lastLapMiniSectors : Maybe MiniSectorPerformance } -> Html msg
viewLastLapColumn_LeMans24h { lastLapRated, lastLapMiniSectors } =
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

        sectorCell maybeRatedTime =
            div
                [ css
                    [ height (px 3)
                    , borderRadius (px 1)
                    , property "background-color"
                        (maybeRatedTime
                            |> Maybe.map .performance
                            |> Maybe.withDefault Performance.Standard
                            |> Performance.toColorVariable
                        )
                    ]
                ]
                []
    in
    case lastLapRated of
        Just lapTime ->
            div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                [ lapTimeView lapTime
                , lastLapMiniSectors
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


view : Config Entry msg -> Model -> Standings -> Html msg
view config state standings =
    DataView.view config state (Standings.toList standings)



-- VIEW


performanceHistory : { a | fastestLapTime : Duration } -> List Lap -> Html msg
performanceHistory bestTimes laps =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "repeat(7, auto)"
            ]
        ]
        [ Lazy.lazy2 performanceHistory_ bestTimes laps ]


performanceHistory_ : { a | fastestLapTime : Duration } -> List Lap -> Html msg
performanceHistory_ { fastestLapTime } laps =
    let
        toCssColor { time, best } =
            performanceLevel { time = time, personalBest = best, fastest = fastestLapTime }
                |> Performance.toColorVariable
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
