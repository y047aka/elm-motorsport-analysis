module Motorsport.Leaderboard exposing
    ( stringColumn, intColumn, floatColumn
    , Model, initialSort
    , Msg, update
    , customColumn, veryCustomColumn
    , sectorTimeColumn, bestTimeColumn
    , histogramColumn, performanceColumn
    , carNumberColumn_Wec
    , driverNameColumn_F1, driverAndTeamColumn_Wec
    , lastLapColumn_F1, lastLapColumn_Wec
    , Config, Leaderboard, LeaderboardItem, init, view
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
@docs lastLapColumn_F1, lastLapColumn_Wec

-}

import Css exposing (..)
import Css.Extra exposing (when)
import Html.Styled as Html exposing (Html, div, span, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Clock as Clock
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap(..))
import Motorsport.Lap as Lap exposing (Lap, Sector(..), completedLapsAt)
import Motorsport.LapStatus as LapStatus exposing (lapStatus)
import Motorsport.Leaderboard.Internal exposing (Column, Config, Msg)
import Motorsport.RaceControl as RaceControl
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
    , sorter : List data -> List data
    }
    -> Column data msg
customColumn =
    Motorsport.Leaderboard.Internal.customColumn


{-| -}
veryCustomColumn :
    { label : String
    , getter : data -> Html msg
    , sorter : List data -> List data
    }
    -> Column data msg
veryCustomColumn =
    Motorsport.Leaderboard.Internal.veryCustomColumn


sectorTimeColumn :
    { label : String
    , getter : data -> Maybe { time : Duration, personalBest : Duration, overallBest : Duration }
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
                            , lapStatus sector
                                |> LapStatus.toHexColorString
                                |> (\c -> backgroundColor (hex c))
                            ]
                        ]
                        []
                )
            >> Maybe.withDefault (text "")
    , sorter = List.sortBy (getter >> Maybe.map .time >> Maybe.withDefault 0)
    }


bestTimeColumn : { getter : data -> Maybe Duration } -> Column data msg
bestTimeColumn { getter } =
    Motorsport.Leaderboard.Internal.customColumn
        { label = "Best"
        , getter = getter >> Maybe.map Duration.toString >> Maybe.withDefault "-"
        , sorter = List.sortBy (getter >> Maybe.withDefault 0)
        }


histogramColumn :
    { getter : data -> List Lap
    , sorter : List data -> List data
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
    , sorter : List data -> List data
    , analysis : Analysis
    }
    -> Column data msg
performanceColumn { getter, sorter, analysis } =
    { name = "Performance"
    , view = getter >> performanceHistory analysis
    , sorter = sorter
    }


carNumberColumn_Wec : { carNumber : data -> String, class : data -> Class } -> Column data msg
carNumberColumn_Wec { carNumber, class } =
    { name = "#"
    , view =
        \data ->
            div
                [ css
                    [ width (em 2.5)
                    , property "padding-block" "5px"
                    , textAlign center
                    , fontSize (px 14)
                    , fontWeight bold
                    , backgroundColor (class data |> Class.toHexColor)
                    , borderRadius (px 5)
                    ]
                ]
                [ text (carNumber data) ]
    , sorter = List.sortBy (class >> Class.toString)
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
    , sorter = List.sortBy getter
    }


driverAndTeamColumn_Wec : Column { a | drivers : List Driver, team : String } msg
driverAndTeamColumn_Wec =
    let
        formatName name =
            String.split " " name
                |> List.Extra.unconsLast
                |> Maybe.map (\( lastName, rest ) -> String.join "." (List.map (String.left 1) rest ++ [ String.toUpper lastName ]))
                |> Maybe.withDefault (String.toUpper name)
    in
    { name = "Team / Driver"
    , view =
        \{ drivers, team } ->
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
    , sorter = List.sortBy .team
    }


lastLapColumn_F1 :
    { getter : data -> Maybe Lap
    , sorter : List data -> List data
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


lastLapColumn_Wec :
    { getter : data -> Maybe Lap
    , sorter : List data -> List data
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


view : Config LeaderboardItem msg -> Model -> RaceControl.Model -> Html msg
view config state raceControl =
    Motorsport.Leaderboard.Internal.table config state (init raceControl)



-- PREVIOUS LEADERBOARD


type alias Leaderboard =
    List LeaderboardItem


type alias LeaderboardItem =
    { position : Int
    , carNumber : String
    , drivers : List Driver
    , class : Class
    , team : String
    , lap : Int
    , gap : Gap
    , interval : Gap
    , sector_1 : Maybe { time : Duration, personalBest : Duration }
    , sector_2 : Maybe { time : Duration, personalBest : Duration }
    , sector_3 : Maybe { time : Duration, personalBest : Duration }
    , lastLap : Maybe Lap
    , history : List Lap
    }


init : RaceControl.Model -> Leaderboard
init { clock, cars } =
    cars
        |> List.indexedMap
            (\index car ->
                let
                    raceClock =
                        { elapsed = Clock.getElapsed clock }

                    currentLap =
                        Maybe.withDefault Lap.empty car.currentLap

                    lastLap =
                        Maybe.withDefault Lap.empty car.lastLap

                    currentSector =
                        Lap.currentSector raceClock currentLap

                    ( sector_1, sector_2, sector_3 ) =
                        case currentSector of
                            S1 ->
                                ( Nothing, Nothing, Nothing )

                            S2 ->
                                ( Just { time = currentLap.sector_1, personalBest = currentLap.s1_best }
                                , Nothing
                                , Nothing
                                )

                            S3 ->
                                ( Just { time = currentLap.sector_1, personalBest = currentLap.s1_best }
                                , Just { time = currentLap.sector_2, personalBest = currentLap.s2_best }
                                , Nothing
                                )
                in
                { position = index + 1
                , drivers =
                    car.drivers
                        |> List.map
                            (\{ name } ->
                                { name = name
                                , isCurrentDriver = name == lastLap.driver
                                }
                            )
                , carNumber = car.carNumber
                , class = car.class
                , team = car.team
                , lap = lastLap.lap
                , gap =
                    Maybe.map2 (Gap.at clock) (List.head cars) (Just car)
                        |> Maybe.withDefault Gap.None
                , interval =
                    Maybe.map2 (Gap.at clock) (List.Extra.getAt (index - 1) cars) (Just car)
                        |> Maybe.withDefault Gap.None
                , sector_1 = sector_1
                , sector_2 = sector_2
                , sector_3 = sector_3
                , lastLap = car.lastLap
                , history = completedLapsAt raceClock car.laps
                }
            )



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
