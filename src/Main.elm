module Main exposing (main)

import AssocList
import AssocList.Extra
import Browser exposing (Document)
import Browser.Navigation as Nav exposing (Key)
import Chart.Chart as Chart
import Chart.GapChart as GapChart
import Chart.LapTimeChart as LapTimeChart
import Chart.LapTimeChartsByDriver as LapTimeChartsByDriver
import Chart.LapTimes as LapTimes
import Css exposing (..)
import Csv
import Csv.Decode as CD exposing (Decoder, Errors(..))
import Data.Analysis exposing (Analysis, analysisDecoder)
import Data.Car exposing (Car)
import Data.Lap.Wec exposing (Lap, lapDecoder)
import Data.LapTimes exposing (LapTimes, lapTimesDecoder)
import Html.Styled as Html exposing (Html, div, td, text, th, toUnstyled, tr)
import Http exposing (Error(..), Expect, Response(..), expectStringResponse)
import List.Extra as List
import Parser exposing (deadEndsToString)
import Url exposing (Url)
import Url.Parser exposing (Parser)



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
    { key : Key
    , page : Page
    , lapTimes : Maybe LapTimes
    , cars : List Car
    , ordersByLap : OrdersByLap
    , hovered : Maybe Datum
    }


type Page
    = NotFound
    | Top


type alias OrdersByLap =
    List { lapNumber : Int, order : List Int }


type alias Datum =
    { elapsed : Float, lapCount : Int, time : Float }


init : () -> Url -> Key -> ( Model, Cmd Msg )
init _ url key =
    { key = key
    , page = Top
    , lapTimes = Nothing
    , cars = []
    , ordersByLap = []
    , hovered = Nothing
    }
        |> routing url
        |> (\( model, cmd ) -> ( model, Cmd.batch [ cmd, fetchJson ] ))


fetchJson : Cmd Msg
fetchJson =
    Http.get
        { url = "/static" ++ "" ++ "/lapTimes.json"
        , expect = Http.expectJson Loaded lapTimesDecoder
        }


fetchCsv : Cmd Msg
fetchCsv =
    Http.get
        { url = "/static" ++ "/23_Analysis_Race_Hour 24.csv"
        , expect = expectCsv Loaded2 lapDecoder
        }


expectCsv : (Result Error (List a) -> msg) -> Decoder (a -> a) a -> Expect msg
expectCsv toMsg decoder =
    let
        resolve : (body -> Result String (List a)) -> Response body -> Result Error (List a)
        resolve toResult response =
            case response of
                BadUrl_ url ->
                    Err (BadUrl url)

                Timeout_ ->
                    Err Timeout

                NetworkError_ ->
                    Err NetworkError

                BadStatus_ metadata _ ->
                    Err (BadStatus metadata.statusCode)

                GoodStatus_ _ body ->
                    Result.mapError BadBody (toResult body)

        errorsToString : Errors -> String
        errorsToString error =
            case error of
                CsvErrors _ ->
                    "Parse failed."

                DecodeErrors e ->
                    Debug.toString e
    in
    expectStringResponse toMsg <|
        resolve
            (Csv.parseWith ';'
                >> Result.map (\csv -> { csv | headers = List.map String.trim csv.headers })
                >> Result.mapError (deadEndsToString >> List.singleton >> CsvErrors)
                >> Result.andThen (CD.decodeCsv decoder)
                >> Result.mapError errorsToString
            )



-- ROUTER


parser : Parser (Page -> a) a
parser =
    Url.Parser.oneOf
        [ Url.Parser.map Top Url.Parser.top ]


routing : Url -> Model -> ( Model, Cmd Msg )
routing url model =
    Url.Parser.parse parser url
        |> Maybe.withDefault NotFound
        |> (\page -> ( { model | page = page }, Cmd.none ))



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | Loaded (Result Http.Error LapTimes)
    | Loaded2 (Result Http.Error (List Lap))
    | Hover (Maybe Datum)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlRequested urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            routing url model

        Loaded (Ok lapTimes) ->
            ( { model | lapTimes = Just lapTimes }, Cmd.none )

        Loaded (Err _) ->
            ( model, Cmd.none )

        Loaded2 (Ok laps) ->
            let
                ordersByLap =
                    laps
                        |> AssocList.Extra.groupBy .lapNumber
                        |> AssocList.toList
                        |> List.map
                            (\( lapNumber, order ) ->
                                { lapNumber = lapNumber
                                , order = order |> List.sortBy .elapsed |> List.map .carNumber
                                }
                            )

                cars =
                    laps
                        |> AssocList.Extra.groupBy .carNumber
                        |> AssocList.toList
                        |> List.filterMap (summarize ordersByLap)
            in
            ( { model
                | cars = cars
                , ordersByLap = ordersByLap
              }
            , Cmd.none
            )

        Loaded2 (Err _) ->
            ( model, Cmd.none )

        Hover hovered ->
            ( { model | hovered = hovered }, Cmd.none )


summarize : OrdersByLap -> ( Int, List Lap ) -> Maybe Car
summarize ordersByLap ( carNumber, laps ) =
    List.head laps
        |> Maybe.map
            (\{ class, group, team, manufacturer } ->
                { carNumber = carNumber
                , class = class
                , group = group
                , team = team
                , manufacturer = manufacturer
                , startPosition = Maybe.withDefault 0 <| getPositionAt { carNumber = carNumber, lapNumber = 1 } ordersByLap
                , positions =
                    List.indexedMap
                        (\index _ -> Maybe.withDefault 0 <| getPositionAt { carNumber = carNumber, lapNumber = index + 1 } ordersByLap)
                        laps
                , laps = laps
                }
            )


getPositionAt : { carNumber : Int, lapNumber : Int } -> OrdersByLap -> Maybe Int
getPositionAt { carNumber, lapNumber } ordersByLap =
    ordersByLap
        |> List.find (.lapNumber >> (==) lapNumber)
        |> Maybe.andThen (.order >> List.findIndex ((==) carNumber))



-- VIEW


view : Model -> Document Msg
view model =
    { title = "Race Analysis"
    , body =
        case model.page of
            Top ->
                case model.lapTimes of
                    Just lapTimes ->
                        [ toUnstyled <|
                            div []
                                [ -- raceSummary analysis
                                  -- , GapChart.view analysis
                                  -- , LapTimeChart.view analysis
                                  -- , LapTimeChartsByDriver.view analysis
                                  LapTimes.view lapTimes
                                ]
                        ]

                    Nothing ->
                        [ toUnstyled <|
                            Chart.view model
                        ]

            _ ->
                []
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
