module Page.RaceSummary exposing (Model, Msg, init, update, view)

import Data.Analysis exposing (Analysis, analysisDecoder)
import Data.Car exposing (Car)
import Html.Styled as Html exposing (Html, td, text, th, tr)
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
        |> Maybe.map (\analysis_ -> [ raceSummary analysis_ ])
        |> Maybe.withDefault []


raceSummary : Analysis -> Html msg
raceSummary { summary } =
    Html.table []
        [ tr []
            [ th [] [ text "seasonName" ]
            , td [] [ text summary.seasonName ]
            ]
        , tr []
            [ th [] [ text "eventName" ]
            , td [] [ text summary.eventName ]
            ]
        ]
