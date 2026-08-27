module Shared exposing
    ( Model, Race, RoundId
    , init, update, subscriptions
    , race, roundId, isPlaying
    )

{-| Application-wide state, preserved from the elm-pages version. The data is
loaded at runtime via `Http`, so no `BackendTask` is involved.

@docs Model, Race, RoundId
@docs init, update, subscriptions
@docs race, roundId, isPlaying

-}

import Data.Wec as Wec
import Data.Wec.Calendar as Calendar exposing (Calendar)
import Data.Wec.Laps as WecLaps
import Data.Wec.Manufacturer as Manufacturer exposing (Manufacturers)
import Dict
import Effect exposing (Effect)
import Http
import Motorsport.Chart.Tracker as Tracker
import Motorsport.Clock as Clock
import Motorsport.Race.Car as Car
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Replay as Replay
import Motorsport.Wec.Era as Era
import Shared.Msg exposing (Msg(..))



-- MODEL


{-| Everything about a round hangs off `Round` rather than sitting beside it,
so a half-loaded one cannot be read as a loaded one.
-}
type alias Model =
    { calendar : Calendar
    , manufacturers : Maybe Manufacturers
    , round : Round
    }


{-| `Waiting` is a URL that arrived before the files a round is read against
did. The calendar is what says where a round's own files are, and the
manufacturer table is what its cars are coloured from, so the request waits
rather than being guessed at.

`Loading` carries no `Race`, which is what stops the previous round's cars being
shown under this one's name.

-}
type Round
    = NoRound
    | Waiting { season : String, event : String }
    | Loading RoundId Partial
    | Loaded RoundId Race


{-| Known as soon as the calendar resolves the URL, so the name can be shown
while the files are still on their way.
-}
type alias RoundId =
    { season : Int
    , id : String
    , name : String
    }


{-| The two files arrive in either order, and a round needs both. Three cases
rather than a pair of `Maybe`s: having both is not a state, it is the move to
`Loaded`.
-}
type Partial
    = NothingYet
    | GotSummary Wec.Event
    | GotLaps (List WecLaps.RawLap)


{-| A loaded round, as the pages read it.

`track` is the one derived value kept rather than worked out where it is used:
everything else about a frame follows from `replay` and the clock, where the
track never moves once the data has loaded. `snapshot` is `replay` read at the
clock, cached because every view of a frame shares it.

-}
type alias Race =
    { replay : Replay.Model
    , snapshot : Snapshot
    , track : Tracker.Track
    }


{-| The calendar and the manufacturer table are asked for here rather than by
the pages that read them: they are the same two files whichever route the app
opened on, and a round reached by its URL still needs both.
-}
init : flags -> ( Model, Effect Msg )
init _ =
    ( { calendar = Calendar.empty, manufacturers = Nothing, round = NoRound }
    , Effect.sendCmd <|
        Cmd.batch
            [ Http.get
                { url = "/static/wec/index.json"
                , expect = Http.expectJson CalendarLoaded Calendar.decoder
                }
            , Http.get
                { url = "/static/manufacturers.json"
                , expect = Http.expectJson ManufacturersLoaded Manufacturer.decoder
                }
            ]
    )



-- QUERIES


