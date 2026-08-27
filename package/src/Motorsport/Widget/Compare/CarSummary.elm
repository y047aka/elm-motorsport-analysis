module Motorsport.Widget.Compare.CarSummary exposing (carSummary, placeholderCard)

{-| Per-car summary card (header + standings strip + lap-time panel) for the
Compare widget, plus the placeholder that fills an unselected slot.

@docs carSummary, placeholderCard

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)
import Html.Styled
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Driver as Driver
import Motorsport.Gap as Gap
import Motorsport.Race.LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Status exposing (Status(..))
import Motorsport.Widget.CarNumberBadge as CarNumberBadge
import Motorsport.Widget.Compare.Distribution as Distribution
import Motorsport.Widget.Compare.Style exposing (panelLabel)
import Motorsport.Widget.SectorAndLaps as SectorAndLaps


{-| The glassmorphism panel background/border, shared by the two panels below.
Kept as one string so both stay in sync with each other and with
[`Style.glassPanel`](Motorsport-Widget-Compare-Style#glassPanel).
-}
glassPanelClass : String
glassPanelClass =
    "bg-[var(--glass-panel-bg)] border border-[var(--glass-panel-border)] rounded-lg"


{-| Subtle placeholder filling an unselected slot. Nudges toward the selector above.
-}
placeholderCard : Html msg
placeholderCard =
    div
        [ class "grid place-items-center min-h-[100px] border border-dashed border-[hsl(0_0%_100%/0.15)] rounded-lg text-[11px] text-[hsl(0_0%_100%/0.35)]" ]
        [ text "車両を追加" ]


carSummary : Maybe ( Int, Int ) -> Maybe Distribution.Scale -> LapHistory -> CarAt -> Html msg
carSummary lapRange distScale lapHistory item =
    div
        [ class "grid grid-rows-[1fr_auto_auto] gap-y-3 content-start" ]
        [ header item
        , summaryStats item
        , lapTimePanel lapRange distScale lapHistory item
        ]


{-| Panel that gathers "sector progress + Current/Last lap + lap-time distribution"
into one, concentrating all lap-time display here. The distribution draws one car
as a KDE curve, with both axes (lap time / density) aligned to the shared
`distScale` so the three columns share one scale (height = peak sharpness = pace
stability, comparable across cars).
-}
lapTimePanel : Maybe ( Int, Int ) -> Maybe Distribution.Scale -> LapHistory -> CarAt -> Html msg
lapTimePanel maybeRange maybeScale lapHistory item =
    div
        [ class (glassPanelClass ++ " p-2 grid gap-y-2") ]
        [ panelLabel "Lap time"
        , div [ class "pb-1" ]
            [ SectorAndLaps.view item ]
        , div
            [ class "pt-1 border-t border-t-[oklch(1_0_0/0.05)]" ]
            [ case ( maybeRange, maybeScale ) of
                ( Just range, Just { domain, maxDensity } ) ->
                    Html.Styled.toUnstyled
                        (LapTimeDistribution.view
                            { width = 300, height = 70, domain = domain, maxDensity = maxDensity }
                            [ Distribution.seriesOf lapHistory range item ]
                        )

                _ ->
                    text ""
            ]
        ]


header : CarAt -> Html msg
header item =
    div
        [ class "grid grid-cols-[auto_1fr_auto] items-start gap-x-2" ]
        [ CarNumberBadge.view item.metadata
        , div
            [ class "grid gap-y-0.5" ]
            [ div [ class "text-[14px]" ]
                [ text item.metadata.team ]
            , driverList item
            ]
        , statusBadge item.status
        ]


{-| As in the leaderboard, emphasizes the driver currently at the wheel and dims
the others.
-}
driverList : CarAt -> Html msg
driverList item =
    let
        isCurrentDriver driver =
            Driver.isSame driver item.currentDriver
    in
    div
        [ class "flex flex-wrap gap-x-2 gap-y-0.5 text-[11px]" ]
        (List.map
            (\driver ->
                div
                    [ class
                        (if isCurrentDriver driver then
                            "opacity-100"

                         else
                            "opacity-40"
                        )
                    ]
                    [ text (Driver.toFullName driver) ]
            )
            item.metadata.drivers
        )


statusBadge : Status -> Html msg
statusBadge status =
    case status of
        InPit ->
            div
                [ class "grid place-items-center py-px px-1.5 rounded-full border border-[hsl(0_0%_100%/0.6)] text-[9px] font-bold" ]
                [ text "IN PIT" ]

        Retired ->
            div
                [ class "py-px px-1.5 rounded-[3px] bg-[hsl(0_70%_45%)] text-[9px] font-bold tracking-wider" ]
                [ text "RETIRED" ]

        _ ->
            text ""


summaryStats : CarAt -> Html msg
summaryStats item =
    div
        [ class (glassPanelClass ++ " grid grid-cols-5") ]
        [ statCell "Pos" (text ("P" ++ String.fromInt item.standing.position))
        , statCell "Class" (text ("P" ++ String.fromInt item.standing.positionInClass))
        , statCell "Laps" (text (String.fromInt item.standing.lapsCompleted))
        , statCell "Gap" (text (Gap.toString item.standing.gapToLeader))
        , statCell "Int" (text (Gap.toString item.standing.intervalToAhead))
        ]


{-| Small cell for packing position/gap values into a single strip. Cells are
separated by a left divider (the first cell has none).
-}
statCell : String -> Html msg -> Html msg
statCell label valueHtml =
    div
        [ class "grid gap-y-px justify-items-center py-1 px-0.5 border-l border-l-[hsl(0_0%_100%/0.05)] first:border-l-0" ]
        [ div
            [ class "text-[8px] uppercase tracking-[0.03em] opacity-50" ]
            [ text label ]
        , div
            [ class "text-[12px] tabular-nums" ]
            [ valueHtml ]
        ]
