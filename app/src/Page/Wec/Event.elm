module Page.Wec.Event exposing (Model, Msg, init, subscriptions, update, view)

{-| WEC event page (`/wec/:season/:event`). Route parameters are passed into
`init` by `Main`.

@docs Model, Msg, init, subscriptions, update, view

-}

import Browser.Events
import Dict exposing (Dict)
import Effect exposing (Effect)
import Html exposing (Html, a, button, div, main_, nav, span, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Events exposing (onClick)
import Html.Keyed
import Html.Lazy
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap
import Motorsport.Leaderboard as Leaderboard
import Motorsport.Position exposing (Position)
import Motorsport.Race.Car exposing (Car, CarNumber, Metadata)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Motorsport.Replay as Replay
import Motorsport.Wec.Class as Class
import Route
import Shared
import Shared.Msg
import Task
import Time
import UI.Notice as Notice
import UI.Shadcn.Card as Card
import UI.Shadcn.ToggleGroup as ToggleGroup
import View exposing (View)
import View.CarCardList as CarCardList
import View.CarDetail as CarDetail
import View.CarNumberBadge as CarNumberBadge
import View.LiveStandings as LiveStandings
import View.PlaybackControls as PlaybackControls



-- MODEL


type alias Model =
    { mode : Mode
    , standingsTab : StandingsTab
    , leaderboardState : Leaderboard.Model
    , columns : CarColumns
    , comparison : CarDetail.Comparison
    }


type Mode
    = Columns
    | Tracker


{-| `ClassLeaders` is the car at the front of each class, re-read from the
snapshot as the race runs. `Picked` is fixed, in the order the reader asked for
them, and any open or close settles the stand-ins into one.
-}
type CarColumns
    = ClassLeaders
    | Picked CarNumber (List CarNumber)


type StandingsTab
    = LeaderboardTab
    | CardsTab


init : { season : String, event : String } -> ( Model, Effect Msg )
init params =
    ( { mode = Columns
      , standingsTab = LeaderboardTab
      , leaderboardState = Leaderboard.init
      , columns = ClassLeaders
      , comparison = CarDetail.initialComparison
      }
    , Effect.sendSharedMsg (Shared.Msg.FetchJson_Wec { season = params.season, event = params.event })
    )



-- UPDATE


type Msg
    = StartRace
    | PauseRace
    | ModeChange Mode
    | StandingsTabChange StandingsTab
    | ReplayMsg Replay.Msg
    | LeaderboardMsg Leaderboard.Msg
    | OpenColumn CarNumber
    | CloseColumn CarNumber
    | CarDetailMsg CarDetail.Msg


update : Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update shared msg m =
    case msg of
        StartRace ->
            ( m, Task.perform (Replay.Start >> ReplayMsg) Time.now |> Effect.sendCmd )

        PauseRace ->
            ( m, Task.perform (Replay.Pause >> ReplayMsg) Time.now |> Effect.sendCmd )

        ModeChange mode ->
            ( { m | mode = mode }, Effect.none )

        StandingsTabChange tab ->
            ( { m | standingsTab = tab }, Effect.none )

        ReplayMsg replayMsg ->
            ( m, Effect.sendSharedMsg (Shared.Msg.ReplayMsg replayMsg) )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            )

        OpenColumn carNumber ->
            ( { m | columns = rearrange shared (openColumn carNumber) m.columns }, Effect.none )

        CloseColumn carNumber ->
            ( { m | columns = rearrange shared (closeColumn carNumber) m.columns }, Effect.none )

        CarDetailMsg detailMsg ->
            ( { m | comparison = CarDetail.update detailMsg m.comparison }, Effect.none )


rearrange : Shared.Model -> (Snapshot -> CarColumns -> CarColumns) -> CarColumns -> CarColumns
rearrange shared f columns =
    case Shared.loadedRound shared of
        Just round ->
            f round.snapshot columns

        Nothing ->
            columns


{-| There is no ceiling on how many, and each column draws its own charts on
every frame of playback.
-}
openColumn : CarNumber -> Snapshot -> CarColumns -> CarColumns
openColumn carNumber snapshot columns =
    let
        current =
            columnCarNumbers snapshot columns
    in
    if List.member carNumber current then
        columns

    else
        pickedOr columns (current ++ [ carNumber ])


closeColumn : CarNumber -> Snapshot -> CarColumns -> CarColumns
closeColumn carNumber snapshot columns =
    columnCarNumbers snapshot columns
        |> List.filter ((/=) carNumber)
        |> pickedOr columns


