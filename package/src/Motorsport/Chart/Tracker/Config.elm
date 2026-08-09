module Motorsport.Chart.Tracker.Config exposing
    ( TrackConfig, Share
    , MiniSectorShares(..)
    , computeProgress, calcSectorBoundaries
    )

{-| The track's proportions: how much of the lap each stretch of it takes, and
where round the lap that stretch begins.

A stretch takes the share of the lap that its record does of the lap record, so
the track is drawn to how quick each part of it is. That division is the CLI's
to make -- it reads the whole file, where this side would have to wait for every
lap of it to arrive first -- and arrives decoded in `Data.Wec`.

Read for every car of every frame, which is what decides the shape here: the
shares are held per sector and per mini-sector, so reading one is
[`Sector.get`](Motorsport-Sector#get) rather than a scan.

@docs TrackConfig, Share
@docs MiniSectorShares
@docs computeProgress, calcSectorBoundaries

-}

import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector)


{-| The whole lap, divided. Both grains cover the same lap, so a car can be
placed by either.
-}
type alias TrackConfig =
    { sectors : BySector Share
    , miniSectors : MiniSectorShares
    }


{-| One stretch of the lap: where it begins and how much of the lap it takes,
both as fractions of the whole. Which stretch it is belongs to the position in
a `BySector` or a `ByMiniSector`, which is what lets both grains share the type.
-}
type alias Share =
    { start : Float
    , share : Float
    }


{-| The mini-sectors' shares, where the circuit has mini-sectors --
[`Circuit.Segmentation`](Motorsport-Circuit#Segmentation) one step further on.
-}
type MiniSectorShares
    = NoMiniSectors
    | MiniSectorShares (ByMiniSector Share)


{-| How far round the lap a car is, as a fraction of it.

Read at the finest grain the circuit and the car's own lap both have. A car's
lap progress is preferred to either where there is one, since it is measured
against the lap's actual time rather than against the records.

-}
computeProgress : TrackConfig -> CarAt -> Float
computeProgress config car =
    if car.currentLap.progress > 0 then
        car.currentLap.progress

    else
        case ( config.miniSectors, car.currentLap.miniSectors ) of
            ( MiniSectorShares shares, Snapshot.Recorded { current } ) ->
                case current of
                    Just miniSector ->
                        along (LeMans.get miniSector.miniSector shares) miniSector.progress

                    -- Nowhere to place the car at the finer grain.
                    Nothing ->
                        bySector config car

            _ ->
                bySector config car


{-| Where round the lap the three-sector grain puts the car. Not a `let` in
[`computeProgress`](#computeProgress): Elm would work it out even when the finer
grain answers, once per car per frame.
-}
bySector : TrackConfig -> CarAt -> Float
bySector config car =
    along (Sector.get car.currentLap.sector.sector config.sectors) car.currentLap.sector.progress


along : Share -> Float -> Float
along { start, share } progress =
    start + progress * share


{-| Where round the lap one stretch ends and the next begins, for the lines
drawn across the track.

At the finest grain the circuit has, since a sector boundary is also a
mini-sector boundary. A stretch no lap has set a time for takes no share and
so marks nothing; the line and the flag are not boundaries between stretches
and are dropped.

-}
calcSectorBoundaries : TrackConfig -> List Float
calcSectorBoundaries config =
    let
        stretches =
            case config.miniSectors of
                MiniSectorShares shares ->
                    LeMans.values shares

                NoMiniSectors ->
                    Sector.values config.sectors
    in
    stretches
        |> List.filterMap
            (\{ start, share } ->
                if share <= 0 then
                    Nothing

                else
                    Just (start + share)
            )
        |> List.filter (\boundary -> boundary > 0 && boundary < 1)
