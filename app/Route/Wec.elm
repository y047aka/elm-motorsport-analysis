module Route.Wec exposing (ActionData, Data, Model, Msg(..), RouteParams, data, route)

import BackendTask exposing (BackendTask)
import Css exposing (alignItems, backgroundColor, center, displayFlex, hsl, justifyContent, position, property, px, right, spaceBetween, sticky, textAlign, top, width, zero)
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html.Styled as Html exposing (div, header, img, input, nav, text)
import Html.Styled.Attributes as Attributes exposing (css, src, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.PositionHistory as PositionHistoryChart
import Motorsport.Clock as Clock exposing (Model(..))
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (bestTimeColumn, carNumberColumn_Wec, currentLapColumn_Wec, customColumn, driverAndTeamColumn_Wec, histogramColumn, initialSort, intColumn, lastLapColumn_Wec, performanceColumn, veryCustomColumn)
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel exposing (ViewModelItem)
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App)
import Shared
import String exposing (dropRight)
import Task
import Time
import UI.Button exposing (button, labeledButton)
import UrlPath exposing (UrlPath)
import View exposing (View)


type alias RouteParams =
    {}


route =
    RouteBuilder.single { data = data, head = \_ -> [] }
        |> RouteBuilder.buildWithSharedState
            { init = init
            , update = update
            , view = view
            , subscriptions = subscriptions
            }



-- MODEL


type alias Model =
    { mode : Mode
    , leaderboardState : Leaderboard.Model
    , query : String
    }


type Mode
    = Leaderboard
    | PositionHistory


init :
    App Data ActionData {}
    -> Shared.Model
    -> ( Model, Effect Msg )
