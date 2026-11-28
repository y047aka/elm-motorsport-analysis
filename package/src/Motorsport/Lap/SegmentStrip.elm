module Motorsport.Lap.SegmentStrip exposing
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
import Motorsport.MiniSector exposing (MiniSectors)
import Motorsport.Sector as Sector exposing (BySector, Sector)


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


{-| The mini-sector strip: the round's mini-sectors in track order, with a spacer
where each of the first two sectors ends.
-}
miniSectors : MiniSectors SegmentState -> Html msg
miniSectors states =
    miniStrip progressCell states


{-| The same strip for a lap that is over.
-}
miniSectorsRated : MiniSectors (Maybe RatedTime) -> Html msg
miniSectorsRated rated =
    miniStrip ratedCell rated


{-| The strip's columns are as wide as the stretches of track they stand for, and
two of them are the gaps where a sector ends -- so the cells are laid out with
those gaps rather than mapped straight over the mini-sectors, which is why the
round has to have exactly as many mini-sectors as the columns are wide.
-}
miniStrip : (String -> a -> Html msg) -> MiniSectors a -> Html msg
miniStrip cell entries =
    div [ class miniSectorColumns ]
        (entries
            |> List.map (\{ name, value } -> cell name value)
            |> gapsAfter [ 3, 7 ]
        )


{-| A spacer after each of these many cells. `overMiniSectors` spans the same
grouping: three mini-sectors, four and eight.
-}
gapsAfter : List Int -> List (Html msg) -> List (Html msg)
gapsAfter positions cells =
    gapsFrom positions 1 cells


gapsFrom : List Int -> Int -> List (Html msg) -> List (Html msg)
gapsFrom positions count cells =
    case cells of
        [] ->
            []

        cell :: rest ->
            let
                tail =
                    gapsFrom positions (count + 1) rest
            in
            if List.member count positions then
                cell :: spacer :: tail

            else
                cell :: tail


{-| The columns a strip is laid out in, which anything drawn over or under one
has to be laid out in too.
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
        , div [ class sectorColumns ] (List.map axisLabel Sector.all)
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
        , spanning (\sector _ -> axisLabel sector) cells
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


axisLabel : Sector -> Html msg
axisLabel sector =
    div [ class "text-[9px] text-center text-muted-foreground leading-none" ]
        [ text (Sector.toString sector) ]


spacer : Html msg
spacer =
    div [] []


{-| One cell of a strip drawn from where the car has got to. A stretch the car
has not reached draws nothing.
-}
progressCell : String -> SegmentState -> Html msg
progressCell label state =
    let
        ( widthPercent, backgroundColor_ ) =
            case state of
                Performance.NotEntered ->
                    ( "0%", "transparent" )

                Performance.InProgress progress ->
                    ( String.fromFloat (progress * 100) ++ "%", Performance.inProgressColor )

                Performance.Completed rated ->
                    ( "100%", colorOfRated rated )
    in
    div
        [ class cellClass
        , style "width" widthPercent
        , style "background-color" backgroundColor_
        , title (readingOf label (Performance.ratedOf state))
        ]
        []


cellClass : String
cellClass =
    "h-[6px] rounded-[1px]"


{-| One cell of a strip drawn from a segment that is over.
-}
ratedCell : String -> Maybe RatedTime -> Html msg
ratedCell label rated =
    div
        [ class cellClass
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
    Maybe.map .performance >> Performance.colorOf