pickedOr : CarColumns -> List CarNumber -> CarColumns
pickedOr fallback carNumbers =
    case carNumbers of
        [] ->
            fallback

        first :: rest ->
            Picked first rest



-- SUBSCRIPTIONS


subscriptions : Shared.Model -> Model -> Sub Msg
subscriptions shared _ =
    if Shared.isPlaying shared then
        Browser.Events.onAnimationFrame (Replay.Tick >> ReplayMsg)

    else
        Sub.none



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared m =
    let
        maybeRound =
            Shared.loadedRound shared
    in
    { title = "Wec"
    , body =
        [ main_
            [ Attributes.class "dark h-full grid grid-rows-[auto_1fr]"
            ]
            [ navigation (headerTitle shared) maybeRound
            , case maybeRound of
                Nothing ->
                    -- Named but not loaded. Nothing is drawn rather than the
                    -- round before it.
                    div [ Attributes.class "row-start-2" ] [ unavailable shared ]

                Just round ->
                    trackerView round.track
                        round.timeline
                        round.snapshot
                        round.replay
                        m
            ]
        ]
    }


{-| Nothing while a round is on its way, and why once it is not coming.
-}
unavailable : Shared.Model -> Html Msg
unavailable shared =
    case Shared.problem shared of
        Nothing ->
            text ""

        Just Shared.NotListed ->
            Notice.view
                { headline = "No such round."
                , detail = "The calendar does not list this season and event."
                }

        Just Shared.NoClassGrid ->
            Notice.view
                { headline = "This season cannot be read yet."
                , detail = "There is no class grid for it, so its cars have no classes to be put in."
                }

        Just (Shared.LoadFailed error) ->
            Notice.view
                { headline = "The round could not be loaded."
                , detail = Notice.httpError error
                }


headerTitle : Shared.Model -> String
headerTitle shared =
    Shared.roundId shared
        |> Maybe.map (\round -> round.name ++ " (" ++ String.fromInt round.season ++ ")")
        |> Maybe.withDefault ""


trackerView : TrackerChart.Track -> Timeline -> Snapshot -> Replay.Model -> Model -> Html Msg
trackerView track timeline snapshot replay m =
    let
        -- The standings are marked from this and not from `layout.shown`,
        -- which the tracker empties.
        carsWithColumns =
            shownCars snapshot m.columns

        layout =
            case m.mode of
                Tracker ->
                    { tracker = "col-start-2 row-start-1 row-span-2"
                    , trackerDetail = TrackerChart.Full
                    , onTracker = ModeChange Columns
                    , detail = "col-start-3 row-start-1"
                    , shown = []
                    }

                Columns ->
                    { tracker = "col-start-3 row-start-1"
                    , trackerDetail = TrackerChart.Compact
                    , onTracker = ModeChange Tracker
                    , detail = "col-start-2 row-start-1 row-span-2"
                    , shown = carsWithColumns
                    }
    in
    div
        [ Attributes.class "row-start-2 h-full overflow-y-auto p-[0_10px_10px_10px] flex flex-col gap-2.5" ]
        [ div
            [ Attributes.class "shrink-0 h-full grid grid-cols-[218px_1fr_300px] grid-rows-[300px_minmax(0,1fr)] gap-2.5" ]
            [ div
                [ Attributes.class "col-start-1 row-start-1 row-span-2 h-full overflow-y-hidden" ]
                [ LiveStandings.view
                    { onSelect = OpenColumn
                    , withColumns = List.map (.metadata >> .carNumber) carsWithColumns
                    }
                    snapshot
                ]
            , columnStrip layout.detail m replay snapshot layout.shown
            , div
                -- The cell is the only box in the chain whose height is settled,
                -- so a square SVG measured against the width overflows the card.
                [ Attributes.class (layout.tracker ++ " grid place-self-center h-full max-w-full aspect-square cursor-pointer")
                , onClick layout.onTracker
                ]
                [ Card.card []
                    [ Card.content []
                        [ div
                            [ Attributes.class "h-full grid place-items-center" ]
                            [ TrackerChart.view layout.trackerDetail track snapshot ]
                        ]
                    ]
                ]
            , timelinePanel "col-start-3 row-start-2" timeline replay
            ]
        , standingsPanel m.standingsTab m replay snapshot
        , standingsPopover
        ]


columnCarNumbers : Snapshot -> CarColumns -> List CarNumber
columnCarNumbers snapshot columns =
    case columns of
        ClassLeaders ->
            leaderOfEachClass snapshot |> List.map (.metadata >> .carNumber)

        Picked first rest ->
            first :: rest


