module Page.LapTimeChart exposing (Model, Msg, init, update, view)

import Chart.LapTimeChart as LapTimeChart
import Data.Car exposing (Car)
import Data.F1.Analysis exposing (Analysis, analysisDecoder)
import Html.Styled as Html exposing (Html)
import Http



-- MODEL


type alias Model =
    { analysis : Maybe Analysis
    , cars : List Car
    , ordersByLap : OrdersByLap
    }


type alias OrdersByLap =
    List { lapNumber : Int, order : List Int }


init : ( Model, Cmd Msg )
init =
    ( { analysis = Nothing
      , cars = []
      , ordersByLap = []
      }
    , fetchCsv
    )


fetchCsv : Cmd Msg
fetchCsv =
    Http.get
        { url = "/static/raceHistoryAnalytics.json"
        , expect = Http.expectJson Loaded analysisDecoder
        }



-- UPDATE


type Msg
    = Loaded (Result Http.Error Analysis)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Loaded (Ok analysis) ->
            ( { model | analysis = Just analysis }, Cmd.none )

        Loaded (Err _) ->
            ( model, Cmd.none )



-- VIEW


view : Model -> List (Html msg)
view { analysis } =
    analysis
        |> Maybe.map (\analysis_ -> [ LapTimeChart.view analysis_ ])
        |> Maybe.withDefault []
