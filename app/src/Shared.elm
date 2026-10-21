module Shared exposing
    ( Model, LoadedRound, RoundId, Catalogue(..), Problem(..)
    , init, update, subscriptions
    , loadedRound, roundId, isPlaying, problem
    )

{-| Application-wide state.

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
import Json.Decode exposing (Decoder)
import Motorsport.Chart.Tracker as Tracker
import Motorsport.Clock as Clock
import Motorsport.Race.Car as Car
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (TimelineEvent)
import Motorsport.Replay as Replay
import Motorsport.Wec.Circuit.Cota.Layout as CotaLayout
import Motorsport.Wec.Circuit.Geometry as Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.LeMans.Layout as LeMansLayout
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
    , geometry : Dict.Dict String Geometry
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
    , geometry : Awaited
    , timeline : Maybe (List TimelineEvent)
    }


{-| The summary and the laps, which arrive in either order and are what a round
is. A round whose circuit has a drawing here waits on a third file -- its
geometry -- so having both of these is a state rather than the move to `Loaded`,
and is held as `GotBoth` until that one arrives.

The timeline is not one of the three and gates nothing, so it stays the `Maybe` it
looks like: a fraction of the size of the laps, it commonly arrives before there
is a round to put it on, and is kept until there is.

-}
type Files
    = NothingYet
    | GotSummary Wec.Event
    | GotLaps (List WecLaps.RawLap)
    | GotBoth Wec.Event (List WecLaps.RawLap)


{-| The geometry a circuit is drawn from, or how far waiting for it has got.
`Unnamed` is a summary that named no circuit and `Undrawn` one this app draws
as the ring; neither has a file to wait for.
-}
type Awaited
    = Unnamed
    | Undrawn
    | Fetching String
    | Decoded Geometry


nothingYet : Partial
nothingYet =
    { files = NothingYet, geometry = Unnamed, timeline = Nothing }


{-| A loaded round, as the pages read it. The race itself is `replay.race`, a
[`Motorsport.Race`](Motorsport-Race).

`track` never moves once the data has loaded. `snapshot` is `replay` read at the
clock, cached because every view of a frame shares it, and the one of them
rebuilt as playback runs.

`timeline` is the events themselves, kept for the events table to read the clock
against, and the only one of them a round can go without: nothing playback reads
is counted off them.

`fieldEvents` is those of them the tracker's column draws, held apart rather
than read off `timeline` on the way: those rows are built behind a `Html.Lazy`
thunk, and a timeline made afresh on a frame is a new reference on every one.

-}
type alias LoadedRound =
    { replay : Replay.Model
    , snapshot : Snapshot
    , track : Tracker.Track
    , timeline : Timeline
    , fieldEvents : Timeline
    }


