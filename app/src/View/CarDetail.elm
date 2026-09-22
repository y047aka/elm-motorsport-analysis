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

import Html exposing (Html, button, div, h3, text)
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
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
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import View.CarDetail.ChartTabs as ChartTabs
import View.CarDetail.Header as Header
import View.CarDetail.LapTable as LapTable
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
            , toLeader = gapOf snapshot { inFront = Rivals.leader rivals, chasing = Just focused }
            , onClose = config.onClose
            }
            focused
        , Html.map config.toMsg (panel config.comparison config.showing cars snapshot rivals focused)
        ]


{-| The gap a classification prints between two cars: the time between them
where the road holds them together, and the whole laps where it does not. No
gap at all where one of them is not there, which is what a class runs out of at
its edges.
-}
gapOf : Snapshot -> { inFront : Maybe CarAt, chasing : Maybe CarAt } -> Gap
gapOf snapshot pair =
    case ( pair.inFront, pair.chasing ) of
        ( Just inFront, Just chasing ) ->
            case Snapshot.gapBetween inFront chasing snapshot of
                Just delta ->
                    Gap.seconds delta

                Nothing ->
                    Gap.laps (inFront.standing.lapsCompleted - chasing.standing.lapsCompleted)

        _ ->
            Gap.none


{-| Everything under the header, which is the column's own and reports to it.

The rivals are named first, under the header and above everything measured: the
three of them are where the header's standing line stops, so a reader has who
this car is racing before they have a single time. Then the lap it is turning,
then those three drawn out over the race, then the shape of the race it has run.

The lap table is last because it is the one thing here that is not a summary:
four hundred rows opened in the middle would push everything a reader had come
for off the bottom of a column.

-}
panel : Comparison -> Model -> List Car -> Snapshot -> Rivals -> CarAt -> Html Msg
panel comparison (Model showing) cars snapshot rivals focused =
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
        , disclosure
            { title = "Lap history"
            , open = showing.lapHistoryOpen
            , onToggle = ToggledLapHistory
            }
            (\() -> LapTable.view laps focused.standing.lapsCompleted)
        ]


{-| The three cars of the fight drawn out over the race, one view at a time.

Named for the state the page hands it, which is what the tabs and the stretch
controls set: the section is one comparison, and the columns beside it are all
showing it.

-}
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

The durations are given bare. `Last` was on two of the three and said nothing
the third did not also mean, and this row is the widest thing in the panel --
what it asks for is what a column has to be.

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
the panel is for, which is how a classification prints an interval and how the
header above reads. Measured out from the middle, the same figure appeared on
whichever row was not the reader's car and with the sign the wrong way round --
the car ahead carried the gap belonging to the car chasing it.

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
            [ text ("P" ++ String.fromInt item.standing.positionInClass) ]
        , CarNumberBadge.viewRow item.metadata
        , div [ class "text-[11px] truncate" ]
            [ text (Driver.toInitialAndSurname item.currentDriver) ]
        , div [ class "text-[12px] tabular-nums whitespace-nowrap" ]
            [ text (Gap.toString (gapOf snapshot { inFront = inFront, chasing = Just item })) ]
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


{-| A section the reader opens, drawn as the sections above it are so that the
panel keeps one rhythm. The title is the control: a title with a control beside
it would be two things to press for one thing to happen.

The content is a thunk, so a table the reader has not asked for is not built
sixty times a second behind a closed section.

-}
disclosure : { title : String, open : Bool, onToggle : msg } -> (() -> Html msg) -> Html msg
disclosure config content =
    div
        [ class sectionClass ]
        (button
            [ onClick config.onToggle
            , attribute "aria-expanded"
                (if config.open then
                    "true"

                 else
                    "false"
                )
            , class "flex items-center gap-x-1.5 font-semibold text-sm text-left cursor-pointer transition-colors hover:text-muted-foreground"
            ]
            [ div [ class "text-[9px]" ]
                [ text
                    (if config.open then
                        "▼"

                     else
                        "▶"
                    )
                ]
            , text config.title
            ]
            :: (if config.open then
                    [ content () ]

                else
                    []
               )
        )


container : String -> Html msg -> Html msg
container title content =
    div
        [ class sectionClass ]
        [ h3 [ class "font-semibold text-sm" ] [ text title ]
        , content
        ]


{-| What a section is, which is a title and its content and a rule above to say
where the one before it ended. A card apiece drew five boxes inside a sixth --
the column is already a card, and boxing what is in it said nothing about the
panel except that its parts are parts.

The rule is skipped on the first section, which the header above it already
parts from, and so is the padding the rule needs under it.

-}
sectionClass : String
sectionClass =
    "grid gap-y-2 py-3 border-t border-t-border first:border-t-0 first:pt-0"


emptyState : String -> Html msg
emptyState message =
    div
        [ class "p-5 text-center italic text-muted-foreground" ]
        [ text message ]
