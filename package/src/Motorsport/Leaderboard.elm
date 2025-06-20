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

-}

import Css exposing (..)
import Css.Extra exposing (when)
import DataView
import DataView.Options exposing (Options, PaginationOption(..), SelectingOption(..))
import Html.Styled exposing (Html, div, span, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap, MiniSector(..), Sector(..))
import Motorsport.LapStatus as LapStatus exposing (lapStatus)
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel exposing (Timing, ViewModelItem)
import Motorsport.Utils exposing (compareBy)
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg, g, rect, svg)
import Svg.Styled.Attributes as SvgAttributes
import TypedSvg.Styled.Attributes as TypedSvgAttributes
import TypedSvg.Styled.Attributes.InPx as InPx



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
    , getter : data -> Maybe { time : Duration, personalBest : Duration, overallBest : Duration, progress : Float }
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
                            , backgroundColor <|
                                if sector.progress < 100 then
                                    hsla 0 0 1 0.9

                                else
                                    lapStatus sector
                                        |> LapStatus.toHexColorString
                                        |> hex
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
    , view = getter >> histogram analysis coefficient
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
    , view =
        getter
            >> (\{ carNumber, class } ->
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
               )
    , sorter = compareBy (getter >> .class >> Class.toString)
    , filter = \data query -> getter data |> .carNumber |> String.startsWith query
    }


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


driverAndTeamColumn_Wec : { getter : data -> { a | drivers : List Driver, team : String } } -> Column data msg
driverAndTeamColumn_Wec { getter } =
    let
        formatName name =
            String.split " " name
                |> List.Extra.unconsLast
                |> Maybe.map (\( lastName, rest ) -> String.join "." (List.map (String.left 1) rest ++ [ String.toUpper lastName ]))
                |> Maybe.withDefault (String.toUpper name)
    in
    { name = "Team / Driver"
    , view =
        getter
            >> (\{ drivers, team } ->
                    div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                        [ div [] [ text team ]
                        , div [ css [ displayFlex, property "column-gap" "10px" ] ] <|
                            List.map
                                (\{ name, isCurrentDriver } ->
                                    div
                                        [ css
                                            [ fontSize (px 10)
                                            , fontStyle italic
                                            , when (not isCurrentDriver)
                                                (color (hsl 0 0 0.75))
                                            ]
                                        ]
                                        [ text (formatName name) ]
                                )
                                drivers
                        ]
               )
    , sorter = compareBy (getter >> .team)
    , filter = \data query -> getter data |> .team |> String.startsWith query
    }


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
                                    lapStatus { time = time, personalBest = best, overallBest = analysis.fastestLapTime }
                              in
                              if LapStatus.isNormal status then
                                batch []

                              else
                                LapStatus.toHexColorString status
                                    |> hex
                                    |> color
                            ]
                        ]
                        [ text (Duration.toString time) ]
                )
            >> Maybe.withDefault (text "-")
    , sorter = sorter
    , filter = \_ _ -> True
    }


currentLapColumn_Wec :
    { getter : data -> { a | timing : Timing, currentLap : Maybe Lap }
    , sorter : data -> data -> Order
    , analysis : Analysis
    }
    -> Column data msg
currentLapColumn_Wec { getter, sorter, analysis } =
    let
        lapTime { time, personalBest } =
            div
                [ css
                    [ textAlign center
                    , let
                        status =
                            lapStatus { time = time, personalBest = personalBest, overallBest = analysis.fastestLapTime }
                      in
                      if LapStatus.isNormal status then
                        batch []

                      else
                        LapStatus.toHexColorString status
                            |> hex
                            |> color
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
                            , backgroundColor (hsla 0 0 1 0.9)
                            ]

                        else
                            [ width (pct 100)
                            , backgroundColor
                                (lapStatus sector_
                                    |> LapStatus.toHexColorString
                                    |> hex
                                )
                            ]
                    ]
                ]
                []
    in
    { name = "Current Lap"
    , view =
        getter
            >> (\{ timing, currentLap } ->
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
                                        [ sector { time = sector_1, personalBest = s1_best, overallBest = analysis.sector_1_fastest, progress = s1_progress }
                                        , sector { time = sector_2, personalBest = s2_best, overallBest = analysis.sector_2_fastest, progress = s2_progress }
                                        , sector { time = sector_3, personalBest = s3_best, overallBest = analysis.sector_3_fastest, progress = s3_progress }
                                        ]
                                    ]
                            )
               )
            >> Maybe.withDefault (text "-")
    , sorter = sorter
    , filter = \_ _ -> True
    }


currentLapColumn_LeMans24h :
    { getter : data -> { a | timing : Timing, currentLap : Maybe Lap }
    , sorter : data -> data -> Order
    , analysis : Analysis
    }
    -> Column data msg
