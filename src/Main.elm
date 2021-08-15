module Main exposing (main)

import Browser exposing (Document)
import Browser.Navigation exposing (Key)
import Chart.LapTimeChart as LapTimeChart
import Css exposing (..)
import Data.Analysis exposing (Analysis, analysisDecoder)
import Html.Styled as Html exposing (Html, div, td, text, th, toUnstyled, tr)
import Http
import Url exposing (Url)



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        , onUrlChange = UrlChanged
        , onUrlRequest = UrlRequested
        }



-- MODEL


type alias Model =
    { analysis : Maybe Analysis
    , hovered : Maybe Datum
    }


type alias Datum =
    { elapsed : Float, lapCount : Int, time : Float }


init : () -> Url -> Key -> ( Model, Cmd Msg )
init _ url key =
    ( { analysis = Nothing
      , hovered = Nothing
      }
    , Http.get
        { url = "/static" ++ "" ++ "/raceHistoryAnalytics.json"
        , expect = Http.expectJson Loaded analysisDecoder
        }
    )



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | Loaded (Result Http.Error Analysis)
    | Hover (Maybe Datum)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Loaded (Ok analysis) ->
            ( { model | analysis = Just analysis }, Cmd.none )

        Loaded (Err _) ->
            ( model, Cmd.none )

        Hover hovered ->
            ( { model | hovered = hovered }, Cmd.none )

        _ ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Document Msg
view model =
    { title = "Race Analysis"
    , body =
        [ toUnstyled <|
            div []
                [ model.analysis
                    |> Maybe.map raceSummary
                    |> Maybe.withDefault (text "")
                , model.analysis
                    |> Maybe.map dataTable
                    |> Maybe.withDefault (text "")
                , model.analysis
                    |> Maybe.map LapTimeChart.view
                    |> Maybe.withDefault (text "")
                ]
        ]
    }


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


dataTable : Analysis -> Html msg
dataTable { raceHistories } =
    let
        tableRow history =
            tr [] <|
                List.map (\d -> td [] [ text d ])
                    [ history.carNumber ]
    in
    Html.table [] (List.map tableRow raceHistories)
