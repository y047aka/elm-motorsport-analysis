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
import Motorsport.Chart.Tracker as Tracker
import Motorsport.Circuit as Circuit
import Motorsport.Clock as Clock
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Replay as Replay
import Motorsport.Wec.Era as Era
import Shared.Msg exposing (Msg(..))



-- MODEL


{-| `track` is the one derived value kept here rather than worked out where it
is used: everything else about a frame follows from `replay` and the clock,
where the track never moves once the data has loaded. See
[`Tracker.trackOf`](Motorsport-Chart-Tracker#trackOf).
-}
type alias Model =
    { eventSummary : EventSummary
    , replay : Replay.Model
    , snapshot : Snapshot
    , track : Tracker.Track
    , pendingWecEvent : Maybe Wec.Event
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
    ( { eventSummary = noEvent
      , replay = replayInit
      , snapshot = snapshotInit
      , track = Tracker.trackOf replayInit.race
      , pendingWecEvent = Nothing
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
                        |> Maybe.withDefault noEvent
            in
            ( { m
                | eventSummary = eventSummary
                , pendingWecEvent = Nothing
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
                modelEventSummary =
                    m.eventSummary
            in
            finalizeWecIfReady
                { m
                    | eventSummary = { modelEventSummary | name = decoded.name }
                    , pendingWecEvent = Just decoded
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


{-| The round the app shows before one has been asked for, and in place of one
it cannot show. Its circuit is the plain clockwise layout, which is what an
empty race is drawn on.
-}
noEvent : EventSummary
noEvent =
    { id = ""
    , name = ""
    , season = 0
    , date = ""
    , jsonPath = ""
    , circuit = Circuit.clockwise
    }


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
    case ( m.pendingWecEvent, m.pendingWecLaps ) of
        ( Just event, Just rawLaps ) ->
            let
                carsWithLaps =
                    event.startingGrid.entries
                        |> List.map Car.fromStartingGrid
                        |> WecLaps.attach rawLaps

                replayNew =
                    Replay.fromCars
                        { circuit = m.eventSummary.circuit
                        , timeLimit = event.timeLimit
                        }
                        carsWithLaps
            in
            ( { m
                | replay = replayNew
                , snapshot = snapshotOf replayNew

                -- Settled here, with the race, and not touched again until the
                -- next one loads.
                , track = Tracker.trackOf replayNew.race
                , pendingWecEvent = Nothing
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
