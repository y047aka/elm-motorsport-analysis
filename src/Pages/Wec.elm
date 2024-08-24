module Pages.Wec exposing (Model, Msg, page)

import Chart.PositionHistory as PositionHistoryChart
import Effect exposing (Effect)
import Html.Styled as Html exposing (input, text)
import Html.Styled.Attributes as Attributes exposing (type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Clock as Clock
import Motorsport.RaceControl as RaceControl
import Page exposing (Page)
import Route exposing (Route)
import Shared
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , view = view shared
        , subscriptions = \_ -> Sub.none
        }



-- MODEL


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
    ( {}
    , Effect.fetchCsv "/static/23_Analysis_Race_Hour 24.csv"
    )



-- UPDATE


type Msg
    = RaceControlMsg RaceControl.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        RaceControlMsg raceControlMsg ->
            ( model, Effect.updateRaceControl raceControlMsg )



-- VIEW


view : Shared.Model -> Model -> View Msg
view { raceControl, ordersByLap } _ =
    { title = "Wec"
    , body =
        let
            { raceClock, lapTotal } =
                raceControl
        in
        [ input
            [ type_ "range"
            , Attributes.max <| String.fromInt lapTotal
            , value (String.fromInt raceClock.lapCount)
            , onInput (String.toInt >> Maybe.withDefault 0 >> RaceControl.SetCount >> RaceControlMsg)
            ]
            []
        , labeledButton []
            [ button [ onClick (RaceControlMsg RaceControl.PreviousLap) ] [ text "-" ]
            , basicLabel [] [ text (String.fromInt raceClock.lapCount) ]
            , button [ onClick (RaceControlMsg RaceControl.NextLap) ] [ text "+" ]
            ]
        , text <| Clock.toString raceClock
        , PositionHistoryChart.view { raceControl = raceControl, ordersByLap = ordersByLap }
        ]
    }
