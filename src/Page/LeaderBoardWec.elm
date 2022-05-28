module Page.LeaderBoardWec exposing (Model, Msg, init, update, view)

import AssocList
import AssocList.Extra
import Chart.Fragments exposing (dot, path)
import Css exposing (color, hex, px)
import Csv.Decode as Decode exposing (Decoder, FieldNames(..))
import Data.Duration as Duration exposing (Duration)
import Data.Gap as Gap exposing (Gap(..))
import Data.Lap exposing (Lap, LapStatus(..), completedLapsAt, fastestLap, findLastLapAt, lapStatus, slowestLap)
import Data.Lap.Wec exposing (lapDecoder)
import Data.Decoder exposing (Decoded)
import Data.RaceClock as RaceClock exposing (RaceClock, countDown, countUp)
import Html.Styled as Html exposing (Html, span, text)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events exposing (onClick)
import Http exposing (Error(..), Expect, Response(..), expectStringResponse)
import List.Extra as List
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
    , decoded : Decoded
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
        , gap : Gap
        , time : Duration
        , best : Duration
        , history : List Lap
        }


init : ( Model, Cmd Msg )
init =
    ( { raceClock = RaceClock.init
      , decoded = []
      , sortedCars = []
      , analysis = Nothing
      , tableState = initialSort "Position"
      , query = ""
      }
    , fetchCsv
    )


fetchCsv : Cmd Msg
fetchCsv =
    Http.get
        { url = "/static/23_Analysis_Race_Hour 24.csv"
        , expect = expectCsv Loaded lapDecoder
        }


expectCsv : (Result Error (List a) -> msg) -> Decoder a -> Expect msg
expectCsv toMsg decoder =
    let
        resolve : (body -> Result String (List a)) -> Response body -> Result Error (List a)
        resolve toResult response =
            case response of
                BadUrl_ url ->
                    Err (BadUrl url)

                Timeout_ ->
                    Err Timeout

                NetworkError_ ->
                    Err NetworkError

                BadStatus_ metadata _ ->
                    Err (BadStatus metadata.statusCode)

                GoodStatus_ _ body ->
                    Result.mapError BadBody (toResult body)
    in
    expectStringResponse toMsg <|
        resolve
            (Decode.decodeCustom { fieldSeparator = ';' } FieldNamesFromFirstRow decoder
                >> Result.mapError Decode.errorToString
            )



-- UPDATE


type Msg
    = Loaded (Result Http.Error (List Data.Lap.Wec.Lap))
    | CountUp
    | CountDown
    | SetTableState State


update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    case msg of
        Loaded (Ok records) ->
            let
                decoded =
                    records
                        |> AssocList.Extra.groupBy .carNumber
                        |> AssocList.toList
                        |> List.map
                            (\( carNumber, laps_ ) ->
                                List.indexedMap
                                    (\index { driverName, lapNumber, lapTime, elapsed } ->
                                        { carNumber = String.fromInt carNumber
                                        , driver = driverName
                                        , lap = lapNumber
                                        , time = lapTime
                                        , best =
                                            laps_
                                                |> List.take (index + 1)
                                                |> List.map .lapTime
                                                |> List.minimum
                                                |> Maybe.withDefault 0
                                        , elapsed = elapsed
                                        }
                                    )
                                    laps_
                            )
            in
            ( { m
                | raceClock = RaceClock.init
                , decoded = decoded
                , sortedCars =
                    List.indexedMap
                        (\index laps ->
                            let
                                { carNumber, driver } =
                                    List.head laps
                                        |> Maybe.map (\l -> { carNumber = l.carNumber, driver = l.driver })
                                        |> Maybe.withDefault { carNumber = "000", driver = "" }
                            in
                            { position = index + 1
                            , carNumber = carNumber
                            , driver = driver
                            , lap = 0
                            , gap = None
                            , time = 0
                            , best = 0
                            , history = []
                            }
                        )
                        decoded
              }
            , Cmd.none
            )

        Loaded (Err _) ->
            ( m, Cmd.none )

        CountUp ->
            let
                maxCount =
                    m.decoded
                        |> List.map List.length
                        |> List.maximum
                        |> Maybe.withDefault 0

                updatedClock =
                    countUp m.decoded m.raceClock
            in
            ( if m.raceClock.lapCount < maxCount then
                { m
                    | raceClock = updatedClock
                    , sortedCars = toLeaderBoard updatedClock m.decoded
                    , analysis = Just (analysis_ updatedClock m.decoded)
                }

              else
                m
            , Cmd.none
            )

        CountDown ->
            let
                updatedClock =
                    countDown m.decoded m.raceClock
            in
            ( { m
                | raceClock = updatedClock
                , sortedCars = toLeaderBoard updatedClock m.decoded
                , analysis = Just (analysis_ updatedClock m.decoded)
              }
            , Cmd.none
            )

        SetTableState newState ->
            ( { m | tableState = newState }, Cmd.none )