currentLapColumn_LeMans24h { getter, sorter, analysis } =
    let
        lapTime { time, personalBest } =
            div
                [ css
                    [ textAlign center
                    , let
                        status =
                            lapStatus { time = time, personalBest = personalBest, overallBest = analysis.fastestLapTime }
                      in
                      if LapStatus.isNormal status then
                        batch []

                      else
                        LapStatus.toHexColorString status
                            |> hex
                            |> color
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
                            , backgroundColor (hsla 0 0 1 0.9)
                            ]

                        else
                            [ width (pct 100)
                            , backgroundColor
                                (lapStatus { time = Maybe.withDefault 1000000 sector_.time, personalBest = Maybe.withDefault 1000000 sector_.personalBest, overallBest = sector_.overallBest }
                                    |> LapStatus.toHexColorString
                                    |> hex
                                )
                            ]
                    ]
                ]
                []
    in
    { name = "Current Lap"
    , view =
        getter
            >> (\{ timing, currentLap } ->
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
                                        [ sector { time = Maybe.andThen (.scl2 >> .time) miniSectors, personalBest = Maybe.andThen (.scl2 >> .best) miniSectors, overallBest = analysis.miniSectorFastest.scl2, progress = scl2_progress }
                                        , sector { time = Maybe.andThen (.z4 >> .time) miniSectors, personalBest = Maybe.andThen (.z4 >> .best) miniSectors, overallBest = analysis.miniSectorFastest.z4, progress = z4_progress }
                                        , sector { time = Maybe.andThen (.ip1 >> .time) miniSectors, personalBest = Maybe.andThen (.ip1 >> .best) miniSectors, overallBest = analysis.miniSectorFastest.ip1, progress = ip1_progress }
                                        , div [] [] -- spacer
                                        , sector { time = Maybe.andThen (.z12 >> .time) miniSectors, personalBest = Maybe.andThen (.z12 >> .best) miniSectors, overallBest = analysis.miniSectorFastest.z12, progress = z12_progress }
                                        , sector { time = Maybe.andThen (.sclc >> .time) miniSectors, personalBest = Maybe.andThen (.sclc >> .best) miniSectors, overallBest = analysis.miniSectorFastest.sclc, progress = sclc_progress }
                                        , sector { time = Maybe.andThen (.a7_1 >> .time) miniSectors, personalBest = Maybe.andThen (.a7_1 >> .best) miniSectors, overallBest = analysis.miniSectorFastest.a7_1, progress = a7_1_progress }
                                        , sector { time = Maybe.andThen (.ip2 >> .time) miniSectors, personalBest = Maybe.andThen (.ip2 >> .best) miniSectors, overallBest = analysis.miniSectorFastest.ip2, progress = ip2_progress }
                                        , div [] [] -- spacer
                                        , sector { time = Maybe.andThen (.a8_1 >> .time) miniSectors, personalBest = Maybe.andThen (.a8_1 >> .best) miniSectors, overallBest = analysis.miniSectorFastest.a8_1, progress = a8_1_progress }
                                        , sector { time = Maybe.andThen (.sclb >> .time) miniSectors, personalBest = Maybe.andThen (.sclb >> .best) miniSectors, overallBest = analysis.miniSectorFastest.sclb, progress = sclb_progress }
                                        , sector { time = Maybe.andThen (.porin >> .time) miniSectors, personalBest = Maybe.andThen (.porin >> .best) miniSectors, overallBest = analysis.miniSectorFastest.porin, progress = porin_progress }
                                        , sector { time = Maybe.andThen (.porout >> .time) miniSectors, personalBest = Maybe.andThen (.porout >> .best) miniSectors, overallBest = analysis.miniSectorFastest.porout, progress = porout_progress }
                                        , sector { time = Maybe.andThen (.pitref >> .time) miniSectors, personalBest = Maybe.andThen (.pitref >> .best) miniSectors, overallBest = analysis.miniSectorFastest.pitref, progress = pitref_progress }
                                        , sector { time = Maybe.andThen (.scl1 >> .time) miniSectors, personalBest = Maybe.andThen (.scl1 >> .best) miniSectors, overallBest = analysis.miniSectorFastest.scl1, progress = scl1_progress }
                                        , sector { time = Maybe.andThen (.fordout >> .time) miniSectors, personalBest = Maybe.andThen (.fordout >> .best) miniSectors, overallBest = analysis.miniSectorFastest.fordout, progress = fordout_progress }
                                        , sector { time = Maybe.andThen (.fl >> .time) miniSectors, personalBest = Maybe.andThen (.fl >> .best) miniSectors, overallBest = analysis.miniSectorFastest.fl, progress = fl_progress }
                                        ]
                                    ]
                            )
               )
            >> Maybe.withDefault (text "-")
    , sorter = sorter
    , filter = \_ _ -> True
    }