shownCars : Snapshot -> CarColumns -> List CarAt
shownCars snapshot columns =
    columnCarNumbers snapshot columns
        |> List.filterMap (\carNumber -> Snapshot.get carNumber snapshot)


{-| The classes come in the order their leaders run in.
-}
leaderOfEachClass : Snapshot -> List CarAt
leaderOfEachClass snapshot =
    Snapshot.toClassList snapshot
        |> List.filterMap (Tuple.second >> List.head)


{-| A column is 360px, not a share of the cell. The widest thing in the panel is
the comparison's tab row, which wants 302px of the 328 a column of this width
hands it. The floor is 335, so the 26px over is what is left for a font that is
not the one this was measured in.
-}
columnStrip : String -> Model -> Replay.Model -> Snapshot -> List CarAt -> Html Msg
columnStrip cell m replay snapshot shown =
    let
        card =
            columnCard { closable = List.length shown > 1 } m replay snapshot
    in
    case shown of
        [] ->
            -- The tracker has the room, and before any car has turned a lap.
            div [ Attributes.class (cell ++ " grid") ] [ Card.card [] [] ]

        _ ->
            -- Keyed on the car: a column matched by position instead would hand
            -- how far the reader had scrolled it to whichever car moved up into
            -- its place when the one before it was closed.
            Html.Keyed.node "div"
                [ Attributes.class (cell ++ " flex gap-2.5 overflow-x-auto") ]
                (List.map
                    (\car ->
                        ( car.metadata.carNumber
                        , div [ Attributes.class "shrink-0 w-[360px] grid" ] [ card car ]
                        )
                    )
                    shown
                )


columnCard : { closable : Bool } -> Model -> Replay.Model -> Snapshot -> CarAt -> Html Msg
columnCard column m replay snapshot car =
    let
        carNumber =
            car.metadata.carNumber
    in
    Card.card []
        -- A card's content does not shrink below what it holds, so the box that
        -- scrolls has to be a flex child of the card.
        [ div [ Attributes.class "flex-1 min-h-0 overflow-y-auto" ]
            [ Card.content []
                [ CarDetail.view
                    { toMsg = CarDetailMsg
                    , onClose =
                        if column.closable then
                            Just (CloseColumn carNumber)

                        else
                            Nothing
                    , comparison = m.comparison
                    }
                    replay.race.cars
                    snapshot
                    car
                ]
            ]
        ]


standingsPanel : StandingsTab -> Model -> Replay.Model -> Snapshot -> Html Msg
standingsPanel tab m replay snapshot =
    let
        body =
            case tab of
                LeaderboardTab ->
                    Leaderboard.view (leaderboardConfig replay.race.cars) m.leaderboardState snapshot

                CardsTab ->
                    CarCardList.view snapshot
    in
    div [ Attributes.class "shrink-0 grid" ]
        [ Card.card []
            [ Card.header []
                [ Card.action [] [ standingsTabs tab ] ]
            , Card.content [] [ body ]
            ]
        ]


standingsTabs : StandingsTab -> Html Msg
standingsTabs current =
    let
        tabItem label tab =
            { label = label
            , active = current == tab
            , disabled = False
            , onSelect = StandingsTabChange tab
            }
    in
    ToggleGroup.view
        { items =
            [ tabItem "Table" LeaderboardTab
            , tabItem "Cards" CardsTab
            ]
        }
        []


{-| The most recent timeline events that have occurred, newest first: when each
happened, whose it was, and what kind of thing it was.
-}
timelinePanel : String -> Timeline -> Replay.Model -> Html Msg
timelinePanel cell timeline replay =
    let
        occurredCount =
            Timeline.countUpTo (Clock.getElapsed replay.playback) timeline
    in
    button
        [ attribute "popovertarget" standingsPopoverId
        , attribute "popovertargetaction" "show"
        , Attributes.class (cell ++ " grid min-h-0 cursor-pointer text-left")
        ]
        [ Card.card []
            [ div [ Attributes.class "flex-1 min-h-0 overflow-y-auto" ]
                [ Card.content []
                    [ Html.Lazy.lazy3 eventRows replay.race.cars timeline occurredCount ]
                ]
            ]
        ]


recentEventLimit : Int
recentEventLimit =
    100