toLeaderBoard : RaceClock -> Decoded -> LeaderBoard
toLeaderBoard raceClock cars =
    let
        sortedCars =
            cars
                |> List.map
                    (\laps ->
                        let
                            lastLap =
                                findLastLapAt raceClock laps
                                    |> Maybe.withDefault { carNumber = "", driver = "", lap = 0, time = 0, best = 0, elapsed = 0 }
                        in
                        { laps = laps, lap = lastLap }
                    )
                |> List.sortWith
                    (\a b ->
                        case compare a.lap.lap b.lap.lap of
                            LT ->
                                GT

                            EQ ->
                                case compare a.lap.elapsed b.lap.elapsed of
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
            (\index { laps, lap } ->
                let
                    { carNumber, driver } =
                        List.head laps
                            |> Maybe.map (\l -> { carNumber = l.carNumber, driver = l.driver })
                            |> Maybe.withDefault { carNumber = "000", driver = "" }
                in
                { position = index + 1
                , driver = driver
                , carNumber = carNumber
                , lap = lap.lap
                , gap =
                    List.head sortedCars
                        |> Maybe.map (\leader -> Gap.from leader.lap lap)
                        |> Maybe.withDefault None
                , time = lap.time
                , best = lap.best
                , history = completedLapsAt raceClock laps
                }
            )


analysis_ : RaceClock -> Decoded -> { fastestLapTime : Duration, slowestLapTime : Duration }
analysis_ clock decoded =
    let
        completedLaps =
            List.map (completedLapsAt clock) decoded
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
        raceClock
        (Maybe.withDefault { fastestLapTime = 0, slowestLapTime = 0 } analysis)
        sortedCars
    ]


sortableTable : State -> RaceClock -> { fastestLapTime : Duration, slowestLapTime : Duration } -> LeaderBoard -> Html Msg
sortableTable tableState raceClock analysis =
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
                    , getter = .gap >> Gap.toString
                    , sorter = increasingOrDecreasingBy .position
                    }
                , veryCustomColumn
                    { label = "Gap"
                    , getter =
                        \{ gap } ->
                            case gap of
                                None ->
                                    text "-"

                                Seconds duration ->
                                    gap_ duration

                                Laps _ ->
                                    text "-"
                    , sorter = increasingOrDecreasingBy .position
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
                    { label = "Time"
                    , getter = .history >> performance raceClock analysis
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


xScale : ( Int, Float ) -> ContinuousScale Float
xScale ( min, max ) =
    ( toFloat min, max ) |> Scale.linear ( padding, w - padding )


yScale : ( Float, Float ) -> ContinuousScale Float
yScale ( min, max ) =
    ( min, max ) |> Scale.linear ( h - padding, padding )


histogram : { fastestLapTime : Duration, slowestLapTime : Duration } -> List Lap -> Html msg
histogram { fastestLapTime, slowestLapTime } laps =
    let
        xScale_ =
            xScale ( fastestLapTime, min (toFloat fastestLapTime * 1.2) (toFloat slowestLapTime) )

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
            , InPx.width (time |> toFloat |> Scale.convert (xScale ( 0, 100000 )))
            , InPx.height 20
            , fill "#999"
            ]
            []
        ]


performance : RaceClock -> { a | fastestLapTime : Duration } -> List Lap -> Html msg
performance raceClock { fastestLapTime } laps =
    svg [ viewBox 0 0 w h, SvgAttributes.css [ Css.width (px 200) ] ]
        [ dotHistory
            { x = .elapsed >> toFloat >> Scale.convert (xScale ( 0, toFloat <| raceClock.elapsed ))
            , y = .time >> toFloat >> Scale.convert (yScale ( toFloat fastestLapTime * 1.2, toFloat fastestLapTime ))
            , color = "#999"
            }
            laps
        ]


dotHistory : { x : a -> Float, y : a -> Float, color : String } -> List a -> Svg msg
dotHistory { x, y, color } laps =
    dotHistory_
        { dots =
            List.map
                (\lap ->
                    dot
                        { cx = x lap
                        , cy = y lap
                        , fillColor = color
                        }
                )
                laps
        , path =
            laps
                |> List.map (\item -> Just ( x item, y item ))
                |> path { strokeColor = color }
        }


dotHistory_ : { dots : List (Svg msg), path : Svg msg } -> Svg msg
dotHistory_ options =
    g []
        [ options.path
        , g [] options.dots
        ]
