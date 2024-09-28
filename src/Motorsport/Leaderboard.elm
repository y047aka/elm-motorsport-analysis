module Motorsport.Leaderboard exposing
    ( stringColumn, intColumn, floatColumn
    , Model, initialSort
    , Msg, update
    , customColumn
    , sectorTimeColumn, lastLapColumn, bestTimeColumn
    , histogramColumn, performanceColumn
    , carNumberColumn_Wec
    , driverNameColumn_F1, driverAndTeamColumn_Wec
    , Config, Leaderboard, LeaderboardItem, view
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

@docs sectorTimeColumn, lastLapColumn, bestTimeColumn
@docs histogramColumn, performanceColumn
@docs carNumberColumn_Wec
@docs driverNameColumn_F1, driverAndTeamColumn_Wec

-}

import Css exposing (..)
import Css.Extra exposing (when)
import Html.Styled as Html exposing (Html, div, span, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Car exposing (Car)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap(..))
import Motorsport.Lap as Lap exposing (Lap, completedLapsAt, findCurrentLap, findLastLapAt)
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


lastLapColumn :
    { getter : data -> { a | lastLapTime : Duration, best : Duration }
    , sorter : List data -> List data
    , analysis : Analysis
    }
    -> Column data msg
lastLapColumn { getter, sorter, analysis } =
    { name = "Time"
    , view =
        getter
            >> (\{ lastLapTime, best } ->
                    span
                        [ css
                            [ let
                                status =
                                    lapStatus { time = analysis.fastestLapTime } { time = lastLapTime, best = best }
                              in
                              if LapStatus.isNormal status then
                                batch []

                              else
                                LapStatus.toHexColorString status
                                    |> hex
                                    |> color
                            ]
                        ]
                        [ text <| Duration.toString lastLapTime ]
               )
    , sorter = sorter
    }


sectorTimeColumn :
    { label : String
    , getter : data -> { time : Duration, best : Duration }
    , fastestSectorTime : Duration
    }
    -> Column data msg
sectorTimeColumn { label, getter, fastestSectorTime } =
    { name = label
    , view =
        getter
            >> (\sector ->
                    div
                        [ css
                            [ height (px 18)
                            , borderRadius (px 1)
                            , lapStatus { time = fastestSectorTime } sector
                                |> LapStatus.toHexColorString
                                |> (\c -> backgroundColor (hex c))
                            ]
                        ]
                        []
               )
    , sorter = List.sortBy (getter >> .time)
    }


bestTimeColumn : { getter : data -> Duration } -> Column data msg
bestTimeColumn { getter } =
    Motorsport.Leaderboard.Internal.customColumn
        { label = "Best"
        , getter = getter >> Duration.toString
        , sorter = List.sortBy getter
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
    , sector_1 : Duration
    , sector_2 : Duration
    , sector_3 : Duration
    , s1_best : Duration
    , s2_best : Duration
    , s3_best : Duration
    , lastLapTime : Duration
    , best : Duration
    , history : List Lap
    }


init : RaceControl.Model -> Leaderboard
init ({ raceClock } as raceControl) =
    let
        sortedCars =
            sortCarsAt raceControl
    in
    sortedCars
        |> List.indexedMap
            (\index { car, currentLap, lastLap } ->
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
                    List.head sortedCars
                        |> Maybe.map (\leader -> Gap.from leader.lastLap lastLap)
                        |> Maybe.withDefault Gap.None
                , interval =
                    List.Extra.getAt (index - 1) sortedCars
                        |> Maybe.map (\target -> Gap.from target.lastLap lastLap)
                        |> Maybe.withDefault Gap.None
                , sector_1 = lastLap.sector_1
                , sector_2 = lastLap.sector_2
                , sector_3 = lastLap.sector_3
                , s1_best = lastLap.s1_best
                , s2_best = lastLap.s2_best
                , s3_best = lastLap.s3_best
                , lastLapTime = lastLap.time
                , best = lastLap.best
                , history = completedLapsAt raceClock car.laps
                }
            )


sortCarsAt : RaceControl.Model -> List { car : Car, currentLap : Lap, lastLap : Lap }
sortCarsAt { raceClock, cars } =
    cars
        |> List.map
            (\car ->
                let
                    currentLap =
                        findCurrentLap raceClock car.laps
                            |> Maybe.withDefault
                                { carNumber = ""
                                , driver = ""
                                , lap = 0
                                , position = Nothing
                                , time = 0
                                , sector_1 = 0
                                , sector_2 = 0
                                , sector_3 = 0
                                , s1_best = 0
                                , s2_best = 0
                                , s3_best = 0
                                , best = 0
                                , elapsed = 0
                                }

                    lastLap =
                        findLastLapAt raceClock car.laps
                            |> Maybe.withDefault
                                { carNumber = ""
                                , driver = ""
                                , lap = 0
                                , position = Nothing
                                , time = 0
                                , sector_1 = 0
                                , sector_2 = 0
                                , sector_3 = 0
                                , s1_best = 0
                                , s2_best = 0
                                , s3_best = 0
                                , best = 0
                                , elapsed = 0
                                }
                in
                { car = car
                , currentLap = currentLap
                , lastLap = lastLap
                }
            )
        |> List.sortWith (\a b -> Lap.compare a.lastLap b.lastLap)



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
                lapStatus { time = fastestLapTime } lap
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
        toCssColor lap =
            (lapStatus { time = fastestLapTime } >> LapStatus.toHexColorString >> hex) lap
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
