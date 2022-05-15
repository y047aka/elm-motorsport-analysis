module Page.LeaderBoard exposing (Model, Msg, init, update, view)

import Data.LapTime as LapTime
import Data.LapTimes exposing (Lap, LapTimes, lapTimesDecoder)
import Data.RaceClock as RaceClock exposing (RaceClock, countDown, countUp)
import Html.Styled as Html exposing (Html, table, tbody, td, text, th, thead, tr)
import Html.Styled.Events exposing (onClick)
import Http
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)



-- MODEL


type alias Model =
    { raceClock : RaceClock
    , lapTimes : LapTimes
    , sortedCars : LapTimes
    }


init : ( Model, Cmd Msg )
init =
    ( { raceClock = RaceClock.init []
      , lapTimes = []
      , sortedCars = []
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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    case msg of
        Loaded (Ok lapTimes) ->
            ( { m
                | raceClock = RaceClock.init (List.map .laps lapTimes)
                , lapTimes = lapTimes
                , sortedCars = lapTimes
              }
            , Cmd.none
            )

        Loaded (Err _) ->
            ( m, Cmd.none )

        CountUp ->
            let
                updatedClock =
                    countUp m.raceClock
            in
            ( { m
                | raceClock = updatedClock
                , sortedCars = sort updatedClock m.sortedCars
              }
            , Cmd.none
            )

        CountDown ->
            let
                updatedClock =
                    countDown m.raceClock
            in
            ( { m
                | raceClock = updatedClock
                , sortedCars = sort updatedClock m.sortedCars
              }
            , Cmd.none
            )


sort : RaceClock -> LapTimes -> LapTimes
sort raceClock cars =
    cars
        |> List.map
            (\car ->
                let
                    { lap, elapsed } =
                        findCompletedLap raceClock car.laps
                            |> Maybe.withDefault { lap = 0, time = 0, fastest = 0, elapsed = 0 }
                in
                { lap = lap, elapsed = elapsed, car = car }
            )
        |> List.sortWith
            (\a b ->
                case compare a.lap b.lap of
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
        |> List.map .car


findCompletedLap : RaceClock -> List Lap -> Maybe Lap
findCompletedLap clock =
    List.filter (\lap -> lap.elapsed <= clock.elapsed)
        >> List.reverse
        >> List.head



-- VIEW


view : Model -> List (Html Msg)
view { raceClock, sortedCars } =
    [ labeledButton []
        [ button [ onClick CountDown ] [ text "-" ]
        , basicLabel [] [ text (String.fromInt raceClock.lapCount) ]
        , button [ onClick CountUp ] [ text "+" ]
        ]
    , text <| RaceClock.toString raceClock
    , table []
        [ thead []
            [ tr []
                [ th [] [ text "CarNumber" ]
                , th [] [ text "Driver" ]
                , th [] [ text "LapTime" ]
                , th [] [ text "Fastest" ]
                , th [] [ text "Elapsed" ]
                , th [] [ text "LapCount" ]
                ]
            ]
        , tbody [] <|
            List.map
                (\{ carNumber, driver, laps } ->
                    let
                        { lap, time, fastest, elapsed } =
                            findCompletedLap raceClock laps
                                |> Maybe.withDefault { lap = 0, time = 0, fastest = 0, elapsed = 0 }
                    in
                    tr []
                        [ td [] [ text carNumber ]
                        , td [] [ text driver.name ]
                        , td [] [ text <| LapTime.toString time ]
                        , td [] [ text <| LapTime.toString fastest ]
                        , td [] [ text <| LapTime.toString elapsed ]
                        , td [] [ text <| String.fromInt lap ]
                        ]
                )
                sortedCars
        ]
    ]
