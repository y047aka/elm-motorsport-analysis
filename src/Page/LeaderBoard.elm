module Page.LeaderBoard exposing (Model, Msg, init, update, view)

import Css exposing (color, hex, px)
import Data.Duration as Duration exposing (Duration)
import Data.Lap exposing (Lap, LapStatus(..), completedLapsAt, fastestLap, findLastLapAt, lapStatus, slowestLap)
import Data.LapTimes exposing (LapTimes, lapTimesDecoder)
import Data.RaceClock as RaceClock exposing (RaceClock, countDown, countUp)
import Html.Styled as Html exposing (Html, span, text)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events exposing (onClick)
import Http
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg, g, rect, svg)
import Svg.Styled.Attributes as SvgAttributes exposing (fill)
import TypedSvg.Styled.Attributes exposing (viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import UI.SortableData exposing (State, customColumn, increasingOrDecreasingBy, initialSort, intColumn, stringColumn, table, veryCustomColumn)



-- MODEL


type alias Model =
    { raceClock : RaceClock
    , lapTimes : LapTimes
    , sortedCars : LeaderBoard
    , analysis :
        Maybe
            { fastestLapTime : Duration
            , slowestLapTime : Duration
            }
    , tableState : State
    , query : String
    }


type alias LeaderBoard =
    List
        { position : Int
        , carNumber : String
        , driver : String
        , lap : Int
        , gap : Duration
        , time : Duration
        , best : Duration
        , history : List Lap
        }


init : ( Model, Cmd Msg )
init =
    ( { raceClock = RaceClock.init []
      , lapTimes = []
      , sortedCars = []
      , analysis = Nothing
      , tableState = initialSort "Position"
      , query = ""
      }
    , fetchJson
    )


fetchJson : Cmd Msg
fetchJson =
    Http.get
        { url = "/static/lapTimes.json"
        , expect = Http.expectJson Loaded lapTimesDecoder
        }



-- UPDATE


type Msg
    = Loaded (Result Http.Error LapTimes)
    | CountUp
    | CountDown
    | SetTableState State


update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    case msg of
        Loaded (Ok lapTimes) ->
            ( { m
                | raceClock = RaceClock.init (List.map .laps lapTimes)
                , lapTimes = lapTimes
                , sortedCars =
                    List.indexedMap
                        (\index { carNumber, driver } ->
                            { position = index + 1
                            , carNumber = carNumber
                            , driver = driver.name
                            , lap = 0
                            , gap = 0
                            , time = 0
                            , best = 0
                            , history = []
                            }
                        )
                        lapTimes
              }
            , Cmd.none
            )

        Loaded (Err _) ->
            ( m, Cmd.none )

        CountUp ->
            let
                maxCount =
                    m.lapTimes
                        |> List.map (.laps >> List.length)
                        |> List.maximum
                        |> Maybe.withDefault 0

                updatedClock =
                    countUp m.raceClock
            in
            ( if m.raceClock.lapCount < maxCount then
                { m
                    | raceClock = updatedClock
                    , sortedCars = toLeaderBoard updatedClock m.lapTimes
                    , analysis = Just (analysis_ updatedClock m.lapTimes)
                }

              else
                m
            , Cmd.none
            )

        CountDown ->
            let
                updatedClock =
                    countDown m.raceClock
            in
            ( { m
                | raceClock = updatedClock
                , sortedCars = toLeaderBoard updatedClock m.lapTimes
                , analysis = Just (analysis_ updatedClock m.lapTimes)
              }
            , Cmd.none
            )

        SetTableState newState ->
            ( { m | tableState = newState }, Cmd.none )


toLeaderBoard : RaceClock -> LapTimes -> LeaderBoard
toLeaderBoard raceClock cars =
    let
        sortedCars =
            cars
                |> List.map
                    (\car ->
                        let
                            lastLap =
                                findLastLapAt raceClock car.laps
                                    |> Maybe.withDefault { lap = 0, time = 0, best = 0, elapsed = 0 }
                        in
                        { car = car, lap = lastLap, elapsed = lastLap.elapsed }
                    )
                |> List.sortWith
                    (\a b ->
                        case compare a.lap.lap b.lap.lap of
                            LT ->
                                GT

                            EQ ->
                                case compare a.elapsed b.elapsed of
                                    LT ->
                                        LT

                                    EQ ->
                                        EQ

                                    GT ->
                                        GT

                            GT ->
                                LT
                    )
    in
    sortedCars
        |> List.indexedMap
            (\index { car, lap } ->
                { position = index + 1
                , driver = car.driver.name
                , carNumber = car.carNumber
                , lap = lap.lap
                , gap =
                    List.head sortedCars
                        |> Maybe.map (\leader -> lap.elapsed - leader.elapsed)
                        |> Maybe.withDefault 0
                , time = lap.time
                , best = lap.best
                , history = completedLapsAt raceClock car.laps
                }
            )


analysis_ : RaceClock -> LapTimes -> { fastestLapTime : Duration, slowestLapTime : Duration }
analysis_ clock lapTimes =
    let
        completedLaps =
            List.map (.laps >> completedLapsAt clock) lapTimes
    in
    { fastestLapTime = completedLaps |> fastestLap |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = completedLaps |> slowestLap |> Maybe.map .time |> Maybe.withDefault 0
    }



-- VIEW


view : Model -> List (Html Msg)
view { raceClock, sortedCars, analysis, tableState } =
    [ labeledButton []
        [ button [ onClick CountDown ] [ text "-" ]
        , basicLabel [] [ text (String.fromInt raceClock.lapCount) ]
        , button [ onClick CountUp ] [ text "+" ]
        ]
    , text <| RaceClock.toString raceClock
    , sortableTable tableState
        (Maybe.withDefault { fastestLapTime = 0, slowestLapTime = 0 } analysis)
        sortedCars
    ]


sortableTable : State -> { fastestLapTime : Duration, slowestLapTime : Duration } -> LeaderBoard -> Html Msg
sortableTable tableState analysis =
    let
        config =
            { toId = .carNumber
            , toMsg = SetTableState
            , columns =
                [ intColumn { label = "Position", getter = .position }
                , stringColumn { label = "#", getter = .carNumber }
                , stringColumn { label = "Driver", getter = .driver }
                , intColumn { label = "Lap", getter = .lap }
                , customColumn
                    { label = "Gap"
                    , getter =
                        \{ gap } ->
                            if gap == 0 then
                                "-"

                            else
                                "+ " ++ Duration.toString gap
                    , sorter = increasingOrDecreasingBy .gap
                    }
                , veryCustomColumn
                    { label = "Gap"
                    , getter = .gap >> gap_
                    , sorter = increasingOrDecreasingBy .gap
                    }
                , veryCustomColumn
                    { label = "Time"
                    , getter =
                        \item ->
                            span
                                [ css
                                    [ color <|
                                        hex <|
                                            case lapStatus { time = analysis.fastestLapTime } item of
                                                Fastest ->
                                                    "#F0F"

                                                PersonalBest ->
                                                    "#0C0"

                                                Normal ->
                                                    "inherit"
                                    ]
                                ]
                                [ text <| Duration.toString item.time ]
                    , sorter = increasingOrDecreasingBy .time
                    }
                , veryCustomColumn
                    { label = "Histogram"
                    , getter = .history >> histogram analysis
                    , sorter = increasingOrDecreasingBy .time
                    }
                ]
            }
    in
    table config tableState



-- CHART


w : Float
w =
    200


h : Float
h =
    20


padding : Float
padding =
    1


xScale : Int -> Int -> ContinuousScale Float
xScale min max =
    Scale.linear ( padding, w - padding ) ( toFloat min, toFloat max )


yScale : Float -> ContinuousScale Float
yScale _ =
    Scale.linear ( h - padding, padding ) ( 0, 0 )


histogram : { fastestLapTime : Duration, slowestLapTime : Duration } -> List Lap -> Html msg
histogram { fastestLapTime, slowestLapTime } laps =
    let
        width lap =
            if isCurrentLap lap then
                3

            else
                1

        color lap =
            case
                ( isCurrentLap lap, lapStatus { time = fastestLapTime } { time = lap.time, best = lap.best } )
            of
                ( True, Fastest ) ->
                    "#F0F"

                ( True, PersonalBest ) ->
                    "#0C0"

                ( True, Normal ) ->
                    "#FC0"

                ( False, _ ) ->
                    "hsla(0, 0%, 50%, 0.5)"

        isCurrentLap { lap } =
            List.length laps == lap
    in
    svg [ viewBox 0 0 w h, SvgAttributes.css [ Css.width (px 200) ] ]
        [ histogram_
            { x = .time >> toFloat >> Scale.convert (xScale fastestLapTime slowestLapTime)
            , y = always 0 >> Scale.convert (yScale 0)
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
                    , fill (color lap)
                    ]
                    []
            )
            laps


gap_ : Duration -> Html msg
gap_ time =
    svg [ viewBox 0 0 w h, SvgAttributes.css [ Css.width (px 200) ] ]
        [ rect
            [ InPx.x 0
            , InPx.y 0
            , InPx.width (time |> toFloat |> Scale.convert (xScale 0 100000))
            , InPx.height 20
            , fill "#999"
            ]
            []
        ]
