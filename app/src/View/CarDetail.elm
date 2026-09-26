module View.CarDetail exposing
    ( Comparison, initialComparison
    , Msg, update
    , view
    )

{-| Everything the race says about one car, drawn in place on the event page.

The car is the caller's; the rivals it is measured against are read off the
field around it, so the panel follows the race without the car it is for
changing.

The chart and the stretch of the race it covers are the page's, so that columns
beside one another are showing the same thing. Whether the lap history is open
is the `details` element's own, and lasts as long as the column's DOM does.

@docs Comparison, initialComparison
@docs Msg, update
@docs view

-}

import Html exposing (Html, details, div, h3, summary, text)
import Html.Attributes exposing (attribute, class)
import List.Extra
import Motorsport.Analysis.LapWindow as LapWindow exposing (LapWindow)
import Motorsport.Analysis.Rivals as Rivals exposing (Rivals)
import Motorsport.Analysis.Stint as AnalysisStint
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Chart.PositionProgression as PositionProgression
import Motorsport.Driver as Driver
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap exposing (Lap)
import Motorsport.LapRange exposing (LapRange)
import Motorsport.Position as Position exposing (Position)
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import View.CarDetail.ChartTabs as ChartTabs
import View.CarDetail.Header as Header
import View.CarDetail.LapTable as LapTable
import View.CarDetail.LapTimes as LapTimes
import View.CarDetail.Stint as Stint
import View.CarNumberBadge as CarNumberBadge