{-| The panel's rows, rebuilt only when an event arrives. A thunk's arguments are
compared by `===`, so every one of these is held to something that survives a
frame: the cars and the timeline never move under playback, and the count is a
number. Anything frame-made passed instead -- a snapshot, or the cut list itself
-- is a fresh reference on every frame and misses.
-}
eventRows : List Car -> Timeline -> Int -> Html Msg
eventRows cars timeline occurredCount =
    let
        carsByNumber =
            cars
                |> List.map (\car -> ( car.metadata.carNumber, car ))
                |> Dict.fromList
    in
    Timeline.latest { upTo = occurredCount, limit = recentEventLimit } timeline
        |> List.map (eventRow carsByNumber)
        |> div [ Attributes.class "grid grid-cols-[auto_1fr_auto_auto] gap-x-2 text-xs" ]


{-| One row per event: its car's class, what it was, whose it was, when, and the
event's `detail` on a line of their own below, as wide as the row less the class.

A row is two lines whatever it holds, the first as tall as the badge: the
`1.375rem` is `CarNumberBadge.viewRow`'s height, and moves with it.

-}
eventRow : Dict CarNumber Car -> TimelineEvent -> Html Msg
eventRow carsByNumber event =
    let
        car =
            case event.eventType of
                CarEvent carNumber _ ->
                    Dict.get carNumber carsByNumber

                RaceStart ->
                    Nothing

        cell classes children =
            div [ Attributes.class classes ] children

        firstLine rows =
            [ cell "row-span-2 h-full" [ car |> Maybe.map (.metadata >> classBar) |> Maybe.withDefault (text "") ]
            , cell rows [ text (describe event.eventType) ]
            , cell rows [ carBadge car event.eventType ]
            , cell ("whitespace-nowrap text-right tabular-nums text-muted-foreground " ++ rows)
                [ text (event.elapsed |> Instant.toDuration |> Duration.toStringToSeconds) ]
            ]
    in
    div [ Attributes.class "col-span-4 grid grid-cols-subgrid grid-rows-[1.375rem_1rem] gap-y-1 items-center py-0.5" ]
        (case detail car event of
            Just line ->
                firstLine ""
                    ++ [ cell "col-start-2 col-span-3 whitespace-nowrap text-[10px] text-muted-foreground" [ text line ] ]

            Nothing ->
                firstLine "row-span-2"
        )


{-| The class of the car the event was, in the colour the standings' class headings
carry, since a lead is its class's, and as tall as the row.
-}
classBar : Metadata -> Html Msg
classBar metadata =
    div
        [ Attributes.class "flex h-full before:block before:content-[''] before:w-[0.2em] before:h-full before:rounded-[2px] before:[background-color:var(--class-color)]"
        , attribute "style" ("--class-color: " ++ Class.toColor metadata.class ++ ";")
        ]
        []


{-| Whose event this was, badged like the standings badge it sits beside. A race
start belongs to nobody, and a number no car of the field answers to keeps its
bare digits rather than vanishing.
-}
carBadge : Maybe Car -> EventType -> Html Msg
carBadge car eventType =
    case ( car, eventType ) of
        ( Just { metadata }, _ ) ->
            CarNumberBadge.viewRow metadata

        ( Nothing, CarEvent carNumber _ ) ->
            span [] [ text carNumber ]

        ( Nothing, RaceStart ) ->
            text ""


describe : EventType -> String
describe eventType =
    case eventType of
        RaceStart ->
            "Race Start"

        CarEvent _ OvertakeForLead ->
            "Overtake for Lead"

        CarEvent _ LeaderInPit ->
            "Leader In Pit"

        CarEvent _ FastestLap ->
            "Fastest Lap"

        CarEvent _ DriverChange ->
            "Driver Change"

        CarEvent _ Retired ->
            "Retired"

        CarEvent _ Finished ->
            "Finished"


{-| The second line an event has, read off the car's laps at the event.

A fastest lap is the lap the event completes, its time and its driver. A driver
change is who handed the car to whom: the driver of the lap the event completes,
and the one of the lap in progress from it, which is the lap the car's
`currentDriver` is read off from then on.

-}
detail : Maybe Car -> TimelineEvent -> Maybe String
detail car event =
    let
        lapOf find =
            car |> Maybe.andThen (.laps >> find { elapsed = event.elapsed })

        driverOf find =
            lapOf find |> Maybe.map (.driver >> Driver.toInitialAndSurname)
    in
    case event.eventType of
        CarEvent _ FastestLap ->
            lapOf Lap.findLastLapAt
                |> Maybe.andThen
                    (\lap ->
                        lap.time
                            |> Maybe.map (\time -> Duration.toString time ++ " · " ++ Driver.toInitialAndSurname lap.driver)
                    )

        CarEvent _ DriverChange ->
            Maybe.map2 (\handedOver tookOver -> handedOver ++ " → " ++ tookOver)
                (driverOf Lap.findLastLapAt)
                (driverOf Lap.findCurrentLap)

        _ ->
            Nothing


