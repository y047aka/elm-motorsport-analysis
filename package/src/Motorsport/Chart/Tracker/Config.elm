module Motorsport.Chart.Tracker.Config exposing
    ( TrackConfig, Share
    , MiniSectorShares(..)
    , computeProgress, calcSectorBoundaries
    )

{-| The track's proportions: how much of the lap each stretch of it takes, and
where round the lap that stretch begins.

Divided by the CLI, which reads the whole file where this side would have to
wait for every lap of it to arrive first, and decoded in `Data.Wec`.

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


{-| The mini-sectors' shares, on the rounds whose feed splits the lap that far.
-}
type MiniSectorShares
    = NoMiniSectors
    | MiniSectorShares (ByMiniSector Share)


{-| How far round the lap a car is, as a fraction of it.

Read at the finest grain the circuit and the car's own lap both have, so that a
car sits between the same two boundaries the drawn track puts it between.

-}
computeProgress : TrackConfig -> CarAt -> Float
computeProgress config car =
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


{-| Where round the lap the three-sector grain puts the car, falling back to the
car's own lap progress for a lap with no sector time to place it by -- measured
against that lap's total time, so it takes no account of where the boundaries
between the stretches fall.

Not a `let` in [`computeProgress`](#computeProgress): Elm would work it out even
when the finer grain answers, once per car per frame.

-}
bySector : TrackConfig -> CarAt -> Float
bySector config car =
    case car.currentLap.sector of
        Just { sector, progress } ->
            along (Sector.get sector config.sectors) progress

        Nothing ->
            car.currentLap.progress


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
