module Shared exposing (Model, init, update, subscriptions)

{-| Application-wide state, preserved from the elm-pages version. The data is
loaded at runtime via `Http`, so no `BackendTask` is involved.

@docs Model, init, update, subscriptions

-}

import Data.Wec as Wec
import Data.Wec.Calendar as Calendar exposing (Calendar)
import Data.Wec.Laps as WecLaps
import Effect exposing (Effect)
import Http
import Motorsport.Chart.Tracker as Tracker
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
[`Tracker.fromConfig`](Motorsport-Chart-Tracker#fromConfig).

`season` and `eventName` both come off the calendar entry the round was found
in, so the app never holds a second opinion about what a race is called.

`requestedRound` is a URL that arrived before the calendar did. The calendar is
what says where a round's files are, so the request waits rather than being
guessed at, and is cleared once issued so a later calendar cannot ask twice.

-}
type alias Model =
    { calendar : Calendar
    , season : Int
    , eventName : String
    , requestedRound : Maybe { season : String, event : String }
    , replay : Replay.Model
    , snapshot : Snapshot
    , track : Tracker.Track
    , pendingWecEvent : Maybe Wec.Event
    , pendingWecLaps : Maybe (List WecLaps.RawLap)
    }


{-| The calendar is asked for here rather than by the page that lists it: it is
the same file whichever route the app opened on, and a round reached by its URL
still needs it.
-}
init : flags -> ( Model, Effect Msg )
init _ =
    let
        replayInit =
            Replay.empty

        snapshotInit =
            snapshotOf replayInit
    in
    ( { calendar = Calendar.empty
      , season = 0
      , eventName = ""
      , requestedRound = Nothing
      , replay = replayInit
      , snapshot = snapshotInit
      , track = Tracker.empty
      , pendingWecEvent = Nothing
      , pendingWecLaps = Nothing
      }
    , Effect.sendCmd <|
        Http.get
            { url = "/static/wec/index.json"
            , expect = Http.expectJson CalendarLoaded Calendar.decoder
            }
    )



-- UPDATE


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    case msg of
        CalendarLoaded (Ok calendar) ->
            requestRequestedRound { m | calendar = calendar }

        CalendarLoaded (Err _) ->
            ( m, Effect.none )

        FetchJson_Wec options ->
            requestRequestedRound
                { m
                    | requestedRound = Just options
                    , season = 0
                    , eventName = ""
                    , pendingWecEvent = Nothing
                    , pendingWecLaps = Nothing
                }

        JsonLoaded_Wec (Ok decoded) ->
            finalizeWecIfReady { m | pendingWecEvent = Just decoded }

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


{-| Asks for the round the URL named, once the calendar can say where its files
are.

Called from both sides of the race between the two, so whichever of the URL and
the calendar arrives second is the one that finds everything it needs here.

-}
requestRequestedRound : Model -> ( Model, Effect Msg )
requestRequestedRound m =
    case Maybe.andThen (\params -> Calendar.findRound params m.calendar) m.requestedRound of
        Nothing ->
            ( m, Effect.none )

        Just ( season, round ) ->
            ( { m
                | requestedRound = Nothing
                , season = season.season
                , eventName = round.name
              }
            , case Era.fromSeason season.season of
                Just era ->
                    Effect.sendCmd <|
                        Cmd.batch
                            [ Http.get
                                { url = round.summary
                                , expect = Http.expectJson JsonLoaded_Wec (Wec.eventDecoder era)
                                }
                            , Http.get
                                { url = round.laps
                                , expect = Http.expectJson LapsLoaded_Wec WecLaps.decoder
                                }
                            ]

                Nothing ->
                    -- No grid for this season, so no way to read its classes.
                    -- Nothing is asked for.
                    Effect.none
            )


{-| The race read where playback has got to.
-}
snapshotOf : Replay.Model -> Snapshot
snapshotOf { race, playback } =
    Snapshot.at { elapsed = Clock.getElapsed playback } race


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
                        { timeLimit = event.timeLimit }
                        carsWithLaps
            in
            ( { m
                | replay = replayNew
                , snapshot = snapshotOf replayNew

                -- Settled here, with the race, and not touched again until the
                -- next one loads.
                , track = Tracker.fromConfig event.track
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
