module Page.LeaderBoard exposing (Model, Msg, init, update, view)

import Data.LapTime as LapTime
import Data.LapTimes exposing (Lap, LapTimes, lapTimesDecoder)
import Html.Styled as Html exposing (Html, table, tbody, td, text, th, thead, tr)
import Html.Styled.Events exposing (onClick)
import Http
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)



-- MODEL


type alias Model =
    { lapCount : Int
    , lapTimes : LapTimes
    }


init : ( Model, Cmd Msg )
init =
    ( { lapCount = 0
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
            ( { model | lapTimes = lapTimes }, Cmd.none )

        Loaded (Err _) ->
            ( model, Cmd.none )

        CountUp ->
            ( { model | lapCount = model.lapCount + 1 }, Cmd.none )

        CountDown ->
            ( { model
                | lapCount =
                    if model.lapCount > 0 then
                        model.lapCount - 1

                    else
                        model.lapCount
              }
            , Cmd.none
            )



-- VIEW


view : Model -> List (Html Msg)
view { lapCount, lapTimes } =
    [ labeledButton []
        [ button [ onClick CountDown ] [ text "-" ]
        , basicLabel [] [ text (String.fromInt lapCount) ]
        , button [ onClick CountUp ] [ text "+" ]
        ]
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
                            currentLap lapCount laps
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
