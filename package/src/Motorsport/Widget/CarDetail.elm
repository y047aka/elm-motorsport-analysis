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
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Widget as Widget
import Motorsport.Widget.CarDetail.ChartTabs as ChartTabs
import Motorsport.Widget.CarDetail.Header as Header
import Motorsport.Widget.CarDetail.LapTable as LapTable
import Motorsport.Widget.CarDetail.LiveTiming as LiveTiming
import Motorsport.Widget.CarDetail.PositionProgression as PositionProgression
import Motorsport.Widget.CarDetail.Stint as Stint
import Motorsport.Widget.CarNumberBadge as CarNumberBadge
import Motorsport.Widget.Distribution as Distribution
import Motorsport.Widget.SelectedCarsStrip.RivalGapSparkline as RivalGapSparkline


{-| The history the panel draws under the car's present, one at a time. The
first three are the car among its rivals; the last is its own laps.
-}
type Chart
    = GapChart
    | PositionChart
    | DistributionChart
    | LapTable


view :
    { activeChart : Chart
    , onSelectChart : Chart -> msg
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
        , Widget.container "Live timing"
            (LiveTiming.view (Snapshot.bestTimes snapshot) focused)
        , Widget.container "Stints & pit stops"
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
    div [ class "grid gap-y-2" ]
        [ legend snapshot focused rivals
        , chartTabs config lapRange lapHistory snapshot focused rivals
        ]


{-| Which car each line of the charts below is, in running order, drawn in the
colour the charts draw it in.
-}
legend : Snapshot -> CarAt -> List CarAt -> Html msg
legend snapshot focused rivals =
    div [ class "grid gap-y-1" ]
        (List.map (legendEntry snapshot focused) rivals)


legendEntry : Snapshot -> CarAt -> CarAt -> Html msg
legendEntry snapshot focused item =
    div
        [ class "flex items-center gap-x-2 p-1 rounded-lg border-l-2 bg-card"
        , style "border-left-color" item.metadata.manufacturer.color
        ]
        [ CarNumberBadge.viewRow item.metadata
        , div [ class "text-[11px] truncate flex-1" ] [ text item.metadata.team ]
        , div [ class "text-[10px] text-muted-foreground whitespace-nowrap" ]
            [ text ("Class P" ++ String.fromInt item.standing.positionInClass) ]
        , div [ class "text-[12px] tabular-nums" ]
            [ text
                (if item.metadata.carNumber == focused.metadata.carNumber then
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
          , "Gap to group avg"
          , \() ->
                case lapRange of
                    Just range ->
                        GapChart.gapChartView range lapHistory rivals

                    Nothing ->
                        text ""
          )
        , ( PositionChart
          , "Position progression"
          , \() ->
                PositionProgression.view { width = 1000, height = 250 }
                    snapshot
                    { class = focused.metadata.class
                    , highlighted = List.map (.metadata >> .carNumber) rivals
                    }
          )
        , ( DistributionChart
          , "Lap time distribution"
          , \() -> distribution lapHistory focused rivals
          )
        , ( LapTable
          , "Laps"
          , \() ->
                LapTable.view (Snapshot.bestTimes snapshot)
                    (LapHistory.get focused.metadata.carNumber lapHistory)
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
    cars
        |> List.Extra.find (\car -> car.metadata.carNumber == focused.metadata.carNumber)
        |> Maybe.map .startPosition


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
