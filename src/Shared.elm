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

import AssocList
import AssocList.Extra
import Csv.Decode as Decode exposing (Decoder, FieldNames(..))
import Data.F1.Decoder as F1
import Data.F1.Preprocess as Preprocess_F1
import Data.Wec.Decoder as Wec
import Data.Wec.Preprocess as Preprocess_Wec
import Effect exposing (Effect)
import Http exposing (Error(..), Expect, Response(..))
import Json.Decode
import List.Extra as List
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
    ( { raceControl = RaceControl.empty
      , ordersByLap = []
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
                preprocessed =
                    Preprocess_F1.preprocess decoded
            in
            ( { m | raceControl = RaceControl.init preprocessed }
            , Effect.none
            )

        JsonLoaded (Err _) ->
            ( m, Effect.none )

        FetchCsv url ->
            ( m
            , Effect.sendCmd <|
                Http.get
                    { url = url
                    , expect = expectCsv CsvLoaded Wec.lapDecoder
                    }
            )

        CsvLoaded (Ok decoded) ->
            let
                preprocessed =
                    Preprocess_Wec.preprocess decoded

                ordersByLap =
                    decoded
                        |> AssocList.Extra.groupBy .lapNumber
                        |> AssocList.toList
                        |> List.map
                            (\( lapNumber, order ) ->
                                { lapNumber = lapNumber
                                , order = order |> List.sortBy .elapsed |> List.map .carNumber
                                }
                            )
            in
            ( { m
                | raceControl = RaceControl.init preprocessed
                , ordersByLap = ordersByLap
              }
            , Effect.none
            )

        CsvLoaded (Err _) ->
            ( m, Effect.none )

        RaceControlMsg raceControlMsg ->
            ( { m | raceControl = RaceControl.update raceControlMsg m.raceControl }, Effect.none )


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
