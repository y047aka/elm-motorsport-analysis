module Motorsport.Widget.SegmentStrip exposing
    ( sectors, miniSectors
    , sectorsRated, miniSectorsRated
    , overSectors, overMiniSectors
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
@docs overSectors, overMiniSectors
@docs colorOfRated

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class, style, title)
import Motorsport.Duration as Duration
import Motorsport.Lap.Performance as Performance exposing (RatedTime, SegmentState)
import Motorsport.Sector as Sector exposing (BySector, Sector)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector)


{-| The three sectors of the lap the car is on.
-}
sectors : BySector SegmentState -> Html msg
sectors states =
    div [ class sectorColumns ]
        (Sector.toList states
            |> List.map (\( sector, state ) -> progressCell (Sector.toString sector) state)
        )


{-| The three sectors of a lap that is over.
-}
sectorsRated : BySector (Maybe RatedTime) -> Html msg
sectorsRated rated =
    div [ class sectorColumns ]
        (Sector.toList rated
            |> List.map (\( sector, rating ) -> ratedCell (Sector.toString sector) rating)
        )


{-| The seventeen columns of the Le Mans strip: the fifteen mini-sectors in
track order, with a spacer where each of the first two sectors ends.
-}
miniSectors : ByMiniSector SegmentState -> Html msg
miniSectors states =
    miniStrip (\mini state -> progressCell (LeMans.toString mini) state) states


{-| The same seventeen columns for a lap that is over.
-}
miniSectorsRated : ByMiniSector (Maybe RatedTime) -> Html msg
miniSectorsRated rated =
    miniStrip (\mini rating -> ratedCell (LeMans.toString mini) rating) rated


{-| The strip's columns are as wide as the stretches of track they stand for, and
two of them are the gaps where a sector ends -- so the cells are laid out here
rather than mapped over, the spacers falling where they belong.
-}
miniStrip : (LeMans.LeMans2025MiniSector -> a -> Html msg) -> ByMiniSector a -> Html msg
miniStrip cell values =
    div [ class miniSectorColumns ]
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


{-| The columns a strip is laid out in, which anything drawn under one has to be
laid out in too: a name for a sector is under the stretch of track it names only
while the two are in the same grid.
-}
sectorColumns : String
sectorColumns =
    "grid grid-cols-[1fr_1fr_1fr] gap-x-1"


miniSectorColumns : String
miniSectorColumns =
    "grid grid-cols-[2fr_2fr_3fr_0.5fr_5fr_1fr_3fr_3fr_0.5fr_1fr_5fr_3fr_2fr_1fr_1fr_1fr_1fr] gap-x-px"


{-| A reading per sector, the strip the lap was read from, and the sectors' own
names -- the three rows of a lap at the sector grain, in the columns the strip
is drawn in so that each sector's reading, its stretch of the strip and its name
are above one another.

A reading wider than the stretch it stands for hangs over the edges of it rather
than being cut or wrapped: the sectors of a lap are not equal, and the shortest
of them is narrower than a time.

-}
overSectors : { cells : BySector (Html msg), strip : Html msg } -> Html msg
overSectors { cells, strip } =
    rows
        [ div [ class sectorColumns ] (Sector.values cells)
        , strip
        , div [ class sectorColumns ] (List.map (axisLabel "") Sector.all)
        ]


{-| The same three rows over a strip of mini-sectors, where a sector spans the
mini-sectors it is driven in -- three of them, four and eight -- with the gaps
where the first two sectors end falling between.
-}
overMiniSectors : { cells : BySector (Html msg), strip : Html msg } -> Html msg
overMiniSectors { cells, strip } =
    rows
        [ spanning (\_ cell -> cell) cells
        , strip
        , spanning (\sector _ -> axisLabel "" sector) cells
        ]


{-| One item per sector, laid over the mini-sectors that sector is driven in.
-}
spanning : (Sector -> Html msg -> Html msg) -> BySector (Html msg) -> Html msg
spanning toCell cells =
    div [ class miniSectorColumns ]
        [ div [ class "col-span-3 min-w-0" ] [ toCell Sector.S1 cells.s1 ]
        , spacer
        , div [ class "col-span-4 min-w-0" ] [ toCell Sector.S2 cells.s2 ]
        , spacer
        , div [ class "col-span-8 min-w-0" ] [ toCell Sector.S3 cells.s3 ]
        ]


rows : List (Html msg) -> Html msg
rows =
    div [ class "grid gap-y-0.5" ]


axisLabel : String -> Sector -> Html msg
axisLabel span sector =
    div [ class (span ++ " text-[9px] text-center text-muted-foreground leading-none") ]
        [ text (Sector.toString sector) ]


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
