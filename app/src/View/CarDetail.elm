module View.CarDetail exposing
    ( Comparison, initialComparison
    , Model, init
    , Msg, update
    , view
    )

{-| Everything the race says about one car, drawn in place on the event page.

The car is the caller's selection; the rivals it is measured against are read
off the field around it, so the panel follows the race without the selection
changing.

What is on show splits in two: the chart and the stretch of the race it covers
are the page's, so that columns beside one another are showing the same thing,
and whether the lap history is open is one column's own.

@docs Comparison, initialComparison
@docs Model, init
@docs Msg, update
@docs view

-}

import Html exposing (Html, div, h3, text)
import Html.Attributes exposing (attribute, class)
import List.Extra
import Motorsport.Analysis.LapWindow as LapWindow exposing (LapWindow)
import Motorsport.Analysis.Rivals as Rivals exposing (Rivals)
import Motorsport.Analysis.Stint as AnalysisStint
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Chart.PositionProgression as PositionProgression
import Motorsport.Duration as Duration
import Motorsport.Lap exposing (Lap)
import Motorsport.LapRange exposing (LapRange)
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import View.CarDetail.ChartTabs as ChartTabs
import View.CarDetail.Header as Header
import View.CarDetail.LapTimes as LapTimes
import View.CarDetail.Stint as Stint
import View.CarNumberBadge as CarNumberBadge


{-| What one column is showing that the columns beside it are not.
-}
type Model
    = Model { lapHistoryOpen : Bool }


init : Model
init =
    Model { lapHistoryOpen = False }


{-| Which chart the rivals are drawn in, and how much of the race it covers.

The page hands every column the same one: a neighbour drawing a different chart
over a different stretch of the race is not something to read anything against.

-}
type Comparison
    = Comparison
        { chart : Chart
        , window : LapWindow
        }


initialComparison : Comparison
initialComparison =
    Comparison
        { chart = GapChart
        , window = LapWindow.WholeRace
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


{-| Takes both, because one set of messages lands in two places.
-}
update :
    Msg
    -> { comparison : Comparison, panel : Model }
    -> { comparison : Comparison, panel : Model }
update msg state =
    let
        (Comparison comparison) =
            state.comparison

        (Model showing) =
            state.panel
    in
    case msg of
        SelectedChart chart ->
            { state | comparison = Comparison { comparison | chart = chart } }

        SelectedWindow window ->
            { state | comparison = Comparison { comparison | window = window } }

        ToggledLapHistory ->
            { state | panel = Model { showing | lapHistoryOpen = not showing.lapHistoryOpen } }


{-| The panel, marked with the car it is drawing, which the visual tests locate
it by: an `id` would name one panel, and the reader can have several of these
open at once.

The car is the one the column was opened for, so it is a car and not a `Maybe`
one: a field with nothing in it yet is a page with no columns, which the page
draws without asking for a panel at all.

-}
view :
    { toMsg : Msg -> msg
    , onClose : Maybe msg
    , comparison : Comparison
    , showing : Model
    }
    -> List Car
    -> Snapshot
    -> CarAt
    -> Html msg
view config cars snapshot focused =
    div
        [ attribute "data-car-detail" focused.metadata.carNumber
        , class "grid gap-y-3"
        ]
        [ Header.view
            { startPosition = startPositionOf cars focused
            , behind = Snapshot.behind focused snapshot |> Maybe.map (.standing >> .intervalToAhead)
            , onClose = config.onClose
            }
            focused
        , Html.map config.toMsg (panel config.comparison config.showing cars snapshot focused)
        ]


{-| Everything under the header, which is the column's own and reports to it.
-}
panel : Comparison -> Model -> List Car -> Snapshot -> CarAt -> Html Msg
panel comparison (Model showing) cars snapshot focused =
    let
        lapHistory =
            Snapshot.lapHistory snapshot

        rivals =
            rivalsOf snapshot focused
    in
    div [ class "grid gap-y-3" ]
        [ container "Lap times"
            (LapTimes.view
                { bestTimes = Snapshot.bestTimes snapshot
                , historyOpen = showing.lapHistoryOpen
                , onToggleHistory = ToggledLapHistory
                }
                (lapsOf cars focused)
                focused
            )
        , container "Stints"
            (Stint.view
                { status = focused.status, stops = focused.pitStops }
                focused.metadata
                (LapHistory.get focused.metadata.carNumber lapHistory |> AnalysisStint.summarize)
            )
        , charts comparison snapshot rivals
        ]


charts : Comparison -> Snapshot -> Rivals -> Html Msg
charts ((Comparison { window }) as comparison) snapshot rivals =
    let
        range =
            LapWindow.range window (Rivals.class rivals) snapshot
    in
    container "Rivals"
        (div [ class "grid gap-y-2" ]
            [ chartTabs comparison range snapshot rivals
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
chartTabs : Comparison -> LapRange -> Snapshot -> Rivals -> Html Msg
chartTabs (Comparison { chart, window }) range snapshot rivals =
    let
        orEmptyState : Maybe (Html Msg) -> Html Msg
        orEmptyState =
            Maybe.withDefault (emptyState "No laps to compare yet")
    in
    ChartTabs.chartTabs SelectedChart
        chart
        (ChartTabs.segmentedControl SelectedWindow window windowOptions)
        [ ( GapChart, "Gap to avg", \() -> orEmptyState (GapChart.gapChartView range snapshot rivals) )
        , ( PositionChart, "Positions", \() -> orEmptyState (PositionProgression.view range snapshot rivals) )
        , ( DistributionChart, "Distribution", \() -> orEmptyState (LapTimeDistribution.view range snapshot rivals) )
        ]


{-| How far up or down the road a rival is. Where the two cars have no time
between them, the laps they are apart are what is left to say.
-}
fromFocused : Snapshot -> CarAt -> CarAt -> String
fromFocused snapshot focused item =
    case Snapshot.gapBetween focused item snapshot of
        Just delta ->
            signed delta ++ Duration.toString (abs delta)

        Nothing ->
            case item.standing.lapsCompleted - focused.standing.lapsCompleted of
                0 ->
                    "-"

                lapsAhead ->
                    signed -lapsAhead ++ String.fromInt (abs lapsAhead) ++ "L"


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


container : String -> Html msg -> Html msg
container title content =
    div
        [ class "rounded-lg border border-border bg-card" ]
        [ div [ class "flex flex-col gap-2 p-3" ]
            [ h3 [ class "font-semibold text-sm" ] [ text title ]
            , content
            ]
        ]


emptyState : String -> Html msg
emptyState message =
    div
        [ class "p-5 text-center italic text-muted-foreground" ]
        [ text message ]
