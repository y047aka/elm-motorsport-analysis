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
    }


init : ( Model, Cmd Msg )
init =
    ( { raceClock = RaceClock.init []
      , lapTimes = []
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
update msg model =
    case msg of
        Loaded (Ok lapTimes) ->
            ( { model
                | raceClock = RaceClock.init (List.map .laps lapTimes)
                , lapTimes = lapTimes
              }
            , Cmd.none
            )

        Loaded (Err _) ->
            ( model, Cmd.none )

        CountUp ->
            ( { model | raceClock = countUp model.raceClock }, Cmd.none )

        CountDown ->
            ( { model | raceClock = countDown model.raceClock }, Cmd.none )



-- VIEW


view : Model -> List (Html Msg)
view { raceClock, lapTimes } =
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
                ]
            ]
        , tbody [] <|
            List.map
                (\{ carNumber, driver, laps } ->
                    let
                        { time, fastest, elapsed } =
                            currentLap raceClock.lapCount laps
                    in
                    tr []
                        [ td [] [ text carNumber ]
                        , td [] [ text driver.name ]
                        , td [] [ text <| LapTime.toString time ]
                        , td [] [ text <| LapTime.toString fastest ]
                        , td [] [ text <| LapTime.toString elapsed ]
                        ]
                )
                lapTimes
        ]
    ]


currentLap : Int -> List Lap -> Lap
currentLap lapCount =
    List.filter (\{ lap } -> lapCount == lap)
        >> List.head
        >> Maybe.withDefault { lap = 0, time = 0, fastest = 0, elapsed = 0 }
