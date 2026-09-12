module Motorsport.Widget.CarDetail exposing (Chart(..), view)

{-| Everything the race says about one car, drawn as plain inline content.

The car is the caller's selection; the rivals it is measured against are read
off the field around it, so the panel follows the race without the selection
changing.

@docs Chart, view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class, style)
import List.Extra
import Motorsport.Chart.Common exposing (Emphasis(..))
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Widget as Widget
import Motorsport.Widget.CarDetail.ChartTabs as ChartTabs
import Motorsport.Widget.CarDetail.Header as Header
import Motorsport.Widget.CarDetail.LapTimes as LapTimes
import Motorsport.Widget.CarDetail.PositionProgression as PositionProgression
import Motorsport.Widget.CarDetail.Stint as Stint
import Motorsport.Widget.CarNumberBadge as CarNumberBadge
import Motorsport.Widget.Distribution as Distribution
import Motorsport.Widget.SelectedCarsStrip.RivalGapSparkline as RivalGapSparkline


{-| The race so far as the car ran it among its rivals, one view at a time.

Every one of them draws the cars the legend above names, which is what keeps
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
            neighborsOf snapshot focused
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
            (Stint.view focused.status
                focused.metadata
                (LapHistory.get focused.metadata.carNumber lapHistory |> Stint.summarize)
            )
        , charts config lapHistory snapshot focused rivals
        ]


charts :
    { a | activeChart : Chart, onSelectChart : Chart -> msg }
    -> LapHistory
    -> Snapshot
    -> CarAt
    -> List CarAt
    -> Html msg
charts config lapHistory snapshot focused rivals =
    let
        lapRange =
            PositionProgression.lapRange snapshot focused.metadata.class
    in
    Widget.container "Rivals"
        (div [ class "grid gap-y-2" ]
            [ legend snapshot focused rivals
            , chartTabs config lapRange lapHistory snapshot focused rivals
            ]
        )


{-| Which car each line of the charts below is, in running order, drawn in the
colour the charts draw it in -- and how far up or down the road each of them is,
which is what the lines are about.
-}
legend : Snapshot -> CarAt -> List CarAt -> Html msg
legend snapshot focused rivals =
    div [ class "grid gap-y-px" ]
        (List.map (legendEntry snapshot focused) rivals)


legendEntry : Snapshot -> CarAt -> CarAt -> Html msg
legendEntry snapshot focused item =
    let
        isFocused =
            item.metadata.carNumber == focused.metadata.carNumber
    in
    div
        [ class "flex items-center gap-x-2 py-0.5 pl-1.5 pr-1 rounded-r border-l-2"
        , class
            (if isFocused then
                "bg-accent/40"

             else
                ""
            )
        , style "border-left-color" item.metadata.manufacturer.color
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
    { a | activeChart : Chart, onSelectChart : Chart -> msg }
    -> Maybe ( Int, Int )
    -> LapHistory
    -> Snapshot
    -> CarAt
    -> List CarAt
    -> Html msg
chartTabs config lapRange lapHistory snapshot focused rivals =
    ChartTabs.chartTabs config.onSelectChart
        config.activeChart
        [ ( GapChart
          , "Gap to avg"
          , \() ->
                case lapRange of
                    Just range ->
                        GapChart.gapChartView range lapHistory rivals

                    Nothing ->
                        text ""
          )
        , ( PositionChart
          , "Positions"
          , \() ->
                PositionProgression.view { width = 1000, height = 250 }
                    snapshot
                    { class = focused.metadata.class
                    , highlighted = List.map (.metadata >> .carNumber) rivals
                    }
          )
        , ( DistributionChart
          , "Distribution"
          , \() -> distribution lapHistory focused rivals
          )
        ]


{-| The three cars' laps on one scale, the selected car's curve the emphasised
one: how quick a car is reads only against what the cars it is racing are doing.
-}
distribution : LapHistory -> CarAt -> List CarAt -> Html msg
distribution lapHistory focused rivals =
    let
        series =
            rivals
                |> List.map
                    (\item ->
                        let
                            own =
                                Distribution.seriesOf lapHistory ( 1, focused.standing.lapsCompleted ) item
                        in
                        if item.metadata.carNumber == focused.metadata.carNumber then
                            own

                        else
                            { own | emphasis = Related }
                    )
    in
    case Distribution.scaleOf series of
        Just { domain, maxDensity } ->
            LapTimeDistribution.view
                { width = 1000, height = 250, domain = domain, maxDensity = maxDensity }
                series

        Nothing ->
            Widget.emptyState "No laps to compare"


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


{-| The selected car and the in-class rivals ahead of and behind it, in running
order, so the set follows the field as positions change. At a class edge only
the available rival is kept.
-}
neighborsOf : Snapshot -> CarAt -> List CarAt
neighborsOf snapshot focused =
    let
        neighbors =
            RivalGapSparkline.findNeighbors (Snapshot.toList snapshot) focused
    in
    List.filterMap identity
        [ List.head neighbors.ahead, Just focused, List.head neighbors.behind ]


startPositionOf : List Car -> CarAt -> Maybe Int
startPositionOf cars focused =
    carOf cars focused |> Maybe.map .startPosition


{-| The car's laps as the race holds them, which is the same list from one frame
to the next -- unlike the history, which is cut at the clock and built afresh
every frame.
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
