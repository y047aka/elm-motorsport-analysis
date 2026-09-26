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
import List.Extra
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
import Route
import Shared
import Shared.Msg
import Task
import Time
import UI.DragHandle as DragHandle
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
    , carried : Maybe Carry
    , comparison : CarDetail.Comparison
    }


type Mode
    = Columns
    | Tracker


{-| `ClassLeaders` is the car at the front of each class, re-read from the
snapshot as the race runs. `Picked` is fixed, in the order the reader left
them in, and any open, close or move settles the stand-ins into one.
-}
type CarColumns
    = ClassLeaders
    | Picked CarNumber (List CarNumber)


{-| A column being carried along the strip by one pointer, from where it went
down to where it is now.
-}
type alias Carry =
    { carNumber : CarNumber
    , pointerId : Int
    , from : Float
    , at : Float
    }


type StandingsTab
    = LeaderboardTab
    | CardsTab


init : { season : String, event : String } -> ( Model, Effect Msg )
init params =
    ( { mode = Columns
      , standingsTab = LeaderboardTab
      , leaderboardState = Leaderboard.init
      , columns = ClassLeaders
      , carried = Nothing
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
    | GrabColumn CarNumber DragHandle.Pointer
    | CarryColumn DragHandle.Pointer
    | DropColumn DragHandle.Pointer
    | CancelCarry Int
    | StepColumn CarNumber Int
    | GripFocused
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

        GrabColumn carNumber pointer ->
            case m.carried of
                Just _ ->
                    ( m, Effect.none )

                Nothing ->
                    ( { m
                        | columns = rearrange shared settleColumns m.columns
                        , carried = Just { carNumber = carNumber, pointerId = pointer.id, from = pointer.x, at = pointer.x }
                      }
                    , Effect.none
                    )

        CarryColumn pointer ->
            case heldBy pointer.id m.carried of
                Just carry ->
                    ( { m | carried = Just { carry | at = pointer.x } }, Effect.none )

                Nothing ->
                    ( m, Effect.none )

        DropColumn pointer ->
            case heldBy pointer.id m.carried of
                Just carry ->
                    ( { m
                        | columns = rearrange shared (moveColumn carry.carNumber (columnsCarried { carry | at = pointer.x })) m.columns
                        , carried = Nothing
                      }
                    , Effect.none
                    )

                Nothing ->
                    ( m, Effect.none )

        CancelCarry pointerId ->
            case heldBy pointerId m.carried of
                Just _ ->
                    ( { m | carried = Nothing }, Effect.none )

                Nothing ->
                    ( m, Effect.none )

        StepColumn carNumber steps ->
            if m.carried /= Nothing then
                -- A step would move the strip under the carried column, and
                -- could take the grip holding the pointer out of the document.
                ( m, Effect.none )

            else
                ( { m | columns = rearrange shared (moveColumn carNumber steps) m.columns }
                  -- The keyed strip may move the column by taking it out of the
                  -- document, which takes the focus with it.
                , Browser.Dom.focus (gripId carNumber)
                    |> Task.attempt (\_ -> GripFocused)
                    |> Effect.sendCmd
                )

        GripFocused ->
            ( m, Effect.none )

        CarDetailMsg detailMsg ->
            ( { m | comparison = CarDetail.update detailMsg m.comparison }, Effect.none )


heldBy : Int -> Maybe Carry -> Maybe Carry
heldBy pointerId =
    Maybe.andThen
        (\carry ->
            if carry.pointerId == pointerId then
                Just carry

            else
                Nothing
        )


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


{-| Whole columns, and never past either end.
-}
moveColumn : CarNumber -> Int -> Snapshot -> CarColumns -> CarColumns
moveColumn carNumber steps snapshot columns =
    let
        current =
            columnCarNumbers snapshot columns

        others =
            List.filter ((/=) carNumber) current
    in
    case List.Extra.elemIndex carNumber current of
        Just index ->
            let
                to =
                    clamp 0 (List.length others) (index + steps)
            in
            pickedOr columns (List.take to others ++ carNumber :: List.drop to others)

        Nothing ->
            columns


{-| The stand-ins are re-read every frame, so a column being carried among them
could change places under the pointer.
-}
settleColumns : Snapshot -> CarColumns -> CarColumns
settleColumns snapshot columns =
    pickedOr columns (columnCarNumbers snapshot columns)


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


columnStrip : String -> Model -> Replay.Model -> Snapshot -> List CarAt -> Html Msg
columnStrip cell m replay snapshot shown =
    let
        several =
            List.length shown > 1

        placements =
            columnPlacements m.carried (List.map (.metadata >> .carNumber) shown)
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
                [ Attributes.class (cell ++ " flex overflow-x-auto")
                , Attributes.style "column-gap" (px columnGap)
                ]
                (List.map2
                    (\car placement ->
                        ( car.metadata.carNumber
                        , div
                            (Attributes.class "shrink-0 grid"
                                :: Attributes.style "width" (px columnWidth)
                                :: placementAttributes placement
                            )
                            [ Html.Lazy.lazy6 columnCard several (isCarried placement) m.comparison replay.race.cars snapshot car ]
                        )
                    )
                    shown
                    placements
                )


{-| A column is 360px, not a share of the cell. The widest thing in the panel is
the comparison's tab row, which wants 302px of the 328 a column of this width
hands it. The floor is 335, so the 26px over is what is left for a font that is
not the one this was measured in.
-}
columnWidth : Float
columnWidth =
    360


columnGap : Float
columnGap =
    10


columnPitch : Float
columnPitch =
    columnWidth + columnGap


px : Float -> String
px n =
    String.fromFloat n ++ "px"


travel : Carry -> Float
travel carry =
    carry.at - carry.from


columnsCarried : Carry -> Int
columnsCarried carry =
    round (travel carry / columnPitch)


{-| Where a column is drawn, and whether it is the one being carried.
-}
type Placement
    = Resting
    | Carried Float
    | Shifted Float


{-| While one is carried: that one under the pointer, held to the strip, and
each it has passed a column back the other way.

Nothing moves in the DOM until it is let go of. The grip holds the pointer only
while it stays in the document, and the keyed strip moves a column by taking
it out.

-}
columnPlacements : Maybe Carry -> List CarNumber -> List Placement
columnPlacements carried carNumbers =
    case carried |> Maybe.andThen (\carry -> List.Extra.elemIndex carry.carNumber carNumbers |> Maybe.map (Tuple.pair carry)) of
        Just ( carry, from ) ->
            let
                last =
                    List.length carNumbers - 1

                to =
                    from + clamp -from (last - from) (columnsCarried carry)
            in
            List.indexedMap
                (\index _ ->
                    if index == from then
                        Carried (clamp (toFloat -from * columnPitch) (toFloat (last - from) * columnPitch) (travel carry))

                    else if from < index && index <= to then
                        Shifted -columnPitch

                    else if to <= index && index < from then
                        Shifted columnPitch

                    else
                        Shifted 0
                )
                carNumbers

        Nothing ->
            List.map (always Resting) carNumbers


isCarried : Placement -> Bool
isCarried placement =
    case placement of
        Carried _ ->
            True

        _ ->
            False


placementAttributes : Placement -> List (Html.Attribute msg)
placementAttributes placement =
    case placement of
        Resting ->
            []

        Carried dx ->
            [ Attributes.class "relative z-10 rounded-xl bg-background shadow-2xl"
            , Attributes.style "transform" ("translateX(" ++ px dx ++ ")")
            ]

        Shifted dx ->
            [ Attributes.class "transition-transform"
            , Attributes.style "transform" ("translateX(" ++ px dx ++ ")")
            ]


columnGrip : Bool -> CarNumber -> Html Msg
columnGrip held carNumber =
    DragHandle.view
        { id = gripId carNumber
        , label = "Move this column"
        , held = held
        , onGrab = GrabColumn carNumber
        , onMove = CarryColumn
        , onDrop = DropColumn
        , onCancel = CancelCarry
        , onStep = StepColumn carNumber
        }


gripId : CarNumber -> String
gripId carNumber =
    "column-grip-" ++ carNumber


{-| Drawn lazily, since a carry redraws the strip on every frame the pointer
moves, paused or not. Each argument is compared by reference, so a record built
at the call site would redraw every panel on every one of those frames.
-}
columnCard : Bool -> Bool -> CarDetail.Comparison -> List Car -> Snapshot -> CarAt -> Html Msg
columnCard several held comparison cars snapshot car =
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
                        if several then
                            Just (CloseColumn carNumber)

                        else
                            Nothing
                    , grip =
                        if several then
                            Just (columnGrip held carNumber)

                        else
                            Nothing
                    , comparison = comparison
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
        |> div [ Attributes.class "grid grid-cols-[auto_1fr_auto_auto] gap-x-2 text-xs" ]


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
    div [ Attributes.class "col-span-4 grid grid-cols-subgrid grid-rows-[1.375rem_1rem] gap-y-1 items-center py-0.5" ]
        ([ cell "" [ car |> Maybe.map (.metadata >> classMark) |> Maybe.withDefault (text "") ]
         , cell "" [ text (describe event.eventType) ]
         , cell "" [ carBadge car event.eventType ]
         , cell "whitespace-nowrap text-right tabular-nums text-muted-foreground"
            [ text (event.elapsed |> Instant.toDuration |> Duration.toStringToSeconds) ]
         ]
            ++ secondLine
        )


classMark : Metadata -> Html Msg
classMark metadata =
    div
        [ Attributes.class "size-2 rounded-[2px]"
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
