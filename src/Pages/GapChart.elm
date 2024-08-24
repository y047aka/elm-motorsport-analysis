module Pages.GapChart exposing (Model, Msg, page)

import Chart.GapChart as GapChart
import Data.F1.Analysis exposing (Analysis, analysisDecoder)
import Data.Wec.Car exposing (Car)
import Effect exposing (Effect)
import Http
import Page exposing (Page)
import Route exposing (Route)
import Shared
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }



-- MODEL


type alias Model =
    { analysis : Maybe Analysis
    , cars : List Car
    , ordersByLap : OrdersByLap
    }


type alias OrdersByLap =
    List { lapNumber : Int, order : List Int }


init : () -> ( Model, Effect Msg )
init () =
    ( { analysis = Nothing
      , cars = []
      , ordersByLap = []
      }
    , fetchCsv
    )


fetchCsv : Effect Msg
fetchCsv =
    Effect.sendCmd <|
        Http.get
            { url = "/static/raceHistoryAnalytics.json"
            , expect = Http.expectJson Loaded analysisDecoder
            }



-- UPDATE


type Msg
    = Loaded (Result Http.Error Analysis)


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        Loaded (Ok analysis) ->
            ( { model | analysis = Just analysis }, Effect.none )

        Loaded (Err _) ->
            ( model, Effect.none )



-- VIEW


view : Model -> View Msg
view { analysis } =
    { title = "GapChart"
    , body =
        analysis
            |> Maybe.map (\analysis_ -> [ GapChart.view analysis_ ])
            |> Maybe.withDefault []
    }
