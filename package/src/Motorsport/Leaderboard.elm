module Motorsport.Leaderboard exposing
    ( stringColumn, intColumn, floatColumn
    , Model, initialSort
    , Msg, update
    , customColumn, veryCustomColumn
    , sectorTimeColumn, bestTimeColumn
    , histogramColumn, performanceColumn
    , carNumberColumn_Wec
    , driverNameColumn_F1, driverAndTeamColumn_Wec
    , currentLapColumn_Wec, currentLapColumn_LeMans24h
    , lastLapColumn_F1, lastLapColumn_Wec, lastLapColumn_LeMans24h
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
@docs driverNameColumn_F1, driverAndTeamColumn_Wec
@docs currentLapColumn_Wec, currentLapColumn_LeMans24h
@docs lastLapColumn_F1, lastLapColumn_Wec, lastLapColumn_LeMans24h

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
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Car as Car exposing (Status)
import Motorsport.Chart.Histogram as Histogram
import Motorsport.Circuit.LeMans as LeMans
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap, MiniSectors)
import Motorsport.Lap.Performance as Performance exposing (performanceLevel)
import Motorsport.Manufacturer as Manufacturer exposing (Manufacturer)
import Motorsport.Standings as Standings exposing (MiniSectorProgress, SectorProgress, SectorTimes, Standings, StandingsEntry)
import Motorsport.Sector exposing (Sector(..))
import Motorsport.Utils exposing (compareBy)



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
                                if sector.progress < 100 then
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


bestTimeColumn : { getter : data -> Maybe Duration } -> Column data msg
bestTimeColumn { getter } =
    DataView.customColumn
        { label = "Best"
        , getter = getter >> Maybe.map Duration.toString >> Maybe.withDefault "-"
        , sorter = compareBy (getter >> Maybe.withDefault 0)
        }


histogramColumn :
    { getter : data -> List Lap
    , sorter : data -> data -> Order
    , analysis : Analysis
    , coefficient : Float
    }
    -> Column data msg
histogramColumn { getter, sorter, analysis, coefficient } =
    { name = "Histogram"
    , view = getter >> Lazy.lazy3 Histogram.view analysis coefficient
    , sorter = sorter
    , filter = \_ _ -> True
    }


performanceColumn :
    { getter : data -> List Lap
    , sorter : data -> data -> Order
    , analysis : Analysis
    }
    -> Column data msg
performanceColumn { getter, sorter, analysis } =
    { name = "Performance"
    , view = getter >> performanceHistory analysis
    , sorter = sorter
    , filter = \_ _ -> True
    }


carNumberColumn_Wec : Int -> { getter : data -> { a | carNumber : String, class : Class, manufacturer : Manufacturer } } -> Column data msg
carNumberColumn_Wec season { getter } =
    { name = "#"
    , view = getter >> Lazy.lazy2 viewCarNumberColumn_Wec season
    , sorter = compareBy (getter >> .class >> Class.toString)
    , filter = \data query -> getter data |> .carNumber |> String.startsWith query
    }


viewCarNumberColumn_Wec : Int -> { a | carNumber : String, class : Class, manufacturer : Manufacturer } -> Html msg
viewCarNumberColumn_Wec season { carNumber, class, manufacturer } =
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


driverNameColumn_F1 : { label : String, getter : data -> String } -> Column data msg
driverNameColumn_F1 { label, getter } =
    let
        formatName name =
            String.split " " name
                |> List.reverse
                |> List.head
                |> Maybe.map String.toUpper
                |> Maybe.withDefault ""
    in
    { name = label
    , view = getter >> formatName >> text
    , sorter = compareBy getter
    , filter = \data query -> getter data |> String.startsWith query
    }


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
        formatName name =
            String.split " " name
                |> List.Extra.unconsLast
                |> Maybe.map (\( lastName, rest ) -> String.join "." (List.map (String.left 1) rest ++ [ String.toUpper lastName ]))
                |> Maybe.withDefault (String.toUpper name)
    in
    div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
        [ div [] [ text metadata.team ]
        , div [ css [ displayFlex, property "column-gap" "10px" ] ] <|
            List.map
                (\driver ->
                    let
                        isCurrentDriver =
                            Maybe.map .name currentDriver == Just driver.name
                    in
                    div
                        [ css
                            [ fontSize (px 10)
                            , fontStyle italic
                            , when (not isCurrentDriver)
                                (color (hsl 0 0 0.75))
                            ]
                        ]
                        [ text (formatName driver.name) ]
                )
                metadata.drivers
        ]


lastLapColumn_F1 :
    { getter : data -> { a | lastLapTime : Maybe Duration, bestLapTime : Maybe Duration }
    , sorter : data -> data -> Order
    , analysis : Analysis
    }
    -> Column data msg
