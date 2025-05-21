module Shared exposing (Data, Model, Msg(..), template)

import BackendTask exposing (BackendTask)
import Css exposing (..)
import Css.Global exposing (global)
import Data.F1.Decoder as F1
import Data.F1.Preprocess as Preprocess_F1
import Data.FormulaE as FormulaE
import Data.Series as Series
import Data.Series.EventSummary exposing (EventSummary)
import Data.Series.FormulaE
import Data.Series.Wec
import Data.Wec as Wec
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html exposing (Html)
import Html.Styled exposing (main_)
import Http
import Motorsport.Analysis as Analysis exposing (Analysis)
import Motorsport.RaceControl as RaceControl
import Pages.Flags
import Pages.PageUrl exposing (PageUrl)
import Route exposing (Route)
import SharedTemplate exposing (SharedTemplate)
import UrlPath exposing (UrlPath)
import View exposing (View)


template : SharedTemplate Msg Model Data msg
template =
    { init = init
    , update = update
    , view = view
    , data = data
    , subscriptions = subscriptions
    , onPageChange = Nothing
    }


type alias Data =
    ()



-- INIT


type alias Model =
    { eventSummary : EventSummary
    , raceControl_F1 : RaceControl.Model
    , raceControl_Wec : RaceControl.Model
    , raceControl_FormulaE : RaceControl.Model
    , analysis_F1 : Analysis
    , analysis : Analysis
    }


init :
    Pages.Flags.Flags
    ->
        Maybe
            { path :
                { path : UrlPath
                , query : Maybe String
                , fragment : Maybe String
                }
            , metadata : route
            , pageUrl : Maybe PageUrl
            }
    -> ( Model, Effect Msg )
init flags maybePagePath =
    ( { eventSummary = { id = "", name = "", season = 0, date = "", jsonPath = "" }
      , raceControl_F1 = RaceControl.empty
      , raceControl_Wec = RaceControl.empty
      , raceControl_FormulaE = RaceControl.empty
      , analysis_F1 = Analysis.finished RaceControl.empty
      , analysis = Analysis.finished RaceControl.empty
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = FetchJson String
    | JsonLoaded (Result Http.Error (List F1.Car))
    | FetchJson_Wec { season : String, event : String }
    | JsonLoaded_Wec (Result Http.Error Wec.Event)
    | FetchJson_FormulaE { season : String, event : String }
    | JsonLoaded_FormulaE (Result Http.Error FormulaE.Event)
    | RaceControlMsg_F1 RaceControl.Msg
    | RaceControlMsg_Wec RaceControl.Msg
    | RaceControlMsg_FormulaE RaceControl.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    case msg of
        FetchJson url ->
            ( m
            , Effect.fromCmd <|
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
                    Maybe.map2 Tuple.pair (String.toInt options.season) (Data.Series.Wec.fromString options.event)
                        |> Maybe.andThen Series.toEventSummary
                        |> Maybe.withDefault { id = "", name = "", season = 0, date = "", jsonPath = "" }
            in
            ( { m | eventSummary = eventSummary }
            , Effect.fromCmd <|
                Http.get
                    { url = eventSummary.jsonPath
                    , expect = Http.expectJson JsonLoaded_Wec Wec.eventDecoder
                    }
            )

        JsonLoaded_Wec (Ok decoded) ->
            let
                rcNew =
                    RaceControl.init decoded.preprocessed

                modelEventSummary =
                    m.eventSummary
            in
            ( { m
                | eventSummary = { modelEventSummary | name = decoded.name }
                , raceControl_Wec = rcNew
                , analysis = Analysis.finished rcNew
              }
            , Effect.none
            )

        JsonLoaded_Wec (Err _) ->
            ( m, Effect.none )

        FetchJson_FormulaE options ->
            let
                eventSummary =
                    Maybe.map2 Tuple.pair (String.toInt options.season) (Data.Series.FormulaE.fromString options.event)
                        |> Maybe.andThen Series.toEventSummary_FormulaE
                        |> Maybe.withDefault { id = "", name = "", season = 0, date = "", jsonPath = "" }
            in
            ( { m | eventSummary = eventSummary }
            , Effect.fromCmd <|
                Http.get
                    { url = eventSummary.jsonPath
                    , expect = Http.expectJson JsonLoaded_FormulaE FormulaE.eventDecoder
                    }
            )

        JsonLoaded_FormulaE (Ok decoded) ->
            let
                rcNew =
                    RaceControl.init decoded.preprocessed

                modelEventSummary =
                    m.eventSummary
            in
            ( { m
                | eventSummary = { modelEventSummary | name = decoded.name }
                , raceControl_FormulaE = rcNew
                , analysis = Analysis.finished rcNew
              }
            , Effect.none
            )

        JsonLoaded_FormulaE (Err _) ->
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
                , analysis = Analysis.fromRaceControl rcNew
              }
            , Effect.none
            )

        RaceControlMsg_FormulaE raceControlMsg ->
            let
                rcNew =
                    RaceControl.update raceControlMsg m.raceControl_FormulaE
            in
            ( { m
                | raceControl_FormulaE = rcNew
                , analysis = Analysis.fromRaceControl rcNew
              }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : UrlPath -> Model -> Sub Msg
subscriptions _ _ =
    Sub.none


data : BackendTask FatalError Data
data =
    BackendTask.succeed ()



-- VIEW


view :
    Data
    ->
        { path : UrlPath
        , route : Maybe Route
        }
    -> Model
    -> (Msg -> msg)
    -> View msg
    -> { body : List (Html msg), title : String }
view sharedData page model toMsg pageView =
    { title = pageView.title
    , body =
        List.map Html.Styled.toUnstyled
            [ global
                [ Css.Global.body
                    [ fontFamilies [ "-apple-system", "BlinkMacSystemFont", qt "Segoe UI", "Helvetica", "Arial", "sans-serif", qt "Apple Color Emoji", qt "Segoe UI Emoji" ]
                    , backgroundColor (hsl 0 0 0.4)
                    , color (hsla 0 0 1 0.9)
                    ]
                ]
            , main_ [] pageView.body
            ]
    }
