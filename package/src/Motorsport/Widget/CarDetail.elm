module Motorsport.Widget.CarDetail exposing (Chart(..), view)

{-| Everything the race says about one car, drawn as plain inline content.

The car is the caller's selection; the rivals it is measured against are read
off the field around it, so the panel follows the race without the selection
changing.

@docs Chart, view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)
import List.Extra
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.LapWindow as LapWindow exposing (LapWindow)
import Motorsport.Race.Rivals as Rivals exposing (Rivals)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Widget as Widget
import Motorsport.Widget.CarDetail.ChartTabs as ChartTabs
import Motorsport.Widget.CarDetail.Header as Header
import Motorsport.Widget.CarDetail.LapTimes as LapTimes
import Motorsport.Widget.CarDetail.PositionProgression as PositionProgression
import Motorsport.Widget.CarDetail.Stint as Stint
import Motorsport.Widget.CarNumberBadge as CarNumberBadge
import Motorsport.Widget.Distribution as Distribution


{-| The race so far as the car ran it among its rivals, one view at a time.

Every one of them draws the cars the legend under it names, which is what keeps
them one group: the car's own laps are not a comparison and are read where its
other lap times are.

-}
type Chart
    = GapChart
    | PositionChart
    | DistributionChart


view :
    { activeChart : Chart
    , onSelectChart : Chart -> msg
    , activeRange : LapWindow
    , onSelectRange : LapWindow -> msg
    , lapHistoryOpen : Bool
    , onToggleLapHistory : msg
    }
    -> List Car
    -> Snapshot
    -> CarAt
    -> Html msg
view config cars snapshot focused =
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
                , historyOpen = config.lapHistoryOpen
                , onToggleHistory = config.onToggleLapHistory
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
        , charts config lapHistory snapshot rivals
        ]


{-| What the three charts are all drawn from: which laps, whose laps, the field
they stand in, and the cars the panel is comparing. Built once here so that the
tabs switch the chart and nothing else about what is being shown.
-}
type alias Comparison =
    { laps : ( Int, Int )
    , lapHistory : LapHistory
    , snapshot : Snapshot
    , rivals : Rivals
    }


charts :
    { a | activeChart : Chart, onSelectChart : Chart -> msg, activeRange : LapWindow, onSelectRange : LapWindow -> msg }
    -> LapHistory
    -> Snapshot
    -> Rivals
    -> Html msg
charts config lapHistory snapshot rivals =
    let
        comparison =
            { laps = LapWindow.laps config.activeRange rivals.focused.metadata.class snapshot
            , lapHistory = lapHistory
            , snapshot = snapshot
            , rivals = rivals
            }
    in
    Widget.container "Rivals"
        (div [ class "grid gap-y-2" ]
            [ chartTabs config comparison
            , legend snapshot rivals
            ]
        )


{-| The stretches of the race on offer, in the order the toggle draws them.

One setting for all three charts rather than one each: only one of them is
showing at a time, and a range that changed as the tabs did would read as the
chart changing.

-}
rangeOptions : List ( LapWindow, String )
rangeOptions =
    [ ( LapWindow.Recent (90 * 60 * 1000), "Last 1.5h" )
    , ( LapWindow.Recent (3 * 60 * 60 * 1000), "Last 3h" )
    , ( LapWindow.WholeRace, "All" )
    ]


{-| Which car each line of the chart above is, in running order, and how far up
or down the road each of them is, which is what the lines are about.

Nothing here restates the colour the charts draw a car in: the car's badge is
that colour already, and a second mark beside it is the same ink twice.

-}
legend : Snapshot -> Rivals -> Html msg
legend snapshot { focused, display } =
    div [ class "grid gap-y-px" ]
        (List.map (legendEntry snapshot focused) display)


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


chartTabs :
    { a | activeChart : Chart, onSelectChart : Chart -> msg, activeRange : LapWindow, onSelectRange : LapWindow -> msg }
    -> Comparison
    -> Html msg
chartTabs config { laps, lapHistory, snapshot, rivals } =
    ChartTabs.chartTabs config.onSelectChart
        config.activeChart
        (ChartTabs.segmentedControl config.onSelectRange config.activeRange rangeOptions)
        [ ( GapChart, "Gap to avg", \() -> GapChart.gapChartView laps lapHistory rivals )
        , ( PositionChart, "Positions", \() -> PositionProgression.view laps snapshot rivals )
        , ( DistributionChart, "Distribution", \() -> Distribution.view laps lapHistory rivals )
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


{-| The cars either side of this one in its class, which is what the charts
compare it against and the legend names.
-}
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