lastLapColumn_F1 { getter, sorter, analysis } =
    { name = "Last Lap"
    , view =
        getter
            >> (\{ lastLapTime, bestLapTime } ->
                    Maybe.map2
                        (\time best ->
                            span
                                [ css
                                    [ let
                                        status =
                                            performanceLevel { time = time, personalBest = best, fastest = analysis.fastestLapTime }
                                      in
                                      if Performance.isStandard status then
                                        batch []

                                      else
                                        Performance.toColorVariable status
                                            |> property "color"
                                    ]
                                ]
                                [ text (Duration.toString time) ]
                        )
                        lastLapTime
                        bestLapTime
                        |> Maybe.withDefault (text "-")
               )
    , sorter = sorter
    , filter = \_ _ -> True
    }


currentLapColumn_Wec :
    { getter :
        data
        ->
            { a
                | status : Status
                , currentLapElapsed : Duration
                , currentLapBest : Maybe Duration
                , currentLapSectors : Maybe SectorTimes
                , sector : Maybe SectorProgress
            }
    , sorter : data -> data -> Order
    , analysis : Analysis
    }
    -> Column data msg
currentLapColumn_Wec { getter, sorter, analysis } =
    { name = "Current Lap"
    , view = getter >> Lazy.lazy2 viewCurrentLapColumn_Wec analysis
    , sorter = sorter
    , filter = \_ _ -> True
    }


viewCurrentLapColumn_Wec :
    Analysis
    ->
        { a
            | status : Status
            , currentLapElapsed : Duration
            , currentLapBest : Maybe Duration
            , currentLapSectors : Maybe SectorTimes
            , sector : Maybe SectorProgress
        }
    -> Html msg
viewCurrentLapColumn_Wec analysis { status, currentLapElapsed, currentLapBest, currentLapSectors, sector } =
    let
        lapTime { time, personalBest } =
            div
                [ css
                    [ textAlign center
                    , let
                        status_ =
                            performanceLevel { time = time, personalBest = personalBest, fastest = analysis.fastestLapTime }
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
                        if sector_.progress < 100 then
                            [ width (pct sector_.progress)
                            , backgroundColor (oklch 1 0 0)
                            ]

                        else
                            [ width (pct 100)
                            , property "background-color"
                                (performanceLevel sector_
                                    |> Performance.toColorVariable
                                )
                            ]
                    ]
                ]
                []
    in
    if Car.hasRetired status then
        div [ css [ textAlign center ] ] [ text "Retired" ]

    else
        Maybe.map2
            (\best { sector_1, sector_2, sector_3, s1_best, s2_best, s3_best } ->
                div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                    [ lapTime { time = currentLapElapsed, personalBest = best }
                    , let
                        ( s1_progress, s2_progress, s3_progress ) =
                            case sector of
                                Just sectorProgress ->
                                    case sectorProgress.sector of
                                        S1 ->
                                            ( sectorProgress.progress, 0, 0 )

                                        S2 ->
                                            ( 100, sectorProgress.progress, 0 )

                                        S3 ->
                                            ( 100, 100, sectorProgress.progress )

                                Nothing ->
                                    ( 100, 100, 100 )
                      in
                      div
                        [ css
                            [ property "display" "grid"
                            , property "grid-template-columns" "1fr 1fr 1fr"
                            , property "column-gap" "4px"
                            ]
                        ]
                        [ sectorCell { time = sector_1, personalBest = s1_best, fastest = analysis.sector_1_fastest, progress = s1_progress }
                        , sectorCell { time = sector_2, personalBest = s2_best, fastest = analysis.sector_2_fastest, progress = s2_progress }
                        , sectorCell { time = sector_3, personalBest = s3_best, fastest = analysis.sector_3_fastest, progress = s3_progress }
                        ]
                    ]
            )
            currentLapBest
            currentLapSectors
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
    , analysis : Analysis
    }
    -> Column data msg
currentLapColumn_LeMans24h { getter, sorter, analysis } =
    { name = "Current Lap"
    , view = getter >> Lazy.lazy2 viewCurrentLapColumn_LeMans24h analysis
    , sorter = sorter
    , filter = \_ _ -> True
    }


