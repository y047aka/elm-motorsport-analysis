module Shared exposing (Data, Model, Msg(..), template)

import BackendTask exposing (BackendTask)
import Css exposing (height, vh)
import Css.Global exposing (global)
import Data.F1.Decoder as F1
import Data.F1.Preprocess as Preprocess_F1
import Data.FormulaE as FormulaE
import Data.Series as Series
import Data.Series.EventSummary exposing (EventSummary)
import Data.Series.FormulaE
import Data.Series.Wec
import Data.Wec as Wec
import Data.Wec.Laps as WecLaps
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html exposing (Html)
import Html.Styled
import Http
import Motorsport.Analysis as Analysis exposing (Analysis)
import Motorsport.Car as Car exposing (Car)
import Motorsport.RaceControl as RaceControl
import Motorsport.TimelineEvent as TimelineEvent
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
    , raceControl : RaceControl.Model
    , analysis_F1 : Analysis
    , analysis : Analysis
    , pendingWecCars : Maybe (List Car)
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
      , raceControl_F1 = RaceControl.placeholder
      , raceControl = RaceControl.placeholder
      , analysis_F1 = Analysis.finished RaceControl.placeholder
      , analysis = Analysis.finished RaceControl.placeholder
      , pendingWecCars = Nothing
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = FetchJson String
    | JsonLoaded (Result Http.Error (List F1.Car))
    | FetchJson_Wec { season : String, event : String }
    | JsonLoaded_Wec (Result Http.Error Wec.Event)
    | LapsLoaded_Wec (Result Http.Error (List WecLaps.RawLap))
    | FetchJson_FormulaE { season : String, event : String }
    | JsonLoaded_FormulaE (Result Http.Error FormulaE.Event)
    | RaceControlMsg_F1 RaceControl.Msg
    | RaceControlMsg RaceControl.Msg


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
                    Preprocess_F1.preprocess decoded
                        |> RaceControl.fromCars []
                        |> Maybe.withDefault RaceControl.placeholder
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
                cars =
                    decoded.startingGrid |> List.map Car.fromStartingGrid

                modelEventSummary =
                    m.eventSummary
            in
            ( { m
                | eventSummary = { modelEventSummary | name = decoded.name }
                , pendingWecCars = Just cars
              }
            , Effect.fromCmd <|
                Http.get
                    { url = lapsPathFor m.eventSummary.jsonPath
                    , expect = Http.expectJson LapsLoaded_Wec WecLaps.decoder
                    }
            )

        JsonLoaded_Wec (Err _) ->
            ( m, Effect.none )

        LapsLoaded_Wec (Ok rawLaps) ->
            case m.pendingWecCars of
                Just cars ->
                    let
                        carsWithLaps =
                            WecLaps.attach rawLaps cars

                        rcNew =
                            RaceControl.fromCars (TimelineEvent.fromCars carsWithLaps) carsWithLaps
                                |> Maybe.withDefault RaceControl.placeholder
                    in
                    ( { m
                        | raceControl = rcNew
                        , analysis = Analysis.finished rcNew
                        , pendingWecCars = Nothing
                      }
                    , Effect.none
                    )

                Nothing ->
                    ( m, Effect.none )

        LapsLoaded_Wec (Err _) ->
            ( { m | pendingWecCars = Nothing }, Effect.none )

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
                cars =
                    decoded.startingGrid
                        |> List.map Car.fromStartingGrid
                        |> FormulaE.attachLaps decoded.laps

                rcNew =
                    RaceControl.fromCars (TimelineEvent.fromCars cars) cars
                        |> Maybe.withDefault RaceControl.placeholder

                modelEventSummary =
                    m.eventSummary
            in
            ( { m
                | eventSummary = { modelEventSummary | name = decoded.name }
                , raceControl = rcNew
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

        RaceControlMsg raceControlMsg ->
            let
                rcNew =
                    RaceControl.update raceControlMsg m.raceControl
            in
            ( { m
                | raceControl = rcNew
                , analysis = Analysis.fromRaceControl rcNew
              }
            , Effect.none
            )




lapsPathFor : String -> String
lapsPathFor jsonPath =
    if String.endsWith ".json" jsonPath then
        String.dropRight 5 jsonPath ++ "_laps.json"

    else
        jsonPath ++ "_laps.json"



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
        let
            globalReset =
                global
                    [ Css.Global.html [ height (vh 100) ]
                    , Css.Global.body [ height (vh 100) ]
                    ]
        in
        List.map Html.Styled.toUnstyled
            (globalReset :: pageView.body)
    }
