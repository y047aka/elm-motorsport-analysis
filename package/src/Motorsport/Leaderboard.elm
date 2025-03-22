module Motorsport.Leaderboard exposing
    ( stringColumn, intColumn, floatColumn
    , Model, initialSort
    , Msg, update
    , customColumn, veryCustomColumn
    , sectorTimeColumn, bestTimeColumn
    , histogramColumn, performanceColumn
    , carNumberColumn_Wec
    , driverNameColumn_F1, driverAndTeamColumn_Wec
    , currentLapColumn_Wec
    , lastLapColumn_F1, lastLapColumn_Wec
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
@docs currentLapColumn_Wec
@docs lastLapColumn_F1, currentLapColumn_Wec, lastLapColumn_Wec

-}

import Css exposing (..)
import Css.Extra exposing (when)
import Html.Styled exposing (Html, div, span, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.LapStatus as LapStatus exposing (lapStatus)
import Motorsport.Leaderboard.Internal exposing (Column, Config, Msg)
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
    Motorsport.Leaderboard.Internal.Model


initialSort : String -> Model
initialSort =
    Motorsport.Leaderboard.Internal.init



-- UPDATE


type alias Msg =
    Motorsport.Leaderboard.Internal.Msg


update : Msg -> Model -> Model
update =
    Motorsport.Leaderboard.Internal.update


type alias Config data msg =
    Motorsport.Leaderboard.Internal.Config data msg



-- COLUMNS


{-| -}
stringColumn : { label : String, getter : data -> String } -> Column data msg
stringColumn =
    Motorsport.Leaderboard.Internal.stringColumn


{-| -}
intColumn : { label : String, getter : data -> Int } -> Column data msg
intColumn =
    Motorsport.Leaderboard.Internal.intColumn


{-| -}
floatColumn : { label : String, getter : data -> Float } -> Column data msg
floatColumn =
    Motorsport.Leaderboard.Internal.floatColumn


{-| -}
customColumn :
    { label : String
    , getter : data -> String
    , sorter : data -> data -> Order
    }
    -> Column data msg
customColumn =
    Motorsport.Leaderboard.Internal.customColumn


{-| -}
veryCustomColumn :
    { label : String
    , getter : data -> Html msg
    , sorter : data -> data -> Order
    }
    -> Column data msg
veryCustomColumn =
    Motorsport.Leaderboard.Internal.veryCustomColumn


sectorTimeColumn :
    { label : String
    , getter : data -> Maybe { time : Duration, personalBest : Duration, overallBest : Duration, inProgress : Bool }
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
                                if sector.inProgress then
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
    }


bestTimeColumn : { getter : data -> Maybe Duration } -> Column data msg
bestTimeColumn { getter } =
    Motorsport.Leaderboard.Internal.customColumn
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
                    , backgroundColor <|
                        if sector_.inProgress then
                            hsla 0 0 1 0.9

                        else
                            lapStatus sector_
                                |> LapStatus.toHexColorString
                                |> hex
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
                                    , div
                                        [ css
                                            [ property "display" "grid"
                                            , property "grid-template-columns" "1fr 1fr 1fr"
                                            , property "column-gap" "4px"
                                            ]
                                        ]
                                        [ timing.sector_1
                                            |> Maybe.map (\{ inProgress } -> sector { time = sector_1, personalBest = s1_best, overallBest = analysis.sector_1_fastest, inProgress = inProgress })
                                            |> Maybe.withDefault (text "")
                                        , timing.sector_2
                                            |> Maybe.map (\{ inProgress } -> sector { time = sector_2, personalBest = s2_best, overallBest = analysis.sector_2_fastest, inProgress = inProgress })
                                            |> Maybe.withDefault (text "")
                                        , timing.sector_3
                                            |> Maybe.map (\{ inProgress } -> sector { time = sector_3, personalBest = s3_best, overallBest = analysis.sector_3_fastest, inProgress = inProgress })
                                            |> Maybe.withDefault (text "")
                                        ]
                                    ]
                            )
               )
            >> Maybe.withDefault (text "-")
    , sorter = sorter
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
    }



-- VIEW


view : Config ViewModelItem msg -> Model -> RaceControl.Model -> Html msg
view config state raceControl =
    Motorsport.Leaderboard.Internal.table config state (ViewModel.init raceControl)



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
