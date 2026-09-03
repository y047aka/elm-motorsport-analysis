module Shared exposing
    ( Model, Race, RoundId, Catalogue(..), Problem(..)
    , init, update, subscriptions
    , race, roundId, isPlaying, problem
    )

{-| Application-wide state, preserved from the elm-pages version. The data is
loaded at runtime via `Http`, so no `BackendTask` is involved.

@docs Model, Race, RoundId, Catalogue, Problem
@docs init, update, subscriptions
@docs race, roundId, isPlaying, problem

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
    { calendar : Catalogue
    , manufacturers : Maybe Manufacturers
    , round : Round
    }


{-| The rounds there are, or the reason the app cannot say what they are. A
failure here is the whole app's: it is the only thing that knows a round
exists.
-}
type Catalogue
    = Arriving
    | Listed Calendar
    | Missing Http.Error


{-| Why a round the URL named is not being shown. A round that cannot arrive
has to say so: left as `Loading`, it is a page that waits for ever.
-}
type Problem
    = NotListed
    | NoClassGrid
    | LoadFailed Http.Error


{-| `Waiting` is a URL that arrived before the calendar or the manufacturer
table did. One says where a round's files are and the other what colours its
cars, so the request waits rather than being guessed at.

`Loading` carries no `Race`, which is what stops the previous round's cars being
shown under this one's name.

-}
type Round
    = NoRound
    | Waiting { season : String, event : String }
    | Loading RoundId Partial
    | Loaded RoundId Race
    | Unavailable { season : String, event : String } Problem


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
the pages that read them: they are the same files whichever route the app opened
on, and a round reached by its URL still needs both.
-}
init : flags -> ( Model, Effect Msg )
init _ =
    ( { calendar = Arriving, manufacturers = Nothing, round = NoRound }
    , Effect.sendCmd <|
        Cmd.batch
            [ Http.get
                { url = "/api/wec/index.json"
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


{-| Why nothing is being shown, when nothing is.
-}
problem : Model -> Maybe Problem
problem model =
    case model.round of
        Unavailable _ reason ->
            Just reason

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
            resumeWaitingRound { m | calendar = Listed calendar }

        CalendarLoaded (Err error) ->
            resumeWaitingRound { m | calendar = Missing error }

        ManufacturersLoaded result ->
            -- Unlike the calendar's, this failure does not hold the round
            -- back: a table that names no one leaves the cars their numbers.
            resumeWaitingRound
                { m | manufacturers = Just (Result.withDefault Dict.empty result) }

        FetchJson_Wec params ->
            resumeWaitingRound { m | round = Waiting params }

        JsonLoaded_Wec key (Ok summary) ->
            ( { m | round = arrived key (withSummary summary) m.round }, Effect.none )

        JsonLoaded_Wec key (Err error) ->
            ( { m | round = didNotArrive key error m.round }, Effect.none )

        LapsLoaded_Wec key (Ok rawLaps) ->
            ( { m | round = arrived key (withLaps rawLaps) m.round }, Effect.none )

        LapsLoaded_Wec key (Err error) ->
            ( { m | round = didNotArrive key error m.round }, Effect.none )

        ReplayMsg replayMsg ->
            ( { m | round = mapRace (stepReplay replayMsg) m.round }, Effect.none )


{-| Called as the URL, the calendar and the manufacturer table arrive, so
whichever is last is the one that finds everything it needs here.
-}
resumeWaitingRound : Model -> ( Model, Effect Msg )
resumeWaitingRound m =
    case ( m.round, m.manufacturers ) of
        ( Waiting params, Just manufacturers ) ->
            case m.calendar of
                Arriving ->
                    ( m, Effect.none )

                Missing error ->
                    ( { m | round = Unavailable params (LoadFailed error) }, Effect.none )

                Listed calendar ->
                    case Calendar.findRound params calendar of
                        Nothing ->
                            ( { m | round = Unavailable params NotListed }, Effect.none )

                        Just ( season, round ) ->
                            askFor params manufacturers { season = season.season, id = round.id, name = round.name } round m

        _ ->
            ( m, Effect.none )


askFor : { season : String, event : String } -> Manufacturers -> RoundId -> Calendar.Round -> Model -> ( Model, Effect Msg )
askFor params manufacturers id round m =
    case Era.fromSeason id.season of
        Nothing ->
            ( { m | round = Unavailable params NoClassGrid }, Effect.none )

        Just era ->
            ( { m | round = Loading id NothingYet }
            , Effect.sendCmd <|
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
            )


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


{-| The round the response was for, given up on. A response naming any other
round is left over from one already navigated away from, and is dropped by
`arrived` as a late success is.
-}
didNotArrive : { season : Int, id : String } -> Http.Error -> Round -> Round
didNotArrive key error round =
    arrived key
        (\id _ -> Unavailable { season = String.fromInt id.season, event = id.id } (LoadFailed error))
        round


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