{-| Answers while the round is still loading, which is why it is separate from
[`race`](#race).
-}
roundId : Model -> Maybe RoundId
roundId model =
    case model.round of
        Loading id _ ->
            Just id

        Loaded id _ ->
            Just id

        _ ->
            Nothing


{-| The round's data, once all of it has arrived.
-}
race : Model -> Maybe Race
race model =
    case model.round of
        Loaded _ loaded ->
            Just loaded

        _ ->
            Nothing


{-| Whether playback is running, which is the whole of what deciding about
animation frames takes. Asked here so that page does not reach through a race to
its clock for one constructor. `Page.Debug` still reaches for the elapsed time,
which is a value and not a question.

[`Clock`](Motorsport-Clock) leaves `Started` by itself when playback runs out, so
nothing here has to know how long the race was.

-}
isPlaying : Model -> Bool
isPlaying model =
    case race model |> Maybe.map (.replay >> .playback >> .state) of
        Just (Clock.Started _ _) ->
            True

        _ ->
            False



-- UPDATE


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    case msg of
        CalendarLoaded (Ok calendar) ->
            resumeWaitingRound { m | calendar = calendar }

        CalendarLoaded (Err _) ->
            ( m, Effect.none )

        ManufacturersLoaded result ->
            -- Holding the race back over its colours is worse than running it
            -- without them, so a table that could not be read names no one and
            -- the cars are told apart by their numbers.
            resumeWaitingRound
                { m | manufacturers = Just (Result.withDefault Dict.empty result) }

        FetchJson_Wec params ->
            resumeWaitingRound { m | round = Waiting params }

        JsonLoaded_Wec key (Ok summary) ->
            ( { m | round = arrived key (withSummary summary) m.round }, Effect.none )

        JsonLoaded_Wec _ (Err _) ->
            ( m, Effect.none )

        LapsLoaded_Wec key (Ok rawLaps) ->
            ( { m | round = arrived key (withLaps rawLaps) m.round }, Effect.none )

        LapsLoaded_Wec _ (Err _) ->
            ( m, Effect.none )

        ReplayMsg replayMsg ->
            ( { m | round = mapRace (stepReplay replayMsg) m.round }, Effect.none )


{-| Called from every side of the race between the URL, the calendar and the
manufacturer table, so whichever arrives last is the one that finds everything
it needs here.
-}
resumeWaitingRound : Model -> ( Model, Effect Msg )
resumeWaitingRound m =
    case ( m.round, m.manufacturers ) of
        ( Waiting params, Just manufacturers ) ->
            case Calendar.findRound params m.calendar of
                Nothing ->
                    ( m, Effect.none )

                Just ( season, round ) ->
                    let
                        id =
                            { season = season.season, id = round.id, name = round.name }
                    in
                    ( { m | round = Loading id NothingYet }
                    , case Era.fromSeason id.season of
                        Just era ->
                            Effect.sendCmd <|
                                Cmd.batch
                                    [ Http.get
                                        { url = round.summary
                                        , expect = Http.expectJson (JsonLoaded_Wec (keyOf id)) (Wec.eventDecoder era manufacturers)
                                        }
                                    , Http.get
                                        { url = round.laps
                                        , expect =
                                            Http.expectString
                                                (LapsLoaded_Wec (keyOf id)
                                                    << Result.andThen (WecLaps.fromJsonl >> Result.mapError Http.BadBody)
                                                )
                                        }
                                    ]

                        Nothing ->
                            -- No grid for this season, so no way to read its
                            -- classes. The name is shown and nothing is asked
                            -- for.
                            Effect.none
                    )

        _ ->
            ( m, Effect.none )


{-| Applies a file to the round that asked for it, and to no other. A response
naming any other round is one left over from a round already navigated away
from.
-}
arrived : { season : Int, id : String } -> (RoundId -> Partial -> Round) -> Round -> Round
arrived key step round =
    case round of
        Loading id partial ->
            if keyOf id == key then
                step id partial

            else
                round

        _ ->
            round


withSummary : Wec.Event -> RoundId -> Partial -> Round
withSummary summary id partial =
    case partial of
        GotLaps rawLaps ->
            Loaded id (raceFrom summary rawLaps)

        _ ->
            Loading id (GotSummary summary)


withLaps : List WecLaps.RawLap -> RoundId -> Partial -> Round
withLaps rawLaps id partial =
    case partial of
        GotSummary summary ->
            Loaded id (raceFrom summary rawLaps)

        _ ->
            Loading id (GotLaps rawLaps)


raceFrom : Wec.Event -> List WecLaps.RawLap -> Race
raceFrom summary rawLaps =
    let
        replay =
            summary.startingGrid.entries
                |> List.map Car.fromStartingGrid
                |> WecLaps.attach rawLaps
                |> Replay.fromCars { timeLimit = summary.timeLimit, finishedAt = summary.finishedAt }
    in
    { replay = replay
    , snapshot = snapshotOf replay
    , track = Tracker.fromConfig summary.track
    }


mapRace : (Race -> Race) -> Round -> Round
mapRace f round =
    case round of
        Loaded id loaded ->
            Loaded id (f loaded)

        _ ->
            round


stepReplay : Replay.Msg -> Race -> Race
stepReplay replayMsg loaded =
    let
        replayNew =
            Replay.update replayMsg loaded.replay
    in
    { loaded | replay = replayNew, snapshot = snapshotOf replayNew }


keyOf : RoundId -> { season : Int, id : String }
keyOf id =
    { season = id.season, id = id.id }


{-| The race read where playback has got to.
-}
snapshotOf : Replay.Model -> Snapshot
snapshotOf replay =
    Snapshot.at { elapsed = Clock.getElapsed replay.playback } replay.race



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