viewCurrentLapColumn_LeMans24h :
    Analysis
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
viewCurrentLapColumn_LeMans24h analysis { status, currentLapElapsed, currentLapBest, currentLapMiniSectors, miniSector } =
    let
        lapTime { time, personalBest } =
            div
                [ css
                    [ textAlign center
                    , let
                        status_ =
                            performanceLevel { time = time, personalBest = personalBest, fastest = analysis.fastestLapTime }
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
    if Car.hasRetired status then
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
                            [ sectorCell { time = Maybe.andThen (.scl2 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.scl2 >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.scl2, progress = progressMap.scl2 }
                            , sectorCell { time = Maybe.andThen (.z4 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.z4 >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.z4, progress = progressMap.z4 }
                            , sectorCell { time = Maybe.andThen (.ip1 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.ip1 >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.ip1, progress = progressMap.ip1 }
                            , div [] [] -- spacer
                            , sectorCell { time = Maybe.andThen (.z12 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.z12 >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.z12, progress = progressMap.z12 }
                            , sectorCell { time = Maybe.andThen (.sclc >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.sclc >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.sclc, progress = progressMap.sclc }
                            , sectorCell { time = Maybe.andThen (.a7_1 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.a7_1 >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.a7_1, progress = progressMap.a7_1 }
                            , sectorCell { time = Maybe.andThen (.ip2 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.ip2 >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.ip2, progress = progressMap.ip2 }
                            , div [] [] -- spacer
                            , sectorCell { time = Maybe.andThen (.a8_1 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.a8_1 >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.a8_1, progress = progressMap.a8_1 }
                            , sectorCell { time = Maybe.andThen (.sclb >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.sclb >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.sclb, progress = progressMap.sclb }
                            , sectorCell { time = Maybe.andThen (.porin >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.porin >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.porin, progress = progressMap.porin }
                            , sectorCell { time = Maybe.andThen (.porout >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.porout >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.porout, progress = progressMap.porout }
                            , sectorCell { time = Maybe.andThen (.pitref >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.pitref >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.pitref, progress = progressMap.pitref }
                            , sectorCell { time = Maybe.andThen (.scl1 >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.scl1 >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.scl1, progress = progressMap.scl1 }
                            , sectorCell { time = Maybe.andThen (.fordout >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.fordout >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.fordout, progress = progressMap.fordout }
                            , sectorCell { time = Maybe.andThen (.fl >> .time) currentLapMiniSectors, personalBest = Maybe.andThen (.fl >> .best) currentLapMiniSectors, fastest = analysis.miniSectorFastest.fl, progress = progressMap.fl }
                            ]
                        ]
                )
            |> Maybe.withDefault (text "-")


lastLapColumn_Wec :
    { getter : data -> { a | lastLapTime : Maybe Duration, bestLapTime : Maybe Duration, lastLapSectors : Maybe SectorTimes }
    , sorter : data -> data -> Order
    , analysis : Analysis
    }
    -> Column data msg
lastLapColumn_Wec { getter, sorter, analysis } =
    { name = "Last Lap"
    , view = getter >> Lazy.lazy2 viewLastLapColumn_Wec analysis
    , sorter = sorter
    , filter = \_ _ -> True
    }


viewLastLapColumn_Wec : Analysis -> { a | lastLapTime : Maybe Duration, bestLapTime : Maybe Duration, lastLapSectors : Maybe SectorTimes } -> Html msg
viewLastLapColumn_Wec analysis { lastLapTime, bestLapTime, lastLapSectors } =
    let
        lapTime { time, personalBest } =
            div
                [ css
                    [ textAlign center
                    , let
                        status =
                            performanceLevel { time = time, personalBest = personalBest, fastest = analysis.fastestLapTime }
                      in
                      if Performance.isStandard status then
                        batch []

                      else
                        Performance.toColorVariable status
                            |> property "color"
                    ]
                ]
                [ text (Duration.toString time) ]

        sectorCell sector_ =
            div
                [ css
                    [ height (px 3)
                    , borderRadius (px 1)
                    , property "background-color"
                        (performanceLevel sector_
                            |> Performance.toColorVariable
                        )
                    ]
                ]
                []
    in
    case Maybe.map2 Tuple.pair lastLapTime bestLapTime of
        Just ( time, best ) ->
            div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                [ lapTime { time = time, personalBest = best }
                , case lastLapSectors of
                    Just { sector_1, sector_2, sector_3, s1_best, s2_best, s3_best } ->
                        div
                            [ css
                                [ property "display" "grid"
                                , property "grid-template-columns" "1fr 1fr 1fr"
                                , property "column-gap" "4px"
                                ]
                            ]
                            [ sectorCell { time = sector_1, personalBest = s1_best, fastest = analysis.sector_1_fastest }
                            , sectorCell { time = sector_2, personalBest = s2_best, fastest = analysis.sector_2_fastest }
                            , sectorCell { time = sector_3, personalBest = s3_best, fastest = analysis.sector_3_fastest }
                            ]

                    Nothing ->
                        text ""
                ]

        Nothing ->
            text "-"


lastLapColumn_LeMans24h :
    { getter : data -> { a | lastLapTime : Maybe Duration, bestLapTime : Maybe Duration, lastLapMiniSectors : Maybe MiniSectors }
    , sorter : data -> data -> Order
    , analysis : Analysis
    }
    -> Column data msg
lastLapColumn_LeMans24h { getter, sorter, analysis } =
    { name = "Last Lap"
    , view = getter >> Lazy.lazy2 viewLastLapColumn_LeMans24h analysis
    , sorter = sorter
    , filter = \_ _ -> True
    }


viewLastLapColumn_LeMans24h : Analysis -> { a | lastLapTime : Maybe Duration, bestLapTime : Maybe Duration, lastLapMiniSectors : Maybe MiniSectors } -> Html msg
viewLastLapColumn_LeMans24h analysis { lastLapTime, bestLapTime, lastLapMiniSectors } =
    let
        lapTime { time, personalBest } =
            div
                [ css
                    [ textAlign center
                    , let
                        status =
                            performanceLevel { time = time, personalBest = personalBest, fastest = analysis.fastestLapTime }
                      in
                      if Performance.isStandard status then
                        batch []

                      else
                        Performance.toColorVariable status
                            |> property "color"
                    ]
                ]
                [ text (Duration.toString time) ]

        sectorCell sector_ =
            div
                [ css
                    [ height (px 3)
                    , borderRadius (px 1)
                    , property "background-color"
                        (performanceLevel { time = Maybe.withDefault 1000000 sector_.time, personalBest = Maybe.withDefault 1000000 sector_.personalBest, fastest = sector_.fastest }
                            |> Performance.toColorVariable
                        )
                    ]
                ]
                []
    in
    case Maybe.map2 Tuple.pair lastLapTime bestLapTime of
        Just ( time, best ) ->
            div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                [ lapTime { time = time, personalBest = best }
                , lastLapMiniSectors
                    |> Maybe.map
                        (\miniSectors_ ->
                            div [ css [ property "display" "grid", property "grid-template-columns" "2fr 2fr 3fr 0.5fr 5fr 1fr 3fr 3fr 0.5fr 1fr 5fr 3fr 2fr 1fr 1fr 1fr 1fr", property "column-gap" "1px" ] ]
                                [ sectorCell { time = miniSectors_.scl2.time, personalBest = miniSectors_.scl2.best, fastest = analysis.miniSectorFastest.scl2 }
                                , sectorCell { time = miniSectors_.z4.time, personalBest = miniSectors_.z4.best, fastest = analysis.miniSectorFastest.z4 }
                                , sectorCell { time = miniSectors_.ip1.time, personalBest = miniSectors_.ip1.best, fastest = analysis.miniSectorFastest.ip1 }
                                , div [] [] -- spacer
                                , sectorCell { time = miniSectors_.z12.time, personalBest = miniSectors_.z12.best, fastest = analysis.miniSectorFastest.z12 }
                                , sectorCell { time = miniSectors_.sclc.time, personalBest = miniSectors_.sclc.best, fastest = analysis.miniSectorFastest.sclc }
                                , sectorCell { time = miniSectors_.a7_1.time, personalBest = miniSectors_.a7_1.best, fastest = analysis.miniSectorFastest.a7_1 }
                                , sectorCell { time = miniSectors_.ip2.time, personalBest = miniSectors_.ip2.best, fastest = analysis.miniSectorFastest.ip2 }
                                , div [] [] -- spacer
                                , sectorCell { time = miniSectors_.a8_1.time, personalBest = miniSectors_.a8_1.best, fastest = analysis.miniSectorFastest.a8_1 }
                                , sectorCell { time = miniSectors_.sclb.time, personalBest = miniSectors_.sclb.best, fastest = analysis.miniSectorFastest.sclb }
                                , sectorCell { time = miniSectors_.porin.time, personalBest = miniSectors_.porin.best, fastest = analysis.miniSectorFastest.porin }
                                , sectorCell { time = miniSectors_.porout.time, personalBest = miniSectors_.porout.best, fastest = analysis.miniSectorFastest.porout }
                                , sectorCell { time = miniSectors_.pitref.time, personalBest = miniSectors_.pitref.best, fastest = analysis.miniSectorFastest.pitref }
                                , sectorCell { time = miniSectors_.scl1.time, personalBest = miniSectors_.scl1.best, fastest = analysis.miniSectorFastest.scl1 }
                                , sectorCell { time = miniSectors_.fordout.time, personalBest = miniSectors_.fordout.best, fastest = analysis.miniSectorFastest.fordout }
                                , sectorCell { time = miniSectors_.fl.time, personalBest = miniSectors_.fl.best, fastest = analysis.miniSectorFastest.fl }
                                ]
                        )
                    |> Maybe.withDefault (text "-")
                ]

        Nothing ->
            text "-"



-- VIEW


view : Config StandingsEntry msg -> Model -> Standings -> Html msg
view config state standings =
    DataView.view config state (Standings.toList standings)



-- VIEW


performanceHistory : { a | fastestLapTime : Duration } -> List Lap -> Html msg
performanceHistory analysis laps =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "repeat(7, auto)"
            ]
        ]
        [ Lazy.lazy2 performanceHistory_ analysis laps ]


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
