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
import Html.Styled exposing (Html, div, span, text)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Lazy as Lazy
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Car as Car exposing (Status(..))
import Motorsport.Chart.Histogram as Histogram
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap, MiniSector(..), Sector(..))
import Motorsport.Lap.Performance as Performance exposing (performanceLevel)
import Motorsport.RaceControl.ViewModel exposing (Timing, ViewModel, ViewModelItem)
import Motorsport.Utils exposing (compareBy)
import SortedList



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


carNumberColumn_Wec : Int -> { getter : data -> { a | carNumber : String, class : Class } } -> Column data msg
carNumberColumn_Wec season { getter } =
    { name = "#"
    , view = getter >> Lazy.lazy2 viewCarNumberColumn_Wec season
    , sorter = compareBy (getter >> .class >> Class.toString)
    , filter = \data query -> getter data |> .carNumber |> String.startsWith query
    }


viewCarNumberColumn_Wec : Int -> { a | carNumber : String, class : Class } -> Html msg
viewCarNumberColumn_Wec season { carNumber, class } =
    div
        [ css
            [ width (em 2.5)
            , property "padding-block" "5px"
            , textAlign center
            , fontSize (px 14)
            , fontWeight bold
            , backgroundColor (Class.toHexColor season class)
            , borderRadius (px 5)
            ]
        ]
        [ text carNumber ]


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
    { getter : data -> Maybe Lap
    , sorter : data -> data -> Order
    , analysis : Analysis
    }
    -> Column data msg
