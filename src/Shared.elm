module Shared exposing
    ( Flags, decoder
    , Model, Msg
    , init, update, subscriptions
    )

{-|

@docs Flags, decoder
@docs Model, Msg
@docs init, update, subscriptions

-}

import Csv.Decode as Decode exposing (Decoder, FieldNames(..))
import Data.F1.Decoder as F1
import Data.F1.Preprocess as Preprocess_F1
import Data.Series as Series
import Data.Wec.Decoder as Wec
import Data.Wec.Preprocess as Preprocess_Wec
import Effect exposing (Effect)
import Http exposing (Error(..), Expect, Response(..))
import Json.Decode
import Motorsport.Analysis as Analysis
import Motorsport.RaceControl as RaceControl
import Route exposing (Route)
import Shared.Model
import Shared.Msg exposing (Msg(..))



-- FLAGS


type alias Flags =
    {}


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.succeed {}



-- INIT


type alias Model =
    Shared.Model.Model


init : Result Json.Decode.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult route =
    ( { eventSummary = { name = "", date = "" }
      , raceControl_F1 = RaceControl.empty
      , raceControl_Wec = RaceControl.empty
      , analysis_F1 = Analysis.finished RaceControl.empty
      , analysis_Wec = Analysis.finished RaceControl.empty
      }
    , Effect.none
    )



-- UPDATE


type alias Msg =
    Shared.Msg.Msg


update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update route msg m =
    case msg of
        FetchJson url ->
            ( m
            , Effect.sendCmd <|
                Http.get
                    { url = url
                    , expect = Http.expectJson JsonLoaded F1.decoder
                    }
            )

        JsonLoaded (Ok decoded) ->
            let
                rcNew =
                    RaceControl.init (Preprocess_F1.preprocess decoded)
            in
            ( { m
                | raceControl_F1 = rcNew
                , analysis_F1 = Analysis.finished rcNew
              }
            , Effect.none
            )

        JsonLoaded (Err _) ->
            ( m, Effect.none )

        FetchCsv options ->
            let
                { eventSummary, filePath } =
                    Series.fromString options.event
                        |> Maybe.map (\event -> { eventSummary = Series.toEventSummary event, filePath = Series.toCsvFilePath event })
                        |> Maybe.withDefault { eventSummary = { name = "", date = "" }, filePath = "" }
            in
            ( { m | eventSummary = eventSummary }
            , Effect.sendCmd <|
                Http.get
                    { url = filePath
                    , expect = expectCsv CsvLoaded Wec.lapDecoder
                    }
            )

        CsvLoaded (Ok decoded) ->
            let
                rcNew =
                    RaceControl.init (Preprocess_Wec.preprocess decoded)
            in
            ( { m
                | raceControl_Wec = rcNew
                , analysis_Wec = Analysis.finished rcNew
              }
            , Effect.none
            )

        CsvLoaded (Err _) ->
            ( m, Effect.none )

        RaceControlMsg_F1 raceControlMsg ->
            let
                rcNew =
                    RaceControl.update raceControlMsg m.raceControl_F1
            in
            ( { m
                | raceControl_F1 = rcNew
                , analysis_F1 = Analysis.fromRaceControl rcNew
              }
            , Effect.none
            )

        RaceControlMsg_Wec raceControlMsg ->
            let
                rcNew =
                    RaceControl.update raceControlMsg m.raceControl_Wec
            in
            ( { m
                | raceControl_Wec = rcNew
                , analysis_Wec = Analysis.fromRaceControl rcNew
              }
            , Effect.none
            )


expectCsv : (Result Http.Error (List a) -> msg) -> Decoder a -> Expect msg
expectCsv toMsg decoder_ =
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
    in
    Http.expectStringResponse toMsg <|
        resolve
            (Decode.decodeCustom { fieldSeparator = ';' } FieldNamesFromFirstRow decoder_
                >> Result.mapError Decode.errorToString
            )



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions route model =
    Sub.none
