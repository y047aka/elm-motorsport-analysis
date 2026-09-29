module Page.Wec.Event exposing (Model, Msg, init, subscriptions, update, view)

{-| WEC event page (`/wec/:season/:event`). Route parameters are passed into
`init` by `Main`.

@docs Model, Msg, init, subscriptions, update, view

-}

import Browser.Dom
import Browser.Events
import Dict exposing (Dict)
import Effect exposing (Effect)
import Html exposing (Html, a, button, div, main_, nav, span, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Events exposing (onClick)
import Html.Keyed
import Html.Lazy
import Json.Decode as Decode
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Flag as Flag
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
import Page.Wec.Columns as Columns
import Route
import Shared
import Shared.Msg
import Task
import Time
import UI.DragHandle as DragHandle
import UI.Notice as Notice
import UI.Shadcn.Button as Button
import UI.Shadcn.Card as Card
import UI.Shadcn.ToggleGroup as ToggleGroup
import View exposing (View)
import View.CarCardList as CarCardList
import View.CarDetail as CarDetail
import View.CarDetail.Header as Header
import View.CarNumberBadge as CarNumberBadge
import View.LiveStandings as LiveStandings
import View.PlaybackControls as PlaybackControls



-- MODEL


type alias Model =
    { pane : Pane
    , strip : Columns.Model
    , standingsTab : StandingsTab
    , leaderboardState : Leaderboard.Model
    , comparison : CarDetail.Comparison
    }


{-| The page's right-hand pane: the tracker the reader adds a column of, and
the timeline.
-}
type Pane
    = Shown
    | Hidden


togglePane : Pane -> Pane
togglePane pane =
    case pane of
        Shown ->
            Hidden

        Hidden ->
            Shown


type StandingsTab
    = LeaderboardTab
    | CardsTab


init : { season : String, event : String } -> ( Model, Effect Msg )
init params =
    ( { pane = Shown
      , strip = Columns.init
      , standingsTab = LeaderboardTab
      , leaderboardState = Leaderboard.init
      , comparison = CarDetail.initialComparison
      }
    , Effect.sendSharedMsg (Shared.Msg.FetchJson_Wec { season = params.season, event = params.event })
    )



-- UPDATE


type Msg
    = StartRace
    | PauseRace
    | TogglePane
    | ColumnsMsg Columns.Msg
    | StandingsTabChange StandingsTab
    | ReplayMsg Replay.Msg
    | LeaderboardMsg Leaderboard.Msg
    | CarDetailMsg CarDetail.Msg


update : Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update shared msg m =
    case msg of
        StartRace ->
            ( m, Task.perform (Replay.Start >> ReplayMsg) Time.now |> Effect.sendCmd )

        PauseRace ->
            ( m, Task.perform (Replay.Pause >> ReplayMsg) Time.now |> Effect.sendCmd )

        ColumnsMsg sub ->
            let
                ( strip, cmd ) =
                    Columns.update (field shared) sub m.strip
            in
            ( { m | strip = strip }, Effect.sendCmd (Cmd.map ColumnsMsg cmd) )

        TogglePane ->
            ( { m | pane = togglePane m.pane }, Effect.none )

        StandingsTabChange tab ->
            ( { m | standingsTab = tab }, Effect.none )

        ReplayMsg replayMsg ->
            ( m, Effect.sendSharedMsg (Shared.Msg.ReplayMsg replayMsg) )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            )

        CarDetailMsg detailMsg ->
            ( { m | comparison = CarDetail.update detailMsg m.comparison }, Effect.none )


