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
import Motorsport.Clock as Clock
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Replay as Replay
import Shared.Msg exposing (Msg(..))



-- MODEL


type alias Model =
    { eventSummary : EventSummary
    , replay : Replay.Model
    , snapshot : Snapshot
    , pendingWecCars : Maybe (List Car)
    , pendingWecLaps : Maybe (List WecLaps.RawLap)
    }


init : flags -> ( Model, Effect Msg )
init _ =
    let
        replayInit =
            Replay.empty

        snapshotInit =
            snapshotOf replayInit
    in
    ( { eventSummary = { id = "", name = "", season = 0, date = "", jsonPath = "" }
      , replay = replayInit
      , snapshot = snapshotInit
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

        ReplayMsg replayMsg ->
            let
                replayNew =
                    Replay.update replayMsg m.replay
            in
            ( { m
                | replay = replayNew
                , snapshot = snapshotOf replayNew
              }
            , Effect.none
            )


{-| The race read where playback has got to.
-}
snapshotOf : Replay.Model -> Snapshot
snapshotOf { race, playback } =
    Snapshot.at { elapsed = Clock.getElapsed playback } race


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

                replayNew =
                    Replay.fromCars carsWithLaps
            in
            ( { m
                | replay = replayNew
                , snapshot = snapshotOf replayNew
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
