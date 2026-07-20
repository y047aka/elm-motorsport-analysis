module Shared exposing (Model, init, update, subscriptions)

{-| Application-wide state, preserved from the elm-pages version. The data is
loaded at runtime via `Http`, so no `BackendTask` is involved.

@docs Model, init, update, subscriptions

-}

import Data.Series as Series
import Data.Series.EventSummary exposing (EventSummary)
import Data.Series.Wec
import Data.Wec as Wec
import Data.Wec.Laps as WecLaps
import Effect exposing (Effect)
import Http
import Motorsport.Car as Car exposing (Car)
import Motorsport.RaceControl as RaceControl
import Motorsport.TimelineEvent as TimelineEvent
import Motorsport.ViewModel as ViewModel exposing (ViewModel)
import Motorsport.ViewModel.BestTimes exposing (Scope(..))
import Shared.Msg exposing (Msg(..))



-- MODEL


type alias Model =
    { eventSummary : EventSummary
    , raceControl : RaceControl.Model
    , viewModel : ViewModel
    , pendingWecCars : Maybe (List Car)
    , pendingWecLaps : Maybe (List WecLaps.RawLap)
    }


init : flags -> ( Model, Effect Msg )
init _ =
    let
        raceControlInit =
            RaceControl.placeholder

        viewModelInit =
            ViewModel.compute { season = 0 } WholeRace raceControlInit
    in
    ( { eventSummary = { id = "", name = "", season = 0, date = "", jsonPath = "" }
      , raceControl = raceControlInit
      , viewModel = viewModelInit
      , pendingWecCars = Nothing
      , pendingWecLaps = Nothing
      }
    , Effect.none
    )



-- UPDATE


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    case msg of
        FetchJson_Wec options ->
            let
                eventSummary =
                    Maybe.map2 Tuple.pair (String.toInt options.season) (Data.Series.Wec.fromString options.event)
                        |> Maybe.andThen Series.toEventSummary
                        |> Maybe.withDefault { id = "", name = "", season = 0, date = "", jsonPath = "" }
            in
            ( { m
                | eventSummary = eventSummary
                , pendingWecCars = Nothing
                , pendingWecLaps = Nothing
              }
            , Effect.sendCmd <|
                Cmd.batch
                    [ Http.get
                        { url = eventSummary.jsonPath
                        , expect = Http.expectJson JsonLoaded_Wec Wec.eventDecoder
                        }
                    , Http.get
                        { url = lapsPathFor eventSummary.jsonPath
                        , expect = Http.expectJson LapsLoaded_Wec WecLaps.decoder
                        }
                    ]
            )

        JsonLoaded_Wec (Ok decoded) ->
            let
                cars =
                    decoded.startingGrid |> List.map Car.fromStartingGrid

                modelEventSummary =
                    m.eventSummary
            in
            finalizeWecIfReady
                { m
                    | eventSummary = { modelEventSummary | name = decoded.name }
                    , pendingWecCars = Just cars
                }

        JsonLoaded_Wec (Err _) ->
            ( m, Effect.none )

        LapsLoaded_Wec (Ok rawLaps) ->
            finalizeWecIfReady { m | pendingWecLaps = Just rawLaps }

        LapsLoaded_Wec (Err _) ->
            ( m, Effect.none )

        RaceControlMsg raceControlMsg ->
            let
                rcNew =
                    RaceControl.update raceControlMsg m.raceControl
            in
            ( { m
                | raceControl = rcNew
                , viewModel = ViewModel.compute { season = m.eventSummary.season } UpToElapsed rcNew
              }
            , Effect.none
            )


lapsPathFor : String -> String
lapsPathFor jsonPath =
    if String.endsWith ".json" jsonPath then
        String.dropRight 5 jsonPath ++ "_laps.json"

    else
        jsonPath ++ "_laps.json"


finalizeWecIfReady : Model -> ( Model, Effect Msg )
finalizeWecIfReady m =
    case ( m.pendingWecCars, m.pendingWecLaps ) of
        ( Just cars, Just rawLaps ) ->
            let
                carsWithLaps =
                    WecLaps.attach rawLaps cars

                rcNew =
                    RaceControl.fromCars (TimelineEvent.fromCars carsWithLaps) carsWithLaps
                        |> Maybe.withDefault RaceControl.placeholder
            in
            ( { m
                | raceControl = rcNew
                , viewModel = ViewModel.compute { season = m.eventSummary.season } WholeRace rcNew
                , pendingWecCars = Nothing
                , pendingWecLaps = Nothing
              }
            , Effect.none
            )

        _ ->
            ( m, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
