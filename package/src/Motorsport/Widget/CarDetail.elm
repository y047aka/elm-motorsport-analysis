module Motorsport.Widget.CarDetail exposing
    ( Model, init
    , Msg, update
    , view
    )

{-| Everything the race says about one car, drawn as plain inline content.

The car is the caller's selection; the rivals it is measured against are read
off the field around it, so the panel follows the race without the selection
changing.

Which of them is on show is the panel's own, though, and is held here rather
than by the page: the chart, the stretch of the race it covers and whether the
lap history is open say nothing about the race and nothing else reads them.

@docs Model, init
@docs Msg, update
@docs view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)
import List.Extra
import Motorsport.Analysis.LapWindow as LapWindow exposing (LapWindow)
import Motorsport.Analysis.Rivals as Rivals exposing (Rivals)
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap exposing (Lap)
import Motorsport.LapRange exposing (LapRange)
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Widget.CarDetail.ChartTabs as ChartTabs
import Motorsport.Widget.CarDetail.Header as Header
import Motorsport.Widget.CarDetail.LapTimes as LapTimes
import Motorsport.Widget.CarDetail.PositionProgression as PositionProgression
import Motorsport.Widget.CarDetail.Stint as Stint
import Motorsport.Widget.CarNumberBadge as CarNumberBadge
import Motorsport.Widget.Common as Widget
import Motorsport.Widget.Distribution as Distribution


{-| What the panel is showing, which nothing outside it reads.
-}
type Model
    = Model State


type alias State =
    { chart : Chart
    , window : LapWindow
    , lapHistoryOpen : Bool
    }


init : Model
init =
    Model
        { chart = GapChart
        , window = LapWindow.WholeRace
        , lapHistoryOpen = False
        }


{-| The race so far as the car ran it among its rivals, one view at a time.

The legend beneath them names the cars the panel is comparing, and all three
draw those in full. What each puts behind them is its own: the gap chart adds
the pair beyond the fight, the position chart the whole class, the distribution
nothing at all. The car's own laps are not a comparison and are read where its
other lap times are.

-}
type Chart
    = GapChart
    | PositionChart
    | DistributionChart


type Msg
    = SelectedChart Chart
    | SelectedWindow LapWindow
    | ToggledLapHistory


update : Msg -> Model -> Model
update msg (Model state) =
    Model <|
        case msg of
            SelectedChart chart ->
                { state | chart = chart }

            SelectedWindow window ->
                { state | window = window }

            ToggledLapHistory ->
                { state | lapHistoryOpen = not state.lapHistoryOpen }


view : (Msg -> msg) -> Model -> List Car -> Snapshot -> CarAt -> Html msg
view toMsg (Model state) cars snapshot focused =
    Html.map toMsg (panel state cars snapshot focused)


panel : State -> List Car -> Snapshot -> CarAt -> Html Msg
panel state cars snapshot focused =
    let
        lapHistory =
            Snapshot.lapHistory snapshot

        rivals =
            rivalsOf snapshot focused
    in
    div [ class "grid gap-y-3" ]
        [ Header.view
            { startPosition = startPositionOf cars focused
            , behind = behind snapshot focused
            }
            focused
        , Widget.container "Lap times"
            (LapTimes.view
                { bestTimes = Snapshot.bestTimes snapshot
                , historyOpen = state.lapHistoryOpen
                , onToggleHistory = ToggledLapHistory
                }
                (lapsOf cars focused)
                focused
            )
        , Widget.container "Stints"
            (Stint.view
                { status = focused.status, stops = focused.pitStops }
                focused.metadata
                (LapHistory.get focused.metadata.carNumber lapHistory |> Stint.summarize)
            )
        , charts state snapshot rivals
        ]


{-| What the three charts are all drawn from, built once here so that the tabs
switch the chart and nothing else about what is being shown.
-}
type alias Comparison =
    { range : LapRange
    , snapshot : Snapshot
    , rivals : Rivals
    }


charts : State -> Snapshot -> Rivals -> Html Msg
charts state snapshot rivals =
    let
        comparison =
            { range = LapWindow.range state.window (Rivals.focused rivals).metadata.class snapshot
            , snapshot = snapshot
            , rivals = rivals
            }
    in
    Widget.container "Rivals"
        (div [ class "grid gap-y-2" ]
            [ chartTabs state comparison
            , legend snapshot rivals
            ]
        )


{-| The stretches of the race on offer, in the order the toggle draws them.

One setting for all three charts rather than one each: only one of them is
showing at a time, and a stretch that changed as the tabs did would read as the
chart changing.

-}
windowOptions : List ( LapWindow, String )
windowOptions =
    [ ( LapWindow.Recent (90 * 60 * 1000), "Last 1.5h" )
    , ( LapWindow.Recent (3 * 60 * 60 * 1000), "Last 3h" )
    , ( LapWindow.WholeRace, "All" )
    ]


{-| The cars the panel is comparing, in running order, and how far up or down
the road each of them is, which is what the charts above are drawn to show.
Only these are named, whatever else a chart draws behind them.

Nothing here restates the colour the charts draw a car in: the car's badge is
that colour already, and a second mark beside it is the same ink twice.

-}
legend : Snapshot -> Rivals -> Html msg
legend snapshot rivals =
    div [ class "grid gap-y-px" ]
        (Rivals.fight rivals
            |> List.map (legendEntry snapshot (Rivals.focused rivals))
        )