lastLapColumn_Wec :
    { getter : data -> Maybe Lap
    , sorter : data -> data -> Order
    , analysis : Analysis
    }
    -> Column data msg
lastLapColumn_Wec { getter, sorter, analysis } =
    let
        lapTime { time, personalBest } =
            div
                [ css
                    [ textAlign center
                    , let
                        status =
                            lapStatus { time = time, personalBest = personalBest, overallBest = analysis.fastestLapTime }
                      in
                      if LapStatus.isNormal status then
                        batch []

                      else
                        LapStatus.toHexColorString status
                            |> hex
                            |> color
                    ]
                ]
                [ text (Duration.toString time) ]

        sector sector_ =
            div
                [ css
                    [ height (px 3)
                    , borderRadius (px 1)
                    , lapStatus sector_
                        |> LapStatus.toHexColorString
                        |> (\c -> backgroundColor (hex c))
                    ]
                ]
                []
    in
    { name = "Last Lap"
    , view =
        getter
            >> Maybe.map
                (\{ time, best, sector_1, sector_2, sector_3, s1_best, s2_best, s3_best } ->
                    div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                        [ lapTime { time = time, personalBest = best }
                        , div
                            [ css
                                [ property "display" "grid"
                                , property "grid-template-columns" "1fr 1fr 1fr"
                                , property "column-gap" "4px"
                                ]
                            ]
                            [ sector { time = sector_1, personalBest = s1_best, overallBest = analysis.sector_1_fastest }
                            , sector { time = sector_2, personalBest = s2_best, overallBest = analysis.sector_2_fastest }
                            , sector { time = sector_3, personalBest = s3_best, overallBest = analysis.sector_3_fastest }
                            ]
                        ]
                )
            >> Maybe.withDefault (text "-")
    , sorter = sorter
    , filter = \_ _ -> True
    }


lastLapColumn_LeMans24h :
    { getter : data -> Maybe Lap
    , sorter : data -> data -> Order
    , analysis : Analysis
    }
    -> Column data msg
lastLapColumn_LeMans24h { getter, sorter, analysis } =
    let
        lapTime { time, personalBest } =
            div
                [ css
                    [ textAlign center
                    , let
                        status =
                            lapStatus { time = time, personalBest = personalBest, overallBest = analysis.fastestLapTime }
                      in
                      if LapStatus.isNormal status then
                        batch []

                      else
                        LapStatus.toHexColorString status
                            |> hex
                            |> color
                    ]
                ]
                [ text (Duration.toString time) ]

        sector sector_ =
            div
                [ css
                    [ height (px 3)
                    , borderRadius (px 1)
                    , backgroundColor
                        (lapStatus { time = Maybe.withDefault 1000000 sector_.time, personalBest = Maybe.withDefault 1000000 sector_.personalBest, overallBest = sector_.overallBest }
                            |> LapStatus.toHexColorString
                            |> hex
                        )
                    ]
                ]
                []
    in
    { name = "Last Lap"
    , view =
        getter
            >> Maybe.map
                (\{ time, best, miniSectors } ->
                    div [ css [ displayFlex, flexDirection column, property "row-gap" "5px" ] ]
                        [ lapTime { time = time, personalBest = best }
                        , miniSectors
                            |> Maybe.map
                                (\miniSectors_ ->
                                    div [ css [ property "display" "grid", property "grid-template-columns" "2fr 2fr 3fr 0.5fr 5fr 1fr 3fr 3fr 0.5fr 1fr 5fr 3fr 2fr 1fr 1fr 1fr 1fr", property "column-gap" "1px" ] ]
                                        [ sector { time = miniSectors_.scl2.time, personalBest = miniSectors_.scl2.best, overallBest = analysis.miniSectorFastest.scl2 }
                                        , sector { time = miniSectors_.z4.time, personalBest = miniSectors_.z4.best, overallBest = analysis.miniSectorFastest.z4 }
                                        , sector { time = miniSectors_.ip1.time, personalBest = miniSectors_.ip1.best, overallBest = analysis.miniSectorFastest.ip1 }
                                        , div [] [] -- spacer
                                        , sector { time = miniSectors_.z12.time, personalBest = miniSectors_.z12.best, overallBest = analysis.miniSectorFastest.z12 }
                                        , sector { time = miniSectors_.sclc.time, personalBest = miniSectors_.sclc.best, overallBest = analysis.miniSectorFastest.sclc }
                                        , sector { time = miniSectors_.a7_1.time, personalBest = miniSectors_.a7_1.best, overallBest = analysis.miniSectorFastest.a7_1 }
                                        , sector { time = miniSectors_.ip2.time, personalBest = miniSectors_.ip2.best, overallBest = analysis.miniSectorFastest.ip2 }
                                        , div [] [] -- spacer
                                        , sector { time = miniSectors_.a8_1.time, personalBest = miniSectors_.a8_1.best, overallBest = analysis.miniSectorFastest.a8_1 }
                                        , sector { time = miniSectors_.sclb.time, personalBest = miniSectors_.sclb.best, overallBest = analysis.miniSectorFastest.sclb }
                                        , sector { time = miniSectors_.porin.time, personalBest = miniSectors_.porin.best, overallBest = analysis.miniSectorFastest.porin }
                                        , sector { time = miniSectors_.porout.time, personalBest = miniSectors_.porout.best, overallBest = analysis.miniSectorFastest.porout }
                                        , sector { time = miniSectors_.pitref.time, personalBest = miniSectors_.pitref.best, overallBest = analysis.miniSectorFastest.pitref }
                                        , sector { time = miniSectors_.scl1.time, personalBest = miniSectors_.scl1.best, overallBest = analysis.miniSectorFastest.scl1 }
                                        , sector { time = miniSectors_.fordout.time, personalBest = miniSectors_.fordout.best, overallBest = analysis.miniSectorFastest.fordout }
                                        , sector { time = miniSectors_.fl.time, personalBest = miniSectors_.fl.best, overallBest = analysis.miniSectorFastest.fl }
                                        ]
                                )
                            |> Maybe.withDefault (text "-")
                        ]
                )
            >> Maybe.withDefault (text "-")
    , sorter = sorter
    , filter = \_ _ -> True
    }