lastLapColumn_F1 { getter, sorter, analysis } =
    { name = "Last Lap"
    , view =
        getter
            >> Maybe.map
                (\{ time, best } ->
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
            >> Maybe.withDefault (text "-")
    , sorter = sorter
    , filter = \_ _ -> True
    }


currentLapColumn_Wec :
    { getter : data -> { a | status : Status, timing : Timing, currentLap : Maybe Lap }
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


viewCurrentLapColumn_Wec : Analysis -> { a | status : Status, timing : Timing, currentLap : Maybe Lap } -> Html msg
viewCurrentLapColumn_Wec analysis { status, timing, currentLap } =
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

        sector sector_ =
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
        currentLap
            |> Maybe.map
                (\{ best, sector_1, sector_2, sector_3, s1_best, s2_best, s3_best } ->
                    div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                        [ lapTime { time = timing.time, personalBest = best }
                        , let
                            ( s1_progress, s2_progress, s3_progress ) =
                                case timing.sector of
                                    Just ( S1, progress ) ->
                                        ( progress, 0, 0 )

                                    Just ( S2, progress ) ->
                                        ( 100, progress, 0 )

                                    Just ( S3, progress ) ->
                                        ( 100, 100, progress )

                                    _ ->
                                        ( 100, 100, 100 )
                          in
                          div
                            [ css
                                [ property "display" "grid"
                                , property "grid-template-columns" "1fr 1fr 1fr"
                                , property "column-gap" "4px"
                                ]
                            ]
                            [ sector { time = sector_1, personalBest = s1_best, fastest = analysis.sector_1_fastest, progress = s1_progress }
                            , sector { time = sector_2, personalBest = s2_best, fastest = analysis.sector_2_fastest, progress = s2_progress }
                            , sector { time = sector_3, personalBest = s3_best, fastest = analysis.sector_3_fastest, progress = s3_progress }
                            ]
                        ]
                )
            |> Maybe.withDefault (text "-")


currentLapColumn_LeMans24h :
    { getter : data -> { a | status : Status, timing : Timing, currentLap : Maybe Lap }
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


viewCurrentLapColumn_LeMans24h : Analysis -> { a | status : Status, timing : Timing, currentLap : Maybe Lap } -> Html msg
viewCurrentLapColumn_LeMans24h analysis { status, timing, currentLap } =
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

        sector sector_ =
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
        currentLap
            |> Maybe.map
                (\{ best, miniSectors } ->
                    div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                        [ lapTime { time = timing.time, personalBest = best }
                        , let
                            { scl2_progress, z4_progress, ip1_progress, z12_progress, sclc_progress, a7_1_progress, ip2_progress, a8_1_progress, sclb_progress, porin_progress, porout_progress, pitref_progress, scl1_progress, fordout_progress, fl_progress } =
                                case timing.miniSector of
                                    Just ( SCL2, progress ) ->
                                        { scl2_progress = progress, z4_progress = 0, ip1_progress = 0, z12_progress = 0, sclc_progress = 0, a7_1_progress = 0, ip2_progress = 0, a8_1_progress = 0, sclb_progress = 0, porin_progress = 0, porout_progress = 0, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( Z4, progress ) ->
                                        { scl2_progress = 1, z4_progress = progress, ip1_progress = 0, z12_progress = 0, sclc_progress = 0, a7_1_progress = 0, ip2_progress = 0, a8_1_progress = 0, sclb_progress = 0, porin_progress = 0, porout_progress = 0, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( IP1, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = progress, z12_progress = 0, sclc_progress = 0, a7_1_progress = 0, ip2_progress = 0, a8_1_progress = 0, sclb_progress = 0, porin_progress = 0, porout_progress = 0, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( Z12, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = progress, sclc_progress = 0, a7_1_progress = 0, ip2_progress = 0, a8_1_progress = 0, sclb_progress = 0, porin_progress = 0, porout_progress = 0, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( SCLC, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = 1, sclc_progress = progress, a7_1_progress = 0, ip2_progress = 0, a8_1_progress = 0, sclb_progress = 0, porin_progress = 0, porout_progress = 0, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( A7_1, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = 1, sclc_progress = 1, a7_1_progress = progress, ip2_progress = 0, a8_1_progress = 0, sclb_progress = 0, porin_progress = 0, porout_progress = 0, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( IP2, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = 1, sclc_progress = 1, a7_1_progress = 1, ip2_progress = progress, a8_1_progress = 0, sclb_progress = 0, porin_progress = 0, porout_progress = 0, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( A8_1, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = 1, sclc_progress = 1, a7_1_progress = 1, ip2_progress = 1, a8_1_progress = progress, sclb_progress = 0, porin_progress = 0, porout_progress = 0, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( SCLB, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = 1, sclc_progress = 1, a7_1_progress = 1, ip2_progress = 1, a8_1_progress = 1, sclb_progress = progress, porin_progress = 0, porout_progress = 0, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( PORIN, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = 1, sclc_progress = 1, a7_1_progress = 1, ip2_progress = 1, a8_1_progress = 1, sclb_progress = 1, porin_progress = progress, porout_progress = 0, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( POROUT, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = 1, sclc_progress = 1, a7_1_progress = 1, ip2_progress = 1, a8_1_progress = 1, sclb_progress = 1, porin_progress = 1, porout_progress = progress, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( PITREF, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = 1, sclc_progress = 1, a7_1_progress = 1, ip2_progress = 1, a8_1_progress = 1, sclb_progress = 1, porin_progress = 1, porout_progress = 1, pitref_progress = progress, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }

                                    Just ( SCL1, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = 1, sclc_progress = 1, a7_1_progress = 1, ip2_progress = 1, a8_1_progress = 1, sclb_progress = 1, porin_progress = 1, porout_progress = 1, pitref_progress = 1, scl1_progress = progress, fordout_progress = 0, fl_progress = 0 }

                                    Just ( FORDOUT, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = 1, sclc_progress = 1, a7_1_progress = 1, ip2_progress = 1, a8_1_progress = 1, sclb_progress = 1, porin_progress = 1, porout_progress = 1, pitref_progress = 1, scl1_progress = 1, fordout_progress = progress, fl_progress = 0 }

                                    Just ( FL, progress ) ->
                                        { scl2_progress = 1, z4_progress = 1, ip1_progress = 1, z12_progress = 1, sclc_progress = 1, a7_1_progress = 1, ip2_progress = 1, a8_1_progress = 1, sclb_progress = 1, porin_progress = 1, porout_progress = 1, pitref_progress = 1, scl1_progress = 1, fordout_progress = 1, fl_progress = progress }

                                    _ ->
                                        { scl2_progress = 0, z4_progress = 0, ip1_progress = 0, z12_progress = 0, sclc_progress = 0, a7_1_progress = 0, ip2_progress = 0, a8_1_progress = 0, sclb_progress = 0, porin_progress = 0, porout_progress = 0, pitref_progress = 0, scl1_progress = 0, fordout_progress = 0, fl_progress = 0 }
                          in
                          div [ css [ property "display" "grid", property "grid-template-columns" "2fr 2fr 3fr 0.5fr 5fr 1fr 3fr 3fr 0.5fr 1fr 5fr 3fr 2fr 1fr 1fr 1fr 1fr", property "column-gap" "1px" ] ]
                            [ sector { time = Maybe.andThen (.scl2 >> .time) miniSectors, personalBest = Maybe.andThen (.scl2 >> .best) miniSectors, fastest = analysis.miniSectorFastest.scl2, progress = scl2_progress }
                            , sector { time = Maybe.andThen (.z4 >> .time) miniSectors, personalBest = Maybe.andThen (.z4 >> .best) miniSectors, fastest = analysis.miniSectorFastest.z4, progress = z4_progress }
                            , sector { time = Maybe.andThen (.ip1 >> .time) miniSectors, personalBest = Maybe.andThen (.ip1 >> .best) miniSectors, fastest = analysis.miniSectorFastest.ip1, progress = ip1_progress }
                            , div [] [] -- spacer
                            , sector { time = Maybe.andThen (.z12 >> .time) miniSectors, personalBest = Maybe.andThen (.z12 >> .best) miniSectors, fastest = analysis.miniSectorFastest.z12, progress = z12_progress }
                            , sector { time = Maybe.andThen (.sclc >> .time) miniSectors, personalBest = Maybe.andThen (.sclc >> .best) miniSectors, fastest = analysis.miniSectorFastest.sclc, progress = sclc_progress }
                            , sector { time = Maybe.andThen (.a7_1 >> .time) miniSectors, personalBest = Maybe.andThen (.a7_1 >> .best) miniSectors, fastest = analysis.miniSectorFastest.a7_1, progress = a7_1_progress }
                            , sector { time = Maybe.andThen (.ip2 >> .time) miniSectors, personalBest = Maybe.andThen (.ip2 >> .best) miniSectors, fastest = analysis.miniSectorFastest.ip2, progress = ip2_progress }
                            , div [] [] -- spacer
                            , sector { time = Maybe.andThen (.a8_1 >> .time) miniSectors, personalBest = Maybe.andThen (.a8_1 >> .best) miniSectors, fastest = analysis.miniSectorFastest.a8_1, progress = a8_1_progress }
                            , sector { time = Maybe.andThen (.sclb >> .time) miniSectors, personalBest = Maybe.andThen (.sclb >> .best) miniSectors, fastest = analysis.miniSectorFastest.sclb, progress = sclb_progress }
                            , sector { time = Maybe.andThen (.porin >> .time) miniSectors, personalBest = Maybe.andThen (.porin >> .best) miniSectors, fastest = analysis.miniSectorFastest.porin, progress = porin_progress }
                            , sector { time = Maybe.andThen (.porout >> .time) miniSectors, personalBest = Maybe.andThen (.porout >> .best) miniSectors, fastest = analysis.miniSectorFastest.porout, progress = porout_progress }
                            , sector { time = Maybe.andThen (.pitref >> .time) miniSectors, personalBest = Maybe.andThen (.pitref >> .best) miniSectors, fastest = analysis.miniSectorFastest.pitref, progress = pitref_progress }
                            , sector { time = Maybe.andThen (.scl1 >> .time) miniSectors, personalBest = Maybe.andThen (.scl1 >> .best) miniSectors, fastest = analysis.miniSectorFastest.scl1, progress = scl1_progress }
                            , sector { time = Maybe.andThen (.fordout >> .time) miniSectors, personalBest = Maybe.andThen (.fordout >> .best) miniSectors, fastest = analysis.miniSectorFastest.fordout, progress = fordout_progress }
                            , sector { time = Maybe.andThen (.fl >> .time) miniSectors, personalBest = Maybe.andThen (.fl >> .best) miniSectors, fastest = analysis.miniSectorFastest.fl, progress = fl_progress }
                            ]
                        ]
                )
            |> Maybe.withDefault (text "-")


lastLapColumn_Wec :
    { getter : data -> Maybe Lap
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


viewLastLapColumn_Wec : Analysis -> Maybe Lap -> Html msg
viewLastLapColumn_Wec analysis maybeLap =
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

        sector sector_ =
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
    case maybeLap of
        Just { time, best, sector_1, sector_2, sector_3, s1_best, s2_best, s3_best } ->
            div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                [ lapTime { time = time, personalBest = best }
                , div
                    [ css
                        [ property "display" "grid"
                        , property "grid-template-columns" "1fr 1fr 1fr"
                        , property "column-gap" "4px"
                        ]
                    ]
                    [ sector { time = sector_1, personalBest = s1_best, fastest = analysis.sector_1_fastest }
                    , sector { time = sector_2, personalBest = s2_best, fastest = analysis.sector_2_fastest }
                    , sector { time = sector_3, personalBest = s3_best, fastest = analysis.sector_3_fastest }
                    ]
                ]

        Nothing ->
            text "-"


lastLapColumn_LeMans24h :
    { getter : data -> Maybe Lap
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


viewLastLapColumn_LeMans24h : Analysis -> Maybe Lap -> Html msg
viewLastLapColumn_LeMans24h analysis maybeLap =
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

        sector sector_ =
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
    case maybeLap of
        Just { time, best, miniSectors } ->
            div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                [ lapTime { time = time, personalBest = best }
                , miniSectors
                    |> Maybe.map
                        (\miniSectors_ ->
                            div [ css [ property "display" "grid", property "grid-template-columns" "2fr 2fr 3fr 0.5fr 5fr 1fr 3fr 3fr 0.5fr 1fr 5fr 3fr 2fr 1fr 1fr 1fr 1fr", property "column-gap" "1px" ] ]
                                [ sector { time = miniSectors_.scl2.time, personalBest = miniSectors_.scl2.best, fastest = analysis.miniSectorFastest.scl2 }
                                , sector { time = miniSectors_.z4.time, personalBest = miniSectors_.z4.best, fastest = analysis.miniSectorFastest.z4 }
                                , sector { time = miniSectors_.ip1.time, personalBest = miniSectors_.ip1.best, fastest = analysis.miniSectorFastest.ip1 }
                                , div [] [] -- spacer
                                , sector { time = miniSectors_.z12.time, personalBest = miniSectors_.z12.best, fastest = analysis.miniSectorFastest.z12 }
                                , sector { time = miniSectors_.sclc.time, personalBest = miniSectors_.sclc.best, fastest = analysis.miniSectorFastest.sclc }
                                , sector { time = miniSectors_.a7_1.time, personalBest = miniSectors_.a7_1.best, fastest = analysis.miniSectorFastest.a7_1 }
                                , sector { time = miniSectors_.ip2.time, personalBest = miniSectors_.ip2.best, fastest = analysis.miniSectorFastest.ip2 }
                                , div [] [] -- spacer
                                , sector { time = miniSectors_.a8_1.time, personalBest = miniSectors_.a8_1.best, fastest = analysis.miniSectorFastest.a8_1 }
                                , sector { time = miniSectors_.sclb.time, personalBest = miniSectors_.sclb.best, fastest = analysis.miniSectorFastest.sclb }
                                , sector { time = miniSectors_.porin.time, personalBest = miniSectors_.porin.best, fastest = analysis.miniSectorFastest.porin }
                                , sector { time = miniSectors_.porout.time, personalBest = miniSectors_.porout.best, fastest = analysis.miniSectorFastest.porout }
                                , sector { time = miniSectors_.pitref.time, personalBest = miniSectors_.pitref.best, fastest = analysis.miniSectorFastest.pitref }
                                , sector { time = miniSectors_.scl1.time, personalBest = miniSectors_.scl1.best, fastest = analysis.miniSectorFastest.scl1 }
                                , sector { time = miniSectors_.fordout.time, personalBest = miniSectors_.fordout.best, fastest = analysis.miniSectorFastest.fordout }
                                , sector { time = miniSectors_.fl.time, personalBest = miniSectors_.fl.best, fastest = analysis.miniSectorFastest.fl }
                                ]
                        )
                    |> Maybe.withDefault (text "-")
                ]

        Nothing ->
            text "-"



-- VIEW


view : Config ViewModelItem msg -> Model -> ViewModel -> Html msg
view config state viewModel =
    DataView.view config state (SortedList.toList viewModel.items)



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