leaderboardConfig : List Car -> Leaderboard.Config CarAt Msg
leaderboardConfig cars =
    let
        -- Worked out once rather than per row: the table is rebuilt on every
        -- frame of playback.
        startPositions : Dict CarNumber Position
        startPositions =
            -- foldr, so that where the source data has two cars under one
            -- number the one running ahead wins, as in `Snapshot.get`.
            cars
                |> List.foldr (\car -> Dict.insert car.metadata.carNumber car.startPosition) Dict.empty

        startPositionOf : CarAt -> Maybe Position
        startPositionOf item =
            Dict.get item.metadata.carNumber startPositions
    in
    { toId = .metadata >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ Leaderboard.carNumberColumn_Wec { getter = .metadata }
        , Leaderboard.driverAndTeamColumn_Wec
            { getter = \item -> { metadata = item.metadata, currentDriver = item.currentDriver } }
        , Leaderboard.positionChangeColumn
            { getter = \item -> { startPosition = startPositionOf item, position = item.standing.position } }
        , Leaderboard.intColumn { label = "Lap", getter = .standing >> .lapsCompleted }
        , Leaderboard.customColumn
            { label = "Gap"
            , getter = .standing >> .gapToLeader >> Gap.toString
            }
        , Leaderboard.customColumn
            { label = "Interval"
            , getter = .standing >> .intervalToAhead >> Gap.toString
            }
        , Leaderboard.currentLapColumn_Wec { getter = identity }
        , Leaderboard.lastLapColumn_Wec { getter = .lastLap }
        , Leaderboard.bestTimeColumn { getter = .bestLap }
        , Leaderboard.intColumn { label = "Stops", getter = .pitStops }
        ]
    }


standingsPopoverId : String
standingsPopoverId =
    "standings-popover"


standingsPopover : Html Msg
standingsPopover =
    Html.node "div"
        [ Attributes.id standingsPopoverId
        , attribute "popover" "auto"

        -- Tailwind preflight cancels the UA's margin:auto, so set it explicitly to center.
        -- The popover has no containing block to size against but the viewport,
        -- so its width is set explicitly rather than left to shrink to content.
        , Attributes.class "m-auto w-11/12 max-w-[min(90vw,1200px)] p-4 rounded-xl overflow-y-auto max-h-screen"
        , Attributes.class "bg-popover text-popover-foreground backdrop-blur-lg border border-border shadow-glass"

        -- A closed popover is display:none by the UA, but its entrance
        -- transition still needs an explicit closed state to animate from.
        , Attributes.class "opacity-0 scale-95 transition-[opacity,scale] duration-200 [&:popover-open]:opacity-100 [&:popover-open]:scale-100"
        , Attributes.class "backdrop:bg-black/10"
        ]
        [ button
            [ attribute "popovertarget" standingsPopoverId
            , attribute "popovertargetaction" "hide"
            , Attributes.class "inline-flex items-center justify-center size-8 rounded-full text-sm cursor-pointer transition-colors hover:bg-accent hover:text-accent-foreground absolute right-2 top-2"
            ]
            [ text "✕" ]
        ]


navigation : String -> Maybe Shared.LoadedRound -> Html Msg
navigation title maybeRound =
    nav
        [ Attributes.class "p-3 grid grid-cols-[auto_1fr] items-center gap-x-10" ]
        [ div [ Attributes.class "flex items-center gap-2 whitespace-nowrap" ]
            [ backLink
            , div [ Attributes.class "text-sm" ] [ text title ]
            ]
        , case maybeRound of
            Nothing ->
                text ""

            Just round ->
                PlaybackControls.view
                    { replay = round.replay
                    , onStart = StartRace
                    , onPause = PauseRace
                    , toReplayMsg = ReplayMsg
                    }
        ]


{-| The app ships as a native window without browser back navigation, so the race
list has to be reachable from the page itself.
-}
backLink : Html Msg
backLink =
    a
        [ Route.href Route.Index
        , Attributes.class "inline-flex items-center justify-center size-8 rounded-md cursor-pointer transition-colors hover:bg-accent hover:text-accent-foreground opacity-60 hover:opacity-100"
        , attribute "aria-label" "Back to the race list"
        , Attributes.title "Back to the race list"
        ]
        [ text "←" ]
