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
import Motorsport.Class.Era as Era
import Motorsport.Race.Entrant as Entrant exposing (Entrant)
import Motorsport.Replay as Replay
import Motorsport.ViewModel as ViewModel exposing (ViewModel)
import Motorsport.ViewModel.BestTimes exposing (Scope(..))
import Shared.Msg exposing (Msg(..))



-- MODEL


type alias Model =
    { eventSummary : EventSummary
    , replay : Replay.Model
    , viewModel : ViewModel
    , pendingWecEntrants : Maybe (List Entrant)
    , pendingWecLaps : Maybe (List WecLaps.RawLap)
    }


init : flags -> ( Model, Effect Msg )
init _ =
    let
        replayInit =
            Replay.empty

        viewModelInit =
            ViewModel.compute WholeRace replayInit
    in
    ( { eventSummary = { id = "", name = "", season = 0, date = "", jsonPath = "" }
      , replay = replayInit
      , viewModel = viewModelInit
      , pendingWecEntrants = Nothing
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
                , pendingWecEntrants = Nothing
                , pendingWecLaps = Nothing
              }
            , case Era.fromSeason eventSummary.season of
                Just era ->
                    Effect.sendCmd <|
                        Cmd.batch
                            [ Http.get
                                { url = eventSummary.jsonPath
                                , expect = Http.expectJson JsonLoaded_Wec (Wec.eventDecoder era)
                                }
                            , Http.get
                                { url = lapsPathFor eventSummary.jsonPath
                                , expect = Http.expectJson LapsLoaded_Wec WecLaps.decoder
                                }
                            ]

                Nothing ->
                    -- No grid for this season, so no way to read its classes.
                    -- Nothing is asked for.
                    Effect.none
            )

        JsonLoaded_Wec (Ok decoded) ->
            let
                entrants =
                    decoded.startingGrid |> List.map Entrant.fromStartingGrid

                modelEventSummary =
                    m.eventSummary
            in
            finalizeWecIfReady
                { m
                    | eventSummary = { modelEventSummary | name = decoded.name }
                    , pendingWecEntrants = Just entrants
                }

        JsonLoaded_Wec (Err _) ->
            ( m, Effect.none )

        LapsLoaded_Wec (Ok rawLaps) ->
            finalizeWecIfReady { m | pendingWecLaps = Just rawLaps }

        LapsLoaded_Wec (Err _) ->
            ( m, Effect.none )

        ReplayMsg replayMsg ->
            let
                replayNew =
                    Replay.update replayMsg m.replay
            in
            ( { m
                | replay = replayNew
                , viewModel = ViewModel.compute UpToElapsed replayNew
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
    case ( m.pendingWecEntrants, m.pendingWecLaps ) of
        ( Just entrants, Just rawLaps ) ->
            let
                entrantsWithLaps =
                    WecLaps.attach rawLaps entrants

                replayNew =
                    Replay.fromEntrants entrantsWithLaps
            in
            ( { m
                | replay = replayNew
                , viewModel = ViewModel.compute WholeRace replayNew
                , pendingWecEntrants = Nothing
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