-- VIEW


view : Config ViewModelItem msg -> Model -> RaceControl.Model -> Html msg
view config state raceControl =
    DataView.view config state (ViewModel.init raceControl)



-- VIEW


w : Float
w =
    200


h : Float
h =
    20


padding : Float
padding =
    1


xScale : ( Int, Float ) -> ContinuousScale Float
xScale ( min, max ) =
    ( toFloat min, max ) |> Scale.linear ( padding, w - padding )


yScale : ( Float, Float ) -> ContinuousScale Float
yScale ( min, max ) =
    ( min, max ) |> Scale.linear ( h - padding, padding )


histogram : Analysis -> Float -> List Lap -> Html msg
histogram { fastestLapTime, slowestLapTime } coefficient laps =
    let
        xScale_ =
            xScale ( fastestLapTime, min (toFloat fastestLapTime * coefficient) (toFloat slowestLapTime) )

        width lap =
            if isCurrentLap lap then
                3

            else
                1

        color lap =
            if isCurrentLap lap then
                lapStatus { time = lap.time, personalBest = lap.best, overallBest = fastestLapTime }
                    |> LapStatus.toHexColorString

            else
                "hsla(0, 0%, 100%, 0.2)"

        isCurrentLap { lap } =
            List.length laps == lap
    in
    svg [ TypedSvgAttributes.viewBox 0 0 w h, SvgAttributes.css [ Css.width (px 200) ] ]
        [ histogram_
            { x = .time >> toFloat >> Scale.convert xScale_
            , y = always 0 >> Scale.convert (yScale ( 0, 0 ))
            , width = width
            , color = color
            }
            laps
        ]


histogram_ :
    { x : a -> Float, y : a -> Float, width : a -> Float, color : a -> String }
    -> List a
    -> Svg msg
histogram_ { x, y, width, color } laps =
    g [] <|
        List.map
            (\lap ->
                rect
                    [ InPx.x (x lap - 1)
                    , InPx.y (y lap - 10)
                    , InPx.width (width lap)
                    , InPx.height 20
                    , SvgAttributes.fill (color lap)
                    ]
                    []
            )
            laps


performanceHistory : { a | fastestLapTime : Duration } -> List Lap -> Html msg
performanceHistory analysis laps =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "repeat(7, auto)"
            ]
        ]
        [ performanceHistory_ analysis laps ]


performanceHistory_ : { a | fastestLapTime : Duration } -> List Lap -> Html msg
performanceHistory_ { fastestLapTime } laps =
    let
        toCssColor { time, best } =
            lapStatus { time = time, personalBest = best, overallBest = fastestLapTime }
                |> LapStatus.toHexColorString
                |> hex
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


coloredCell : Color -> Html msg
coloredCell backgroundColor_ =
    div
        [ css
            [ width (pct 100)
            , height (pct 100)
            , borderRadius (pct 10)
            , backgroundColor backgroundColor_
            ]
        ]
        []
