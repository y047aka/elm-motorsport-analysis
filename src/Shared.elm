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

import Data.F1.Decoder as F1
import Data.F1.Preprocess as Preprocess_F1
import Data.Series as Series
import Data.Wec.Decoder.Json
import Data.Wec.Preprocess as Preprocess_Wec
import Effect exposing (Effect)
import Http
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
    ( { eventSummary = { name = "", date = "", csvPath = "" }
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

        FetchJson_Wec options ->
            let
                eventSummary =
                    Series.fromString options.event
                        |> Maybe.map Series.toEventSummary
                        |> Maybe.withDefault { name = "", date = "", csvPath = "" }
            in
            ( { m | eventSummary = eventSummary }
            , Effect.sendCmd <|
                Http.get
                    { url = eventSummary.csvPath
                    , expect = Http.expectJson JsonLoaded_Wec (Json.Decode.list Data.Wec.Decoder.Json.lapDecoder)
                    }
            )

        JsonLoaded_Wec (Ok decoded) ->
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

        JsonLoaded_Wec (Err _) ->
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



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions route model =
    Sub.none
