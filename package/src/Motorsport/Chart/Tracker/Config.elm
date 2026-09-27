module Motorsport.Chart.Tracker.Config exposing
    ( TrackConfig, Share
    , MiniSectorShares(..)
    , computeProgress, calcSectorBoundaries
    , LapScale, lapScale, toMetres
    )

{-| The track's proportions: how much of the lap each stretch of it takes, and
where round the lap that stretch begins.

Divided by the CLI and decoded in `Data.Wec`.

Read for every car of every frame, which is what decides the shape here: the
shares are held per sector and per mini-sector, so reading one is
[`Sector.get`](Motorsport-Sector#get) rather than a scan.

@docs TrackConfig, Share
@docs MiniSectorShares
@docs computeProgress, calcSectorBoundaries
@docs LapScale, lapScale, toMetres

-}

import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector)
import Motorsport.Wec.Circuit.LeMans.Layout exposing (TimingLines)


{-| The whole lap, divided. Both grains cover the same lap, so a car can be
placed by either.
-}
type alias TrackConfig =
    { sectors : BySector Share
    , miniSectors : MiniSectorShares
    }


{-| One stretch of the lap: where it begins and how much of the lap it takes,
both as fractions of the whole. Which stretch it is belongs to the position in
a `BySector` or a `ByMiniSector`.
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


{-| How far round the lap, in metres, a track progress puts a car. See
[`lapScale`](#lapScale).
-}
type LapScale
    = LapScale (List Knot)


type alias Knot =
    { progress : Float
    , metres : Float
    }


{-| A progress is a share of the time a lap takes, and the stretches of a lap
are not driven at one speed, so the two only agree at the lines the lap is
timed at. The scale is pinned to the lines whose distance is known and runs
straight between them: a car between two of those is placed by the share of
the time between them it has run, and so is a line with no distance given.

A stretch no lap has set a time for is not a place to pin the scale to.

-}
lapScale : TimingLines -> TrackConfig -> LapScale
lapScale lines config =
    let
        knot { start, share } metres =
            if share > 0 then
                Maybe.map (\m -> { progress = start + share, metres = m }) metres

            else
                Nothing

        ends =
            case config.miniSectors of
                MiniSectorShares shares ->
                    LeMans.values (LeMans.map2 knot shares lines.miniSectors)

                NoMiniSectors ->
                    Sector.values (Sector.map2 (\share metres -> knot share (Just metres)) config.sectors lines.sectors)
    in
    LapScale ({ progress = 0, metres = 0 } :: List.filterMap identity ends)


{-| Past the last line the scale is pinned to, it runs on as it ran into it.
-}
toMetres : LapScale -> Float -> Float
toMetres (LapScale knots) progress =
    interpolate knots progress


interpolate : List Knot -> Float -> Float
interpolate knots progress =
    case knots of
        a :: b :: rest ->
            if progress <= b.progress || List.isEmpty rest then
                if b.progress > a.progress then
                    a.metres + (progress - a.progress) / (b.progress - a.progress) * (b.metres - a.metres)

                else
                    a.metres

            else
                interpolate (b :: rest) progress

        [ a ] ->
            a.metres

        [] ->
            progress
