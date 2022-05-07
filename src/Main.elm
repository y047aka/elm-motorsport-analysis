module Main exposing (main)

import AssocList
import AssocList.Extra
import Browser exposing (Document)
import Browser.Navigation as Nav exposing (Key)
import Chart.Chart as Chart
import Chart.GapChart as GapChart
import Chart.LapTimeChart as LapTimeChart
import Chart.LapTimeChartsByDriver as LapTimeChartsByDriver
import Csv
import Csv.Decode as CD exposing (Decoder, Errors(..))
import Data.Analysis exposing (Analysis, analysisDecoder)
import Data.Car exposing (Car)
import Data.Lap.Wec exposing (Lap, lapDecoder)
import Html.Styled as Html exposing (Html, a, td, text, th, toUnstyled, tr)
import Html.Styled.Attributes exposing (href)
import Http exposing (Error(..), Expect, Response(..), expectStringResponse)
import List.Extra as List
import Page.LapTimeTable as LapTimeTable
import Parser exposing (deadEndsToString)
import Url exposing (Url)
import Url.Parser exposing (Parser, s)



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
    , subModel : SubModel
    , cars : List Car
    , ordersByLap : OrdersByLap
    , hovered : Maybe Datum
    }


type SubModel
    = None
    | TopModel
    | LapTimeTableModel LapTimeTable.Model


type alias OrdersByLap =
    List { lapNumber : Int, order : List Int }


type alias Datum =
    { elapsed : Float, lapCount : Int, time : Float }


init : () -> Url -> Key -> ( Model, Cmd Msg )
init _ url key =
    { key = key
    , subModel = TopModel
    , cars = []
    , ordersByLap = []
    , hovered = Nothing
    }
        |> routing url


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


type Page
    = NotFound
    | Top
    | LapTimeTable


parser : Parser (Page -> a) a
parser =
    Url.Parser.oneOf
        [ Url.Parser.map Top Url.Parser.top
        , Url.Parser.map LapTimeTable (s "laptime-table")
        ]


routing : Url -> Model -> ( Model, Cmd Msg )
routing url model =
    Url.Parser.parse parser url
        |> Maybe.withDefault NotFound
        |> (\page ->
                case page of
                    NotFound ->
                        ( { model | subModel = None }, Cmd.none )

                    Top ->
                        ( { model | subModel = TopModel }, Cmd.none )

                    LapTimeTable ->
                        LapTimeTable.init
                            |> updateWith LapTimeTableModel LapTimeTableMsg model
           )



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url
    | LapTimeTableMsg LapTimeTable.Msg
    | Loaded2 (Result Http.Error (List Lap))
    | Hover (Maybe Datum)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( model.subModel, msg ) of
        ( _, UrlRequested urlRequest ) ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        ( _, UrlChanged url ) ->
            routing url model

        ( LapTimeTableModel subModel, LapTimeTableMsg submsg ) ->
            LapTimeTable.update submsg subModel
                |> updateWith LapTimeTableModel LapTimeTableMsg model

        ( _, Loaded2 (Ok laps) ) ->
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

        ( _, Loaded2 (Err _) ) ->
            ( model, Cmd.none )

        ( _, Hover hovered ) ->
            ( { model | hovered = hovered }, Cmd.none )

        _ ->
            ( model, Cmd.none )


updateWith : (subModel -> SubModel) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg model ( subModel, subCmd ) =
    ( { model | subModel = toModel subModel }
    , Cmd.map toMsg subCmd
    )


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
        List.map toUnstyled <|
            case model.subModel of
                None ->
                    []

                TopModel ->
                    [ -- raceSummary analysis
                      -- , GapChart.view analysis
                      -- , LapTimeChart.view analysis
                      -- , LapTimeChartsByDriver.view analysis
                      a [ href "/laptime-table" ] [ text "LapTime table" ]
                    ]

                LapTimeTableModel subModel ->
                    LapTimeTable.view subModel
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
