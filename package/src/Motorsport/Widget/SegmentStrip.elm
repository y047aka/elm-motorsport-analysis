module Motorsport.Widget.SegmentStrip exposing
    ( sectors, miniSectors
    , sectorsRated, miniSectorsRated
    , colorOfRated
    )

{-| A lap drawn as the segments it is timed in: a thin bar per sector, or per
mini-sector where the circuit records them.

Two readings are drawn the same way. A lap under way is a
[`SegmentState`](Motorsport-Lap-Performance#SegmentState) per segment -- white as
far as the car has got through the one it is in, its rating's colour once the
whole of it is behind. A lap that is over is a rating per segment and nothing
else.

@docs sectors, miniSectors
@docs sectorsRated, miniSectorsRated
@docs colorOfRated

-}

import Html exposing (Html, div)
import Html.Attributes exposing (class, style, title)
import Motorsport.Duration as Duration
import Motorsport.Lap.Performance as Performance exposing (RatedTime, SegmentState)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector)


{-| The three sectors of the lap the car is on.
-}
sectors : BySector SegmentState -> Html msg
sectors states =
    div [ class "grid grid-cols-[1fr_1fr_1fr] gap-x-1" ]
        (Sector.toList states
            |> List.map (\( sector, state ) -> progressCell (Sector.toString sector) state)
        )


{-| The three sectors of a lap that is over.
-}
sectorsRated : BySector (Maybe RatedTime) -> Html msg
sectorsRated rated =
    div [ class "grid grid-cols-[1fr_1fr_1fr] gap-x-1" ]
        (Sector.toList rated
            |> List.map (\( sector, rating ) -> ratedCell (Sector.toString sector) rating)
        )


{-| The seventeen columns of the Le Mans strip: the fifteen mini-sectors in
track order, with a spacer where each of the first two sectors ends.
-}
miniSectors : ByMiniSector SegmentState -> Html msg
miniSectors states =
    strip (\mini state -> progressCell (LeMans.toString mini) state) states


{-| The same seventeen columns for a lap that is over.
-}
miniSectorsRated : ByMiniSector (Maybe RatedTime) -> Html msg
miniSectorsRated rated =
    strip (\mini rating -> ratedCell (LeMans.toString mini) rating) rated


{-| The strip's columns are as wide as the stretches of track they stand for, and
two of them are the gaps where a sector ends -- so the cells are laid out here
rather than mapped over, the spacers falling where they belong.
-}
strip : (LeMans.LeMans2025MiniSector -> a -> Html msg) -> ByMiniSector a -> Html msg
strip cell values =
    div [ class "grid grid-cols-[2fr_2fr_3fr_0.5fr_5fr_1fr_3fr_3fr_0.5fr_1fr_5fr_3fr_2fr_1fr_1fr_1fr_1fr] gap-x-px" ]
        [ cell LeMans.SCL2 values.scl2
        , cell LeMans.Z4 values.z4
        , cell LeMans.IP1 values.ip1
        , spacer
        , cell LeMans.Z12 values.z12
        , cell LeMans.SCLC values.sclc
        , cell LeMans.A7_1 values.a7_1
        , cell LeMans.IP2 values.ip2
        , spacer
        , cell LeMans.A8_1 values.a8_1
        , cell LeMans.SCLB values.sclb
        , cell LeMans.PORIN values.porin
        , cell LeMans.POROUT values.porout
        , cell LeMans.PITREF values.pitref
        , cell LeMans.SCL1 values.scl1
        , cell LeMans.FORDOUT values.fordout
        , cell LeMans.FL values.fl
        ]


spacer : Html msg
spacer =
    div [] []


{-| One cell of a strip drawn from where the car has got to.

A stretch the car has not reached draws nothing, which is what a zero-width fill
came to anyway -- the difference is that the reading now says so, rather than
leaving the cell to read it back out of a number.

-}
progressCell : String -> SegmentState -> Html msg
progressCell label state =
    let
        ( widthPercent, backgroundColor_ ) =
            case state of
                Performance.NotEntered ->
                    ( "0%", "transparent" )

                Performance.InProgress progress ->
                    ( String.fromFloat (progress * 100) ++ "%", "oklch(1 0 0)" )

                Performance.Completed rated ->
                    ( "100%", colorOfRated rated )
    in
    div
        [ class "h-[3px] rounded-[1px]"
        , style "width" widthPercent
        , style "background-color" backgroundColor_
        , title (readingOf label (Performance.ratedOf state))
        ]
        []


{-| One cell of a strip drawn from a segment that is over.
-}
ratedCell : String -> Maybe RatedTime -> Html msg
ratedCell label rated =
    div
        [ class "h-[3px] rounded-[1px]"
        , style "background-color" (colorOfRated rated)
        , title (readingOf label rated)
        ]
        []


{-| What the cell stands for, for a reader who wants the number a three-pixel
bar cannot carry.
-}
readingOf : String -> Maybe RatedTime -> String
readingOf label rated =
    case rated of
        Just time ->
            label ++ " " ++ Duration.toString time.time

        Nothing ->
            label


{-| The colour of a rating that may not exist.

A sector, mini-sector or lap the source data has no time for has no rating
either, and takes the standard colour: there is nothing to rate it against.

-}
colorOfRated : Maybe RatedTime -> String
colorOfRated =
    Maybe.map .performance
        >> Maybe.withDefault Performance.Standard
        >> Performance.toColorVariable