{-| The field is read at the moment of the message, never kept: the strip's
update takes it as an argument and the stand-ins are off it.
-}
field : Shared.Model -> Maybe Snapshot
field shared =
    Shared.loadedRound shared |> Maybe.map .snapshot



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
            [ navigation m.pane (headerTitle shared) maybeRound
            , case maybeRound of
                Nothing ->
                    -- Named but not loaded. Nothing is drawn rather than the
                    -- round before it.
                    div [ Attributes.class "row-start-2" ] [ unavailable shared ]

                Just round ->
                    mainGrid round.track
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


{-| The tracker's column, carried among the cars as any other is. Its ✕ is
the one thing that takes it away; the body answers to no click.

It carries `data-tracker-column`, which the visual tests locate it by.

-}
trackerCard : Bool -> Bool -> TrackerChart.Track -> Snapshot -> Html Msg
trackerCard several held track snapshot =
    Card.card [ attribute "data-tracker-column" "" ]
        [ div
            [ Attributes.class "flex-1 min-h-0 grid grid-rows-[minmax(0,1fr)]"
            ]
            [ Card.content []
                [ div [ Attributes.class "relative h-full w-full grid place-items-center" ]
                    [ TrackerChart.view TrackerChart.Full track snapshot
                    , div [ Attributes.class "absolute top-0 right-0 flex items-start gap-x-1" ]
                        ((if several then
                            [ columnGrip held Columns.Tracker ]

                          else
                            []
                         )
                            ++ [ Header.closeButton (ColumnsMsg (Columns.ShowTracker False)) ]
                        )
                    ]
                ]
            ]
        ]


mainGrid : TrackerChart.Track -> Timeline -> Snapshot -> Replay.Model -> Model -> Html Msg
mainGrid track timeline snapshot replay m =
    let
        keys =
            Columns.resolve snapshot (Columns.keysOf snapshot m.strip.order)

        gridCells =
            [ div
                [ Attributes.class "col-start-1 row-start-1 row-span-2 h-full overflow-y-hidden" ]
                [ LiveStandings.view
                    { onSelect = Columns.Open >> ColumnsMsg
                    , withColumns = List.map (.metadata >> .carNumber) (Columns.carsIn snapshot keys)
                    }
                    snapshot
                ]
            , columnStrip "col-start-2 row-start-1 row-span-2" track keys m replay snapshot
            ]
                ++ paneCells m.pane track snapshot timeline replay
    in
    div
        [ Attributes.class "row-start-2 h-full overflow-y-auto p-[0_10px_10px_10px] flex flex-col gap-2.5" ]
        [ div
            [ Attributes.class
                ("shrink-0 h-full grid "
                    ++ (case m.pane of
                            Shown ->
                                "grid-cols-[218px_1fr_270px]"

                            Hidden ->
                                "grid-cols-[218px_1fr]"
                       )
                    ++ " grid-rows-[300px_minmax(0,1fr)] gap-2.5"
                )
            ]
            gridCells
        , standingsPanel m.standingsTab m replay snapshot
        , standingsPopover
        , div [ attribute "aria-live" "polite", Attributes.class "sr-only" ] [ text m.strip.announcement ]
        ]


{-| The tracker and the timeline, or nothing once the pane is hidden.

The tracker's box is settled the way the tracker column settles its own --
row, grow, row -- because the card's content has no height of its own to
give a drawing a percentage of: a drawing sized only by its viewBox's aspect,
and a tall circuit's is very tall, runs past the card's border instead of
inside it.

-}
paneCells : Pane -> TrackerChart.Track -> Snapshot -> Timeline -> Replay.Model -> List (Html Msg)
paneCells pane track snapshot timeline replay =
    case pane of
        Hidden ->
            []

        Shown ->
            [ div
                [ Attributes.class "col-start-3 row-start-1 h-full grid grid-rows-[minmax(0,1fr)] cursor-pointer"
                , attribute "data-tracker-pane" ""
                , onClick (ColumnsMsg (Columns.ShowTracker True))
                ]
                [ Card.card []
                    [ div
                        [ Attributes.class "flex-1 min-h-0 grid grid-rows-[minmax(0,1fr)]" ]
                        [ Card.content []
                            [ div
                                [ Attributes.class "relative h-full w-full grid place-items-center" ]
                                [ TrackerChart.view TrackerChart.Compact track snapshot ]
                            ]
                        ]
                    ]
                ]
            , timelinePanel "col-start-3 row-start-2" timeline replay
            ]


columnStrip : String -> TrackerChart.Track -> List Columns.StripKey -> Model -> Replay.Model -> Snapshot -> Html Msg
columnStrip cell track keys m replay snapshot =
    let
        several =
            List.length keys > 1

        placements =
            Columns.placements m.strip.carried keys
    in
    case keys of
        [] ->
            -- Before any car has turned a lap.
            div [ Attributes.class (cell ++ " flex") ] [ Card.card [] [] ]

        _ ->
            -- Keyed on the column: a column matched by position instead would
            -- hand how far the reader had scrolled it to whichever column moved
            -- up into its place when the one before it was closed.
            Html.Keyed.node "div"
                ([ Attributes.id Columns.stripId
                 , Attributes.class (cell ++ " flex overflow-x-auto")
                 , Attributes.style "column-gap" (Columns.px Columns.gap)
                 ]
                    ++ (case m.strip.carried of
                            Just _ ->
                                [ Html.Events.on "scroll" (Decode.map (Columns.StripScrolled >> ColumnsMsg) (Decode.at [ "target", "scrollLeft" ] Decode.float)) ]

                            Nothing ->
                                []
                       )
                )
                (List.map2
                    (\key placement ->
                        ( Columns.keyName key
                        , div
                            (Attributes.class "shrink-0 grid"
                                :: Attributes.style "width" (Columns.px Columns.width)
                                :: Columns.placementAttributes placement
                            )
                            [ case key of
                                Columns.Car carNumber ->
                                    Maybe.withDefault (text "")
                                        (Snapshot.get carNumber snapshot
                                            |> Maybe.map
                                                (\car ->
                                                    Html.Lazy.lazy5 (carCard several) (Columns.isCarried placement) m.comparison replay.race.cars snapshot car
                                                )
                                        )

                                Columns.Tracker ->
                                    trackerCard several (Columns.isCarried placement) track snapshot
                            ]
                        )
                    )
                    keys
                    placements
                )


columnGrip : Bool -> Columns.StripKey -> Html Msg
columnGrip held key =
    DragHandle.view
        { id = Columns.gripId key
        , label = "Move this column"
        , held = held
        , onGrab = Columns.Grab key >> ColumnsMsg
        , onMove = Columns.Carrying >> ColumnsMsg
        , onDrop = Columns.Release >> ColumnsMsg
        , onCancel = Columns.Cancel >> ColumnsMsg
        , onStep = Columns.Step key >> ColumnsMsg
        }


carCard : Bool -> Bool -> CarDetail.Comparison -> List Car -> Snapshot -> CarAt -> Html Msg
carCard several held comparison cars snapshot car =
    let
        carNumber =
            car.metadata.carNumber
    in
    Card.card []
        -- A card's content does not shrink below what it holds, so the card
        -- settles the height here and the panel scrolls within it, under the
        -- header. The row is `minmax(0,1fr)` rather than `auto`: an `auto` row
        -- takes the content's height and overflows the card rather than
        -- cropping it.
        [ div
            [ Attributes.class "flex-1 min-h-0 grid grid-rows-[minmax(0,1fr)]" ]
            [ Card.content []
                [ CarDetail.view
                    { toMsg = CarDetailMsg
                    , onClose =
                        if several then
                            Just (ColumnsMsg (Columns.Close carNumber))

                        else
                            Nothing
                    , grip =
                        if several then
                            Just (columnGrip held (Columns.Car carNumber))

                        else
                            Nothing
                    , comparison = comparison
                    , scrollId = Columns.scrollId carNumber
                    , onScroll = Columns.PanelScrolled carNumber >> ColumnsMsg
                    }
                    cars
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
        |> div [ Attributes.class "grid grid-cols-[auto_auto_1fr_auto] gap-x-2 text-xs" ]


{-| A row is two lines whatever it holds, the first as tall as the badge: the
`1.375rem` is `CarNumberBadge.viewRow`'s height, and moves with it.
-}
eventRow : Dict CarNumber Car -> TimelineEvent -> Html Msg
eventRow carsByNumber event =
    let
        car =
            case event.eventType of
                CarEvent carNumber _ ->
                    Dict.get carNumber carsByNumber

                _ ->
                    Nothing

        cell classes children =
            div [ Attributes.class classes ] children

        secondLine =
            case detail car event of
                Just line ->
                    [ cell "col-start-2 col-span-3 whitespace-nowrap text-[10px] text-muted-foreground" [ text line ] ]

                Nothing ->
                    []
    in
    div [ Attributes.class "col-span-4 grid grid-cols-subgrid grid-rows-[1.375rem_1rem] gap-y-0.5 items-center py-0.5" ]
        ([ cell "" [ car |> Maybe.map (.metadata >> classMark) |> Maybe.withDefault (text "") ]
         , cell "" [ carBadge car event.eventType ]
         , cell "" [ text (describe event.eventType) ]
         , cell "whitespace-nowrap text-right tabular-nums text-muted-foreground"
            [ text (event.elapsed |> Instant.toDuration |> Duration.toStringToSeconds) ]
         ]
            ++ secondLine
        )


{-| The same bar the LiveStandings class headers stand their names on --
`0.2em x 1.2em` of the class colour at their 10px, which is 2px x 12px.
-}
classMark : Metadata -> Html Msg
classMark metadata =
    div
        [ Attributes.class "w-[2px] h-[12px] rounded-[2px]"
        , attribute "style" ("background-color: " ++ Class.toColor metadata.class ++ ";")
        ]
        []


{-| An event of the whole field's has no badge, and a number no car of the field
answers to keeps its bare digits rather than vanishing.
-}
carBadge : Maybe Car -> EventType -> Html Msg
carBadge car eventType =
    case ( car, eventType ) of
        ( Just { metadata }, _ ) ->
            CarNumberBadge.viewRow metadata

        ( Nothing, CarEvent carNumber _ ) ->
            span [] [ text carNumber ]

        ( Nothing, _ ) ->
            text ""


describe : EventType -> String
describe eventType =
    case eventType of
        RaceStart ->
            "Race Start"

        Flag flag ->
            Flag.toString flag

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


navigation : Pane -> String -> Maybe Shared.LoadedRound -> Html Msg
navigation pane title maybeRound =
    nav
        [ Attributes.class "p-3 grid grid-cols-[auto_1fr_auto] items-center gap-x-10" ]
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
        , paneToggle pane
        ]


{-| The arrows point at the edge the pane lives on.
-}
paneToggle : Pane -> Html Msg
paneToggle pane =
    let
        verb =
            case pane of
                Shown ->
                    "Hide"

                Hidden ->
                    "Show"

        glyph =
            case pane of
                Shown ->
                    "»"

                Hidden ->
                    "«"
    in
    Button.view
        { label = glyph
        , variant = Button.Ghost
        , size = Button.Icon
        , shape = Button.Circle
        , disabled = False
        , onPress = TogglePane
        }
        [ attribute "aria-label" (verb ++ " the tracker and timeline")
        , Attributes.title (verb ++ " the tracker and timeline")
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
