module Motorsport.Widget.CarDetail exposing (Chart(..), Range(..), view)

{-| Everything the race says about one car, drawn as plain inline content.

The car is the caller's selection; the rivals it is measured against are read
off the field around it, so the panel follows the race without the selection
changing.

@docs Chart, Range, view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)
import List.Extra
import Motorsport.Chart.Common exposing (Emphasis(..))
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Instant as Instant
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

Every one of them draws the cars the legend under it names, which is what keeps
them one group: the car's own laps are not a comparison and are read where its
other lap times are.

-}
type Chart
    = GapChart
    | PositionChart
    | DistributionChart


{-| How much of the race the charts are drawn over: all of it run so far, or
the last stretch of it.

The stretch is a length of time rather than a count of laps, because that is
what a race is read in -- an hour of it is an hour of it whether the cars spent
it lapping under a safety car or flat out.

One setting for all three rather than one each: only one chart is showing at a
time, and a range that changed as the tabs did would read as the chart changing.

-}
type Range
    = WholeRace
    | Recent Duration


view :
    { activeChart : Chart
    , onSelectChart : Chart -> msg
    , activeRange : Range
    , onSelectRange : Range -> msg
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
            (Stint.view
                { status = focused.status, stops = focused.pitStops }
                focused.metadata
                (LapHistory.get focused.metadata.carNumber lapHistory |> Stint.summarize)
            )
        , charts config lapHistory snapshot focused rivals
        ]


charts :
    { a | activeChart : Chart, onSelectChart : Chart -> msg, activeRange : Range, onSelectRange : Range -> msg }
    -> LapHistory
    -> Snapshot
    -> CarAt
    -> Rivals
    -> Html msg
charts config lapHistory snapshot focused rivals =
    let
        range =
            lapsIn config.activeRange snapshot focused
    in
    Widget.container "Rivals"
        (div [ class "grid gap-y-2" ]
            [ chartTabs config range lapHistory snapshot focused rivals
            , legend snapshot focused rivals.display
            ]
        )


{-| The selected range as the lap numbers each chart keeps its laps by, both
ends read off the car's own class rather than the race: every car these charts
draw is in the one class, and a slower class's laps both run out short of the
race leader's and take longer to come round.
-}
lapsIn : Range -> Snapshot -> CarAt -> ( Int, Int )
lapsIn range snapshot focused =
    let
        classCars =
            Snapshot.inClass focused.metadata.class snapshot

        latest =
            classCars
                |> List.map (.standing >> .lapsCompleted)
                |> List.maximum
                |> Maybe.withDefault 1
                |> max 1
    in
    case range of
        WholeRace ->
            ( 1, latest )

        Recent window ->
            ( firstLapSince window snapshot classCars, latest )


{-| The class leader's first lap completed no earlier than `window` ago, which
is where a chart drawn over that stretch starts. Lap 1 where the class has not
been running that long yet.
-}
firstLapSince : Duration -> Snapshot -> List CarAt -> Int
firstLapSince window snapshot classCars =
    let
        threshold =
            Instant.subtract window (Snapshot.elapsed snapshot)
    in
    classCars
        |> List.head
        |> Maybe.map (\leading -> LapHistory.get leading.metadata.carNumber (Snapshot.lapHistory snapshot))
        |> Maybe.andThen (List.Extra.find (\lap -> Instant.compare lap.elapsed threshold /= LT))
        |> Maybe.map .lap
        |> Maybe.withDefault 1


{-| The ranges on offer, in the order the toggle draws them.
-}
rangeOptions : List ( Range, String )
rangeOptions =
    [ ( Recent (90 * 60 * 1000), "Last 1.5h" )
    , ( Recent (3 * 60 * 60 * 1000), "Last 3h" )
    , ( WholeRace, "All" )
    ]


{-| Which car each line of the chart above is, in running order, and how far up
or down the road each of them is, which is what the lines are about.

Nothing here restates the colour the charts draw a car in: the car's badge is
that colour already, and a second mark beside it is the same ink twice.

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
    { a | activeChart : Chart, onSelectChart : Chart -> msg, activeRange : Range, onSelectRange : Range -> msg }
    -> ( Int, Int )
    -> LapHistory
    -> Snapshot
    -> CarAt
    -> Rivals
    -> Html msg
chartTabs config range lapHistory snapshot focused rivals =
    ChartTabs.chartTabs config.onSelectChart
        config.activeChart
        (ChartTabs.segmentedControl config.onSelectRange config.activeRange rangeOptions)
        [ ( GapChart
          , "Gap to avg"
          , \() -> GapChart.gapChartView range lapHistory rivals
          )
        , ( PositionChart
          , "Positions"
          , \() ->
                PositionProgression.view { width = 1000, height = 250 }
                    snapshot
                    { class = focused.metadata.class
                    , highlighted = List.map (.metadata >> .carNumber) rivals.display
                    , lapRange = range
                    }
          )
        , ( DistributionChart
          , "Distribution"
          , \() -> distribution range lapHistory focused rivals.display
          )
        ]


{-| The three cars' laps on one scale, the selected car's curve the emphasised
one: how quick a car is reads only against what the cars it is racing are doing.
-}
distribution : ( Int, Int ) -> LapHistory -> CarAt -> List CarAt -> Html msg
distribution range lapHistory focused rivals =
    let
        series =
            rivals
                |> List.map
                    (\item ->
                        let
                            own =
                                Distribution.seriesOf lapHistory range item
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


{-| The cars the charts are about, and the cars the gap chart measures them
against.

`display` is the selected car and the in-class rival either side of it, in
running order, so the set follows the field as positions change. `reference` is
the same group widened to two rivals a side: only the gap chart reads it, and
only to average a baseline out of it.

-}
type alias Rivals =
    { display : List CarAt
    , reference : List CarAt
    }


{-| Three cars to draw and up to five to baseline them on, the same populations
the strip's sparkline is built from.

Baselining on exactly the three cars drawn locks the picture into a mirror
image: the three gaps sum to zero, so the outer two lines can only move against
each other. Two more cars either side loosen that into an approximate centring
and let all three move. What the chart is read for -- two lines converging or
diverging -- is the difference between them, which no choice of baseline
changes.

At a class edge only the available rivals are kept.

-}
neighborsOf : Snapshot -> CarAt -> Rivals
neighborsOf snapshot focused =
    let
        neighbors =
            RivalGapSparkline.findNeighbors (Snapshot.toList snapshot) focused
    in
    { display =
        List.filterMap identity
            [ List.head neighbors.ahead, Just focused, List.head neighbors.behind ]
    , reference = neighbors.ahead ++ focused :: neighbors.behind
    }


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