init app shared =
    ( { mode = Leaderboard
      , leaderboardState = initialSort "Position"
      , query = ""
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = StartRace
    | PauseRace
    | ModeChange Mode
    | RaceControlMsg RaceControl.Msg
    | LeaderboardMsg Leaderboard.Msg


update :
    App Data ActionData {}
    -> Shared.Model
    -> Msg
    -> Model
    -> ( Model, Effect Msg, Maybe Shared.Msg )
update app shared msg m =
    case msg of
        StartRace ->
            ( m, Task.perform (RaceControl.Start >> RaceControlMsg) Time.now |> Effect.fromCmd, Nothing )

        PauseRace ->
            ( m, Task.perform (RaceControl.Pause >> RaceControlMsg) Time.now |> Effect.fromCmd, Nothing )

        ModeChange mode ->
            ( { m | mode = mode }, Effect.none, Nothing )

        RaceControlMsg raceControlMsg ->
            ( m, Effect.none, Just (Shared.RaceControlMsg_Wec raceControlMsg) )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            , Nothing
            )



-- SUBSCRIPTIONS


subscriptions : {} -> UrlPath -> Shared.Model -> Model -> Sub Msg
subscriptions _ _ shared model =
    case shared.raceControl_Wec.clock of
        Started _ _ ->
            Time.every (1000 / 60) (RaceControl.Tick >> RaceControlMsg)

        _ ->
            Sub.none



-- DATA


type alias Data =
    {}


type alias ActionData =
    {}


data : BackendTask FatalError Data
data =
    BackendTask.succeed {}



-- VIEW


view :
    App Data ActionData {}
    -> Shared.Model
    -> Model
    -> View (PagesMsg Msg)
view app { analysis_Wec, raceControl_Wec } { mode, leaderboardState } =
    View.map PagesMsg.fromMsg
        { title = "Wec"
        , body =
            [ header
                [ css
                    [ position sticky
                    , top zero
                    , displayFlex
                    , justifyContent spaceBetween
                    , backgroundColor (hsl 0 0 0.4)
                    ]
                ]
                [ nav []
                    [ case raceControl_Wec.clock of
                        Initial ->
                            button [ onClick StartRace ] [ text "Start" ]

                        Started _ _ ->
                            button [ onClick PauseRace ] [ text "Pause" ]

                        Paused _ ->
                            button [ onClick StartRace ] [ text "Resume" ]

                        _ ->
                            text ""
                    , case raceControl_Wec.clock of
                        Started _ _ ->
                            text ""

                        _ ->
                            labeledButton []
                                [ button [ onClick (RaceControlMsg RaceControl.Add10seconds) ] [ text "+10s" ]
                                , button [ onClick (RaceControlMsg RaceControl.NextLap) ] [ text "+1 Lap" ]
                                ]
                    ]
                , statusBar raceControl_Wec
                , nav []
                    [ button [ onClick (ModeChange Leaderboard) ] [ text "Leaderboard" ]
                    , button [ onClick (ModeChange PositionHistory) ] [ text "Position History" ]
                    ]
                ]
            , case mode of
                Leaderboard ->
                    Leaderboard.view (config analysis_Wec) leaderboardState raceControl_Wec

                PositionHistory ->
                    PositionHistoryChart.view raceControl_Wec
            ]
        }


statusBar : RaceControl.Model -> Html.Html Msg
statusBar { clock, lapTotal, lapCount } =
    let
        elapsed =
            Clock.getElapsed clock

        remaining =
            24 * 60 * 60 * 1000 - elapsed
    in
    div [ css [ displayFlex, alignItems center, property "column-gap" "10px" ] ]
        [ div []
            [ div [] [ text "Elapsed" ]
            , div [] [ text (Clock.toString clock) ]
            ]
        , input
            [ type_ "range"
            , Attributes.max <| String.fromInt lapTotal
            , value (String.fromInt lapCount)
            , onInput (String.toInt >> Maybe.withDefault 0 >> RaceControl.SetCount >> RaceControlMsg)
            ]
            []
        , div [ css [ textAlign right ] ]
            [ div [] [ text "Remaining" ]
            , div [] [ text (Duration.toString remaining |> dropRight 4) ]
            ]
        ]


config : Analysis -> Leaderboard.Config ViewModelItem Msg
config analysis =
    { toId = .metaData >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "", getter = .position }
        , carNumberColumn_Wec { getter = .metaData }
        , driverAndTeamColumn_Wec { getter = .metaData }
        , veryCustomColumn
            { label = "-"
            , getter = .metaData >> .carNumber >> carImageUrl >> Maybe.map (\url -> img [ src url, css [ width (px 100) ] ] []) >> Maybe.withDefault (text "")
            , sorter = List.sortBy (.metaData >> .carNumber)
            }
        , intColumn { label = "Lap", getter = .lap }
        , customColumn
            { label = "Gap"
            , getter = .timing >> .gap >> Gap.toString
            , sorter = List.sortBy .position
            }
        , customColumn
            { label = "Interval"
            , getter = .timing >> .interval >> Gap.toString
            , sorter = List.sortBy .position
            }
        , currentLapColumn_Wec
            { getter = identity
            , sorter = List.sortBy (.currentLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , lastLapColumn_Wec
            { getter = .lastLap
            , sorter = List.sortBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , bestTimeColumn { getter = .lastLap >> Maybe.map .best }
        , performanceColumn
            { getter = .history
            , sorter = List.sortBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , histogramColumn
            { getter = .history
            , sorter = List.sortBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            , coefficient = 1.2
            }
        ]
    }


carImageUrl : String -> Maybe String
carImageUrl carNumber =
    let
        domain =
            "https://storage.googleapis.com"

        path =
            "/ecm-prod/media/cache/easy_thumb/assets/1/engage"
    in
    carImageFileName carNumber
        -- |> Maybe.map (\fileName -> String.concat [ domain, path, fileName ])
        |> Maybe.map (\fileName -> String.concat [ "/static/image", String.dropLeft 6 fileName ])


carImageFileName : String -> Maybe String
carImageFileName carNumber =
    case carNumber of
        "2" ->
            Just "/80971/2024-wec-2-cadillac-droite_0d4f1c.png"

        "3" ->
            Just "/86899/2024-lm-3-cadillac-droite_c3c109.png"

        "4" ->
            Just "/86900/2024-lm-4-porsche-963-droite_1d620d.png"

        "5" ->
            Just "/80972/2024-wec-5-porsche-963-droite_d4f58d.png"

        "6" ->
            Just "/80973/2024-wec-6-porsche-963-droite_d4f63b.png"

        "7" ->
            Just "/80974/2024-wec-7toyota-gr010-7-droite_4660d4.png"

        "8" ->
            Just "/80975/2024-wec-8toyota-gr010-8-droite_f77a4f.png"

        "9" ->
            Just "/86905/2024-lm-9-oreca-07-droite_1666c3.png"

        "10" ->
            Just "/86906/2024-lm-10-oreca-07-droite_78bd95.png"

        "11" ->
            Just "/85287/2024-wec-11-isotta-fraschini-droite_e049c9.png"

        "12" ->
            Just "/84465/2024-wec-12-porsche-963-droite_466350.png"

        "14" ->
            Just "/86909/2024-lm-14-oreca-07-droite_c955cd.png"

        "15" ->
            Just "/80978/2024-wec-15-bmw-m-hybrid-v8-droite_133660.png"

        "19" ->
            Just "/86911/2024-lm-19-lamborghini-sc63-droite_cb7e49.png"

        "20" ->
            Just "/80979/2024-wec-20-bmw-m-hybrid-v8-droite_60d4fa.png"

        "22" ->
            Just "/86913/2024-lm-22-oreca-07-droite_6c3d04.png"

        "23" ->
            Just "/86914/2024-lm-23-oreca-07-droite_0f97a3.png"

        "24" ->
            Just "/86915/2024-lm-24-oreca-07-droite_1ecd50.png"

        "25" ->
            Just "/86916/2024-lm-25-oreca-07-droite_38666c.png"

        "27" ->
            Just "/82124/2024-wec-27-aston-martin-gt3-droite_301661.png"

        "28" ->
            Just "/86918/2024-lm-28-oreca-07-droite_0666c3.png"

        "30" ->
            Just "/86919/2024-lm-30-oreca-07-droite_7338bc.png"

        "31" ->
            Just "/87116/2024-wec-31-bmw-m4-gt3-sp-droite_68434d.png"

        "33" ->
            Just "/86921/2024-lm-33-oreca-07-droite_666c3d.png"

        "34" ->
            Just "/86922/2024-lm-34-oreca-07-droite_d77f36.png"

        "35" ->
            Just "/84904/2024-wec-35-alpine-droite_06639e.png"

        "36" ->
            Just "/84905/2024-wec-36-alpine-droite_6639e0.png"

        "37" ->
            Just "/86925/2024-lm-37-oreca-07-droite_922666.png"

        "38" ->
            Just "/89170/2024-wec-38-porsche-963-droite_66cf3b.png"

        "44" ->
            Just "/86927/2024-lm-44-ford-mustang-droite_3dcd73.png"

        "45" ->
            Just "/86928/2024-lm-45-oreca-07-droite_6c3dd8.png"

        "46" ->
            Just "/87115/2024-wec-46-bmw-m4-gt3-sp-droite_8434c5.png"

        "47" ->
            Just "/86930/2024-lm-47-oreca-07-droite_c3df1e.png"

        "50" ->
            Just "/87106/2024-wec-50-ferrari-droite_668067.png"

        "51" ->
            Just "/87107/2024-wec-51-ferrari-droite_466806.png"

        "54" ->
            Just "/80225/2024-wec-54-ferrari-296-gt3-droite_96739e.png"

        "55" ->
            Just "/87110/2024-wec-55-ferrari-296-gt3-droite_398905.png"

        "59" ->
            Just "/88528/2024-wec-59-mclaren-720s-cota-droite_6c8579.png"

        "60" ->
            Just "/80694/2024-wec-60-lamborghini-huracan-gt3-evo2-droite_9d2e22.png"

        "63" ->
            Just "/80985/2024-wec-63-lamborghini-sc63-droite_437660.png"

        "65" ->
            Just "/86938/2024-lm-65-oreca-07-droite_c3f026.png"

        "66" ->
            Just "/86939/2024-lm-66-ferrari-296-gt3-droite_666c3f.png"

        "70" ->
            Just "/86940/2024-lm-70-mclaren-720s-droite_666c3f.png"

        "77" ->
            Just "/79980/2024-wec-77-ford-mustang-droite_65dc67.png"

        "78" ->
            Just "/80229/2024-wec-78-lexus-rc-f-lmgt3-droite_ecc4c6.png"

        "81" ->
            Just "/79982/2024-wec-81-corvette-z06-gt3-r-droite_7465dc.png"

        "82" ->
            Just "/79983/2024-wec-82-corvette-z06-gt3-r-droite_96c378.png"

        "83" ->
            Just "/87108/2024-wec-83-ferrari-droite_19a0da.png"

        "85" ->
            Just "/80701/2024-wec-85-lamborghini-huracan-gt3-evo2-droite_a81791.png"

        "86" ->
            Just "/86947/2024-lm-86-ferrari-296-droite_3fad55.png"

        "87" ->
            Just "/80194/2024-wec-87-lexus-rc-f-lmgt3-droite_5dec73.png"

        "88" ->
            Just "/79987/2024-wec-88-ford-mustang-droite_23bf01.png"

        "91" ->
            Just "/80704/2024-wec-91-porsche-911-gt3-r-droite_765f85.png"

        "92" ->
            Just "/90632/2024-wec-92-porsche-911-gt3-r-droite-bahrain_1adc79.png"

        "93" ->
            Just "/82125/2024-wec-93-peugeot-9x8-droite_592661.png"

        "94" ->
            Just "/82126/2024-wec-94-peugeot-9x8-droite_691661.png"

        "95" ->
            Just "/88529/2024-wec-95-mclaren-720s-cota-droite_f6f3c6.png"

        "99" ->
            Just "/87109/2024-wec-99-porsche-963-sp-droite_73721.png"

        "155" ->
            Just "/86956/2024-lm-155-ferrari-296-droite_68062e.png"

        "183" ->
            Just "/86957/2024-lm-183-oreca-07-droite_7666c4.png"

        "311" ->
            Just "/86958/2024-lm-311-cadillac-droite_f2b29b.png"

        "777" ->
            Just "/82733/2024-wec-777-aston-martin-gt3-droite_8d4f6c.png"

        _ ->
            Nothing