legendEntry : Snapshot -> CarAt -> CarAt -> Html msg
legendEntry snapshot focused item =
    let
        isFocused =
            item.metadata.carNumber == focused.metadata.carNumber
    in
    div
        [ class "flex items-center gap-x-2 py-0.5 px-1 rounded"
        , class
            (if isFocused then
                "bg-accent/40"

             else
                ""
            )
        ]
        [ CarNumberBadge.viewRow item.metadata
        , div [ class "text-[11px] truncate flex-1" ] [ text item.metadata.team ]
        , div [ class "text-[10px] text-muted-foreground whitespace-nowrap" ]
            [ text ("P" ++ String.fromInt item.standing.positionInClass) ]
        , div [ class "text-[12px] tabular-nums" ]
            [ text
                (if isFocused then
                    "-"

                 else
                    fromFocused snapshot focused item
                )
            ]
        ]


{-| One wording for an empty chart, whatever tab is showing. The three run out
of laps for reasons of their own -- a stretch holding none of the cars drawn, a
class with no line to draw, no lap time to describe -- and a wording apiece reads
as the tabs disagreeing about the race.
-}
chartTabs : State -> Comparison -> Html Msg
chartTabs state { range, snapshot, rivals } =
    let
        orEmptyState : Maybe (Html Msg) -> Html Msg
        orEmptyState =
            Maybe.withDefault (Widget.emptyState "No laps to compare yet")
    in
    ChartTabs.chartTabs SelectedChart
        state.chart
        (ChartTabs.segmentedControl SelectedWindow state.window windowOptions)
        [ ( GapChart, "Gap to avg", \() -> orEmptyState (GapChart.gapChartView range snapshot rivals) )
        , ( PositionChart, "Positions", \() -> orEmptyState (PositionProgression.view range snapshot rivals) )
        , ( DistributionChart, "Distribution", \() -> orEmptyState (Distribution.view range snapshot rivals) )
        ]


{-| How far up or down the road a rival is: the intervals between the two cars,
added up along the running order. Each is measured at the same moment, so the sum
is a time on the road; a lap anywhere between the two makes it no time at all,
and the laps the two are apart are what is left to say.
-}
fromFocused : Snapshot -> CarAt -> CarAt -> String
fromFocused snapshot focused item =
    case gapBetween snapshot focused item of
        Just delta ->
            signed delta ++ Duration.toString (abs delta)

        Nothing ->
            case item.standing.lapsCompleted - focused.standing.lapsCompleted of
                0 ->
                    "-"

                lapsAhead ->
                    signed -lapsAhead ++ String.fromInt (abs lapsAhead) ++ "L"


{-| Positive where `item` is behind `focused`, as a gap on a timing screen is.
-}
gapBetween : Snapshot -> CarAt -> CarAt -> Maybe Duration
gapBetween snapshot focused item =
    let
        field =
            Snapshot.toList snapshot

        positionOf car =
            List.Extra.findIndex (\other -> other.metadata.carNumber == car.metadata.carNumber) field
    in
    Maybe.map2 Tuple.pair (positionOf focused) (positionOf item)
        |> Maybe.andThen
            (\( ours, theirs ) ->
                field
                    |> List.drop (min ours theirs + 1)
                    |> List.take (abs (theirs - ours))
                    |> List.map (.standing >> .intervalToAhead >> Gap.toDuration)
                    |> combine
                    |> Maybe.map
                        (\intervals ->
                            if theirs > ours then
                                List.sum intervals

                            else
                                negate (List.sum intervals)
                        )
            )


combine : List (Maybe a) -> Maybe (List a)
combine =
    List.foldr (Maybe.map2 (::)) (Just [])


signed : Int -> String
signed value =
    if value >= 0 then
        "+"

    else
        "-"


rivalsOf : Snapshot -> CarAt -> Rivals
rivalsOf snapshot focused =
    Rivals.around (Snapshot.toList snapshot) focused


startPositionOf : List Car -> CarAt -> Maybe Int
startPositionOf cars focused =
    carOf cars focused |> Maybe.map .startPosition


{-| The car's laps as the race holds them, which is the same list from one frame
to the next -- unlike the history, which is built afresh at every clock.
-}
lapsOf : List Car -> CarAt -> List Lap
lapsOf cars focused =
    carOf cars focused |> Maybe.map .laps |> Maybe.withDefault []


carOf : List Car -> CarAt -> Maybe Car
carOf cars focused =
    List.Extra.find (\car -> car.metadata.carNumber == focused.metadata.carNumber) cars


{-| How far the next car in the running order is behind this one, which is the
gap that car is given to the one ahead of it.
-}
behind : Snapshot -> CarAt -> Maybe Gap
behind snapshot focused =
    Snapshot.toList snapshot
        |> List.Extra.dropWhile (\item -> item.metadata.carNumber /= focused.metadata.carNumber)
        |> List.drop 1
        |> List.head
        |> Maybe.map (.standing >> .intervalToAhead)
