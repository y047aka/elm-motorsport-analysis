module Page.LeaderBoard exposing (Model, Msg, init, update, view)

import Data.LapTime as LapTime exposing (LapTime)
import Data.LapTimes exposing (Lap, LapTimes, lapTimesDecoder)
import Data.RaceClock as RaceClock exposing (RaceClock, countDown, countUp)
import Html.Styled as Html exposing (Html, text)
import Html.Styled.Events exposing (onClick)
import Http
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import UI.SortableData exposing (State, initialSort, intColumn, stringColumn, table)



-- MODEL


type alias Model =
    { raceClock : RaceClock
    , lapTimes : LapTimes
    , sortedCars : LeaderBoard
    , tableState : State
    , query : String
    }


type alias LeaderBoard =
    List
        { position : Int
        , carNumber : String
        , driver : String
        , lap : Int
        , diff : LapTime
        , time : LapTime
        , fastest : LapTime
        }


init : ( Model, Cmd Msg )
init =
    ( { raceClock = RaceClock.init []
      , lapTimes = []
      , sortedCars = []
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
                            , time = 0
                            , fastest = 0
                            , diff = 0
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
                            lap =
                                findCompletedLap raceClock car.laps
                                    |> Maybe.withDefault { lap = 0, time = 0, fastest = 0, elapsed = 0 }
                        in
                        { car = car, lap = lap, elapsed = lap.elapsed }
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
                , diff =
                    List.head sortedCars
                        |> Maybe.map (\leader -> lap.elapsed - leader.elapsed)
                        |> Maybe.withDefault 0
                , time = lap.time
                , fastest = lap.fastest
                }
            )


findCompletedLap : RaceClock -> List Lap -> Maybe Lap
findCompletedLap clock =
    List.filter (\lap -> lap.elapsed <= clock.elapsed)
        >> List.reverse
        >> List.head



-- VIEW


view : Model -> List (Html Msg)
view { raceClock, sortedCars, tableState } =
    [ labeledButton []
        [ button [ onClick CountDown ] [ text "-" ]
        , basicLabel [] [ text (String.fromInt raceClock.lapCount) ]
        , button [ onClick CountUp ] [ text "+" ]
        ]
    , text <| RaceClock.toString raceClock
    , sortableTable tableState sortedCars
    ]


sortableTable : State -> LeaderBoard -> Html Msg
sortableTable tableState =
    let
        config =
            { toId = .carNumber
            , toMsg = SetTableState
            , columns =
                [ intColumn { label = "Position", getter = .position }
                , stringColumn { label = "#", getter = .carNumber }
                , stringColumn { label = "Driver", getter = .driver }
                , intColumn { label = "Lap", getter = .lap }
                , laptimeColumn { label = "Diff", getter = .diff }
                , laptimeColumn { label = "Time", getter = .time }
                , laptimeColumn { label = "Best", getter = .fastest }
                ]
            }

        laptimeColumn { label, getter } =
            stringColumn { label = label, getter = getter >> LapTime.toString }
    in
    table config tableState