{-| Which chart the rivals are drawn in, and how much of the race it covers.
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


update : Msg -> Comparison -> Comparison
update msg (Comparison comparison) =
    case msg of
        SelectedChart chart ->
            Comparison { comparison | chart = chart }

        SelectedWindow window ->
            Comparison { comparison | window = window }


{-| The panel carries `data-car-detail`, which the visual tests locate it by.
-}
view :
    { toMsg : Msg -> msg
    , onClose : Maybe msg
    , grip : Maybe (Html msg)
    , comparison : Comparison
    }
    -> List Car
    -> Snapshot
    -> CarAt
    -> Html msg
view config cars snapshot focused =
    let
        rivals =
            rivalsOf snapshot focused
    in
    div
        [ attribute "data-car-detail" focused.metadata.carNumber
        , class "grid gap-y-3"
        ]
        [ Header.view
            { startPosition = startPositionOf cars focused
            , toLeader = gapOf snapshot (Snapshot.classLeader focused.metadata.class snapshot) focused
            , onClose = config.onClose
            , grip = config.grip
            }
            focused
        , Html.map config.toMsg (panel config.comparison cars snapshot rivals focused)
        ]


{-| The gap a classification prints between two cars: the time between them
where the road holds them together, and the whole laps where it does not.

No gap at all where there is no car in front, and none where it is the same
car: a car leading its class is asked for its gap to the leader too.

-}
gapOf : Snapshot -> Maybe CarAt -> CarAt -> Gap
gapOf snapshot maybeInFront chasing =
    case maybeInFront of
        Just inFront ->
            if inFront.metadata.carNumber == chasing.metadata.carNumber then
                Gap.none

            else
                case Snapshot.gapBetween inFront chasing snapshot of
                    Just delta ->
                        Gap.seconds delta

                    Nothing ->
                        Gap.laps (inFront.standing.lapsCompleted - chasing.standing.lapsCompleted)

        Nothing ->
            Gap.none


panel : Comparison -> List Car -> Snapshot -> Rivals -> CarAt -> Html Msg
panel comparison cars snapshot rivals focused =
    let
        lapHistory =
            Snapshot.lapHistory snapshot

        laps =
            lapsOf cars focused
    in
    -- No gap: the sections carry their own padding, and the rule between two of
    -- them wants to sit in the middle of that rather than have space of its own.
    div [ class "grid" ]
        [ container "Rivals" (legend snapshot rivals)
        , container "Lap times"
            (LapTimes.view { bestTimes = Snapshot.bestTimes snapshot } laps focused)
        , charts comparison snapshot rivals
        , container "Stints"
            (Stint.view
                { status = focused.status, stops = focused.pitStops }
                focused.metadata
                (LapHistory.get focused.metadata.carNumber lapHistory |> AnalysisStint.summarize)
            )
        , disclosure "Lap history" (LapTable.view laps focused.standing.lapsCompleted)
        ]


charts : Comparison -> Snapshot -> Rivals -> Html Msg
charts ((Comparison { window }) as comparison) snapshot rivals =
    let
        range =
            LapWindow.range window (Rivals.class rivals) snapshot
    in
    container "Comparison" (chartTabs comparison range snapshot rivals)


{-| The stretches of the race on offer, in the order the toggle draws them.

One setting for all three charts rather than one each: only one of them is
showing at a time, and a stretch that changed as the tabs did would read as the
chart changing.

The durations are given bare: this row is the widest thing in the panel, and
sets how wide a column has to be.

-}
windowOptions : List ( LapWindow, String )
windowOptions =
    [ ( LapWindow.Recent (90 * 60 * 1000), "1.5h" )
    , ( LapWindow.Recent (3 * 60 * 60 * 1000), "3h" )
    , ( LapWindow.WholeRace, "All" )
    ]


{-| The cars the panel is comparing, in class order, and the interval down the
order to each. Only these are named, whatever else a chart below draws behind
them.

A row's time is measured against the row above it rather than out from the car
the panel is for, which is how a classification prints an interval.

Nothing here restates the colour the charts draw a car in: the car's badge is
that colour already, and a second mark beside it is the same ink twice.

-}
legend : Snapshot -> Rivals -> Html msg
legend snapshot rivals =
    let
        shown =
            Rivals.fight rivals
    in
    div [ class "grid gap-y-px" ]
        (List.map2 (legendEntry snapshot (Rivals.focused rivals))
            (Nothing :: List.map Just shown)
            shown
        )


legendEntry : Snapshot -> CarAt -> Maybe CarAt -> CarAt -> Html msg
legendEntry snapshot focused inFront item =
    let
        isFocused =
            item.metadata.carNumber == focused.metadata.carNumber
    in
    -- A grid rather than a row of flexed boxes, so that the places read as a
    -- column and the badges start where one another do.
    div
        [ attribute "data-rival" item.metadata.carNumber
        , class "grid grid-cols-[1.75rem_auto_1fr_auto] items-center gap-x-2 py-0.5 px-1 rounded"
        , class
            (if isFocused then
                "bg-accent/40"

             else
                ""
            )
        ]
        [ div [ class "text-[10px] text-muted-foreground whitespace-nowrap" ]
            [ text (Position.toOrdinal item.standing.positionInClass) ]
        , CarNumberBadge.viewRow item.metadata
        , div [ class "text-[11px] truncate" ]
            [ text (Driver.toInitialAndSurname item.currentDriver) ]
        , div [ class "text-[12px] tabular-nums whitespace-nowrap" ]
            [ text (Gap.toString (gapOf snapshot inFront item)) ]
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
        -- `Gap` alone: this row sets how narrow a column can be, and the
        -- chart labels its own baseline.
        [ ( GapChart, "Gap", \() -> orEmptyState (GapChart.gapChartView range snapshot rivals) )
        , ( PositionChart, "Positions", \() -> orEmptyState (PositionProgression.view range snapshot rivals) )
        , ( DistributionChart, "Distribution", \() -> orEmptyState (LapTimeDistribution.view range snapshot rivals) )
        ]


rivalsOf : Snapshot -> CarAt -> Rivals
rivalsOf snapshot focused =
    Rivals.around (Snapshot.toList snapshot) focused


startPositionOf : List Car -> CarAt -> Maybe Position
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


{-| Open or shut is the element's and not the model's, so the content is built
whether it is showing or not: hand it something lazy.
-}
disclosure : String -> Html msg -> Html msg
disclosure title content =
    details [ class sectionClass ]
        [ summary [ class ("cursor-pointer transition-colors hover:text-foreground " ++ headingClass) ]
            [ text title ]
        , div [ class "mt-2" ] [ content ]
        ]


container : String -> Html msg -> Html msg
container title content =
    div
        [ class ("grid gap-y-2 " ++ sectionClass) ]
        [ h3 [ class headingClass ] [ text title ]
        , content
        ]


sectionClass : String
sectionClass =
    "py-3 border-t border-t-border first:border-t-0 first:pt-0"


headingClass : String
headingClass =
    "text-[10px] font-medium uppercase tracking-[0.03em] text-muted-foreground"


emptyState : String -> Html msg
emptyState message =
    div
        [ class "p-5 text-center italic text-muted-foreground" ]
        [ text message ]
