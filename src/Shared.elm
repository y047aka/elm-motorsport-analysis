module Shared exposing
    ( Flags, decoder
    , Model, Msg(..)
    , init, update, subscriptions
    )

{-|

@docs Flags, decoder
@docs Model, Msg
@docs init, update, subscriptions

-}

import Csv.Decode as Decode exposing (Decoder, FieldNames(..))
import Data.Wec.Decoder as Wec
import Data.Wec.Preprocess as Wec
import Http exposing (Error(..), Expect, Response(..), expectStringResponse)
import Json.Decode
import Motorsport.RaceControl as RaceControl
import Motorsport.Summary as Summary



-- FLAGS


type alias Flags =
    {}


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.succeed {}



-- INIT


type alias Model =
    { raceControl : RaceControl.Model }


init : Flags -> ( Model, Cmd Msg )
init flagsResult =
    ( { raceControl = RaceControl.empty }
    , Cmd.none
    )



-- UPDATE


type Msg
    = FetchCsv String
    | Loaded (Result Http.Error (List Wec.Lap))
    | RaceControlMsg RaceControl.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    case msg of
        FetchCsv url ->
            ( m
            , Http.get
                { url = url
                , expect = expectCsv Loaded Wec.lapDecoder
                }
            )

        Loaded (Ok decoded) ->
            let
                preprocessed =
                    Wec.preprocess decoded
            in
            ( { m | raceControl = RaceControl.init (Summary.calcLapTotal preprocessed) preprocessed }
            , Cmd.none
            )

        Loaded (Err _) ->
            ( m, Cmd.none )

        RaceControlMsg raceControlMsg ->
            ( { m | raceControl = RaceControl.update raceControlMsg m.raceControl }, Cmd.none )


expectCsv : (Result Error (List a) -> msg) -> Decoder a -> Expect msg
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
    expectStringResponse toMsg <|
        resolve
            (Decode.decodeCustom { fieldSeparator = ';' } FieldNamesFromFirstRow decoder_
                >> Result.mapError Decode.errorToString
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
