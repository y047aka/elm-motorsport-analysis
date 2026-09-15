module Shared exposing
    ( Model, LoadedRound, RoundId, Catalogue(..), Problem(..)
    , init, update, subscriptions
    , loadedRound, roundId, isPlaying, problem
    )

{-| Application-wide state, preserved from the elm-pages version. The data is
loaded at runtime via `Http`, so no `BackendTask` is involved.

@docs Model, LoadedRound, RoundId, Catalogue, Problem
@docs init, update, subscriptions
@docs loadedRound, roundId, isPlaying, problem

-}

import Data.Wec as Wec
import Data.Wec.Calendar as Calendar exposing (Calendar)
import Data.Wec.CarImage as CarImage exposing (CarImages)
import Data.Wec.Laps as WecLaps
import Data.Wec.Manufacturer as Manufacturer exposing (Manufacturers)
import Dict
import Effect exposing (Effect)
import Http
import Motorsport.Chart.Tracker as Tracker
import Motorsport.Clock as Clock
import Motorsport.Race.Car as Car
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (TimelineEvent)
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
    , carImages : Maybe CarImages
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


{-| Why a round the URL named is not being shown. A round left as `Loading`
instead is a page that waits for ever.
-}
type Problem
    = NotListed
    | NoClassGrid
    | LoadFailed Http.Error


{-| `Waiting` is a URL that arrived before the calendar or one of the two tables
did. The calendar says where a round's files are, and the tables what colours
its cars and which photograph each carries, so the request waits rather than
being guessed at.

`Loading` carries no `LoadedRound`, which is what stops the previous round's
cars being shown under this one's name.

-}
type Round
    = NoRound
    | Waiting { season : String, event : String }
    | Loading RoundId Partial
    | Loaded RoundId LoadedRound
    | Unavailable { season : String, event : String } Problem


{-| Known as soon as the calendar resolves the URL, so the name can be shown
while the files are still on their way.
-}
type alias RoundId =
    { season : Int
    , id : String
    , name : String
    }


{-| How far a round has got: what it is still waiting on, and what has come
along beside it.
-}
type alias Partial =
    { files : Files
    , timeline : Maybe (List TimelineEvent)
    }


{-| The summary and the laps, which arrive in either order and are what a round
is. Three cases rather than a pair of `Maybe`s: having both is not a state, it is
the move to `Loaded`.

The timeline is not one of the two and gates nothing, so it stays the `Maybe` it
looks like: a fraction of the size of the laps, it commonly arrives before there
is a round to put it on, and is kept until there is.

-}
type Files
    = NothingYet
    | GotSummary Wec.Event
    | GotLaps (List WecLaps.RawLap)


nothingYet : Partial
nothingYet =
    { files = NothingYet, timeline = Nothing }