{-| The calendar, the manufacturer table and the car images are asked for here
rather than by the pages that read them: they are the same files whichever route
the app opened on, and a round reached by its URL still draws on all three.
-}
init : flags -> ( Model, Effect Msg )
init _ =
    ( { calendar = Arriving, manufacturers = Nothing, carImages = Nothing, geometry = Dict.empty, round = NoRound }
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


{-| Answers while the round is still loading, unlike
[`loadedRound`](#loadedRound).
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


{-| Whether playback is running. [`Clock`](Motorsport-Clock) leaves `Started` by
itself when playback runs out, so nothing here has to know how long the race
was.
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
            case awaiting summary m.geometry of
                ( awaited, Just circuit ) ->
                    ( { m | round = forRound key (withSummary summary awaited) m.round }
                    , Effect.sendCmd (getGeometry key circuit)
                    )

                ( awaited, Nothing ) ->
                    ( { m | round = forRound key (withSummary summary awaited) m.round }, Effect.none )

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

        GeometryLoaded key circuit (Ok geometry) ->
            ( { m | geometry = Dict.insert circuit geometry m.geometry, round = forRound key (geometryArrived circuit geometry) m.round }, Effect.none )

        GeometryLoaded key _ (Err error) ->
            -- A drawn round fails rather than falling back to the ring: a
            -- round drawn as a ring is a wrong drawing read back as a round
            -- that loaded.
            ( { m | round = didNotArrive key error m.round }, Effect.none )

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


withSummary : Wec.Event -> Awaited -> RoundId -> Partial -> Round
withSummary summary awaited id partial =
    arriving id { partial | files = bothWith summary partial.files, geometry = awaited }


withLaps : List WecLaps.RawLap -> RoundId -> Partial -> Round
withLaps rawLaps id partial =
    arriving id { partial | files = bothWithLaps rawLaps partial.files }


bothWith : Wec.Event -> Files -> Files
bothWith summary files =
    case files of
        GotLaps rawLaps ->
            GotBoth summary rawLaps

        _ ->
            GotSummary summary


bothWithLaps : List WecLaps.RawLap -> Files -> Files
bothWithLaps rawLaps files =
    case files of
        GotSummary summary ->
            GotBoth summary rawLaps

        _ ->
            GotLaps rawLaps


{-| A round is made once its files are here and its geometry is settled --
decoded, or not wanted. Whichever of them arrives last finds the others.
-}
arriving : RoundId -> Partial -> Round
arriving id partial =
    case partial.files of
        GotBoth summary rawLaps ->
            case partial.geometry of
                Fetching _ ->
                    Loading id partial

                _ ->
                    Loaded id (roundFrom id summary rawLaps (eventsOf partial) partial.geometry)

        _ ->
            Loading id partial


geometryArrived : String -> Geometry -> RoundId -> Partial -> Round
geometryArrived circuit geometry id partial =
    case partial.geometry of
        Fetching asked ->
            if asked == circuit then
                arriving id { partial | geometry = Decoded geometry }

            else
                Loading id partial

        _ ->
            Loading id partial


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
                Loaded id { loaded | timeline = Timeline.fromList events, fieldEvents = fieldEventsOf events }

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


fieldEventsOf : List TimelineEvent -> Timeline
fieldEventsOf events =
    events
        |> List.filter (\event -> TimelineEvent.forField event.eventType)
        |> Timeline.fromList


roundFrom : RoundId -> Wec.Event -> List WecLaps.RawLap -> List TimelineEvent -> Awaited -> LoadedRound
roundFrom id summary rawLaps timelineEvents geometry =
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
    , track = trackOf id summary.track geometry
    , timeline = Timeline.fromList timelineEvents
    , fieldEvents = fieldEventsOf timelineEvents
    }


{-| Which drawing of a circuit the round is put in, by the circuit the summary
names for it -- `Motorsport.Events.circuit`. The round id is still asked for,
because which lines Le Mans is drawn with turns on the season.

A circuit this app has no drawing of is drawn as the ring -- clockwise, the
way a circuit whose ground is unknown may always be imagined to run -- which is
the shape the proportions the summary carries can describe; so is a round
exported before the summary named its circuit. A circuit that has a drawing and
whose geometry is not here falls to the ring too: the load gates on the
geometry, so reaching this arm means a gate was opened elsewhere.

-}
trackOf : RoundId -> Wec.Track -> Awaited -> Tracker.Track
trackOf id track geometry =
    case track.circuit of
        Just "le_mans" ->
            case geometry of
                Decoded lap ->
                    Tracker.onCircuit (LeMansLayout.layout id.season lap) { direction = lap.direction, config = track.config }

                _ ->
                    Tracker.fromConfig track.config

        Just "cota" ->
            case geometry of
                Decoded lap ->
                    Tracker.onCircuit (CotaLayout.layout lap) { direction = lap.direction, config = track.config }

                _ ->
                    Tracker.fromConfig track.config

        _ ->
            Tracker.fromConfig track.config


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


{-| Whether the summary's circuit wants its geometry -- from the cache if it is
already in one, from `/static/geometry/` if it is not -- or wants nothing, being
a circuit with no decoder here.
-}
awaiting : Wec.Event -> Dict.Dict String Geometry -> ( Awaited, Maybe String )
awaiting summary cache =
    case summary.track.circuit of
        Just circuit ->
            case decoderFor circuit of
                Nothing ->
                    ( Undrawn, Nothing )

                Just _ ->
                    case Dict.get circuit cache of
                        Just geometry ->
                            ( Decoded geometry, Nothing )

                        Nothing ->
                            ( Fetching circuit, Just circuit )

        Nothing ->
            ( Unnamed, Nothing )


{-| Which circuits are drawn to their own shape: one word, one decoder.
`trackOf` matches the same words; `geometry-contract.spec.ts` keeps them in
step.
-}
decoderFor : String -> Maybe (Decoder Geometry)
decoderFor circuit =
    case circuit of
        "cota" ->
            Just CotaLayout.decoder

        "le_mans" ->
            Just LeMansLayout.decoder

        _ ->
            Nothing


{-| The geometry a drawn circuit reads itself from, at the same URL pattern the
manufacturer table uses, named by the word the summary sends for it.
-}
getGeometry : { season : Int, id : String } -> String -> Cmd Msg
getGeometry key circuit =
    case decoderFor circuit of
        Just decoder ->
            Http.get
                { url = "/static/geometry/" ++ circuit ++ ".geojson"
                , expect = Http.expectJson (GeometryLoaded key circuit) decoder
                }

        Nothing ->
            Cmd.none


{-| The race read where playback has got to.
-}
snapshotOf : Replay.Model -> Snapshot
snapshotOf replay =
    Snapshot.at { elapsed = Clock.getElapsed replay.playback } replay.race



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