{-| A loaded round, as the pages read it: the race, the playback head over it,
and the derived values worth keeping rather than working out where they are
used.

The race itself is `replay.race`, a [`Motorsport.Race`](Motorsport-Race). This
is the round around it -- what the app holds in order to draw one -- which is
why it is not called a race. A `Race` answers what is true at a moment of it,
and none of the four fields here does.

`track` never moves once the data has loaded. `snapshot` is `replay` read at the
clock, cached because every view of a frame shares it, and the one of the four
that is rebuilt as playback runs.

`timeline` is the events themselves, kept for the events table to read the clock
against, and the only one of the four a round can go without: nothing playback
reads is counted off them.

It is the round's report rather than everything the file holds -- see
[`reported`](#reported).

-}
type alias LoadedRound =
    { replay : Replay.Model
    , snapshot : Snapshot
    , track : Tracker.Track
    , timeline : Timeline
    }


{-| The calendar, the manufacturer table and the car images are asked for here
rather than by the pages that read them: they are the same files whichever route
the app opened on, and a round reached by its URL still draws on all three.
-}
init : flags -> ( Model, Effect Msg )
init _ =
    ( { calendar = Arriving, manufacturers = Nothing, carImages = Nothing, round = NoRound }
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
            , Http.get
                { url = "/static/car-images.json"
                , expect = Http.expectJson CarImagesLoaded CarImage.decoder
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
loadedRound : Model -> Maybe LoadedRound
loadedRound model =
    case model.round of
        Loaded _ loaded ->
            Just loaded

        _ ->
            Nothing


{-| Whether playback is running, which is the whole of what deciding about
animation frames takes. Asked here so that page does not reach through a race to
its clock for one constructor.

[`Clock`](Motorsport-Clock) leaves `Started` by itself when playback runs out, so
nothing here has to know how long the race was.

-}
isPlaying : Model -> Bool
isPlaying model =
    case loadedRound model |> Maybe.map (.replay >> .playback >> .state) of
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

        CarImagesLoaded result ->
            -- As above: a table that has no picture of a car leaves it drawn
            -- without one.
            resumeWaitingRound
                { m | carImages = Just (Result.withDefault CarImage.none result) }

        FetchJson_Wec params ->
            resumeWaitingRound { m | round = Waiting params }

        JsonLoaded_Wec key (Ok summary) ->
            ( { m | round = forRound key (withSummary summary) m.round }, Effect.none )

        JsonLoaded_Wec key (Err error) ->
            ( { m | round = didNotArrive key error m.round }, Effect.none )

        LapsLoaded_Wec key (Ok rawLaps) ->
            ( { m | round = forRound key (withLaps rawLaps) m.round }, Effect.none )

        LapsLoaded_Wec key (Err error) ->
            ( { m | round = didNotArrive key error m.round }, Effect.none )

        TimelineLoaded_Wec key (Ok events) ->
            ( { m | round = timelineArrived key events m.round }, Effect.none )

        TimelineLoaded_Wec _ (Err _) ->
            -- The events table goes without rather than the round: a page draws
            -- every other part of one from the summary and the laps.
            ( m, Effect.none )

        ReplayMsg replayMsg ->
            ( { m | round = mapLoaded (stepReplay replayMsg) m.round }, Effect.none )


{-| Called as the URL, the calendar and the two tables arrive, so whichever is
last is the one that finds everything it needs here.
-}
resumeWaitingRound : Model -> ( Model, Effect Msg )
resumeWaitingRound m =
    case ( m.round, m.manufacturers, m.carImages ) of
        ( Waiting params, Just manufacturers, Just carImages ) ->
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
                            let
                                id =
                                    { season = season.season, id = round.id, name = round.name }
                            in
                            askFor params manufacturers (photographIn carImages id) id round m

        _ ->
            ( m, Effect.none )


{-| Where each car of a round has its photograph, which the cars are read
against as they decode, the way the manufacturer table colours them.
-}
photographIn : CarImages -> RoundId -> Car.CarNumber -> Maybe String
photographIn carImages id carNumber =
    CarImage.url carImages { season = id.season, round = id.id, carNumber = carNumber }


askFor : { season : String, event : String } -> Manufacturers -> (Car.CarNumber -> Maybe String) -> RoundId -> Calendar.Round -> Model -> ( Model, Effect Msg )
askFor params manufacturers carImageUrl id round m =
    case Era.fromSeason id.season of
        Nothing ->
            ( { m | round = Unavailable params NoClassGrid }, Effect.none )

        Just era ->
            ( { m | round = Loading id nothingYet }
            , Effect.sendCmd <|
                Cmd.batch
                    [ Http.get
                        { url = round.summary
                        , expect = Http.expectJson (JsonLoaded_Wec (keyOf id)) (Wec.eventDecoder era manufacturers carImageUrl)
                        }
                    , Http.get
                        { url = round.laps
                        , expect = expectJsonl (LapsLoaded_Wec (keyOf id)) WecLaps.fromJsonl
                        }
                    , Http.get
                        { url = round.timeline
                        , expect = expectJsonl (TimelineLoaded_Wec (keyOf id)) TimelineEvent.fromJsonl
                        }
                    ]
            )


{-| A body read a line at a time, and a line that would not read answered as the
round's own failure rather than as a round with fewer records in it.
-}
expectJsonl : (Result Http.Error (List a) -> msg) -> (String -> Result String (List a)) -> Http.Expect msg
expectJsonl toMsg fromJsonl =
    Http.expectString (toMsg << Result.andThen (fromJsonl >> Result.mapError Http.BadBody))


{-| Applies a file to the round that asked for it, and to no other. A response
naming any other round is one left over from a round already navigated away
from.
-}
forRound : { season : Int, id : String } -> (RoundId -> Partial -> Round) -> Round -> Round
forRound key step round =
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
    case partial.files of
        GotLaps rawLaps ->
            Loaded id (roundFrom summary rawLaps (eventsOf partial))

        _ ->
            Loading id { partial | files = GotSummary summary }


withLaps : List WecLaps.RawLap -> RoundId -> Partial -> Round
withLaps rawLaps id partial =
    case partial.files of
        GotSummary summary ->
            Loaded id (roundFrom summary rawLaps (eventsOf partial))

        _ ->
            Loading id { partial | files = GotLaps rawLaps }


eventsOf : Partial -> List TimelineEvent
eventsOf partial =
    Maybe.withDefault [] partial.timeline


{-| The timeline, which can land either side of the round being made, so it is
not `forRound`'s: the round it is for may already have loaded.
-}
timelineArrived : { season : Int, id : String } -> List TimelineEvent -> Round -> Round
timelineArrived key events round =
    case round of
        Loading id partial ->
            if keyOf id == key then
                Loading id { partial | timeline = Just events }

            else
                round

        Loaded id loaded ->
            if keyOf id == key then
                Loaded id { loaded | timeline = Timeline.fromList events }

            else
                round

        _ ->
            round


{-| The round the response was for, given up on. A response naming another is
dropped by `forRound`, as a late success is.
-}
didNotArrive : { season : Int, id : String } -> Http.Error -> Round -> Round
didNotArrive key error round =
    forRound key
        (\id _ -> Unavailable { season = String.fromInt id.season, event = id.id } (LoadFailed error))
        round


roundFrom : Wec.Event -> List WecLaps.RawLap -> List TimelineEvent -> LoadedRound
roundFrom summary rawLaps timelineEvents =
    let
        replay =
            summary.startingGrid.entries
                |> List.map Car.fromStartingGrid
                |> WecLaps.attach rawLaps
                |> Replay.fromCars
                    { timeLimit = summary.timeLimit
                    , finishedAt = summary.finishedAt
                    , index = summary.index
                    }
    in
    { replay = replay
    , snapshot = snapshotOf replay
    , track = Tracker.fromConfig summary.track
    , timeline = Timeline.fromList timelineEvents
    }


mapLoaded : (LoadedRound -> LoadedRound) -> Round -> Round
mapLoaded f round =
    case round of
        Loaded id loaded ->
            Loaded id (f loaded)

        _ ->
            round


stepReplay : Replay.Msg -> LoadedRound -> LoadedRound
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
