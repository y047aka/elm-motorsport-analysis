module Motorsport.Chart.Tracker.Config exposing
    ( TrackConfig, Share
    , MiniSectorShares(..)
    , progressOf, boundaries
    , Stretch, stretchOf
    )

{-| The track's proportions: how much of the lap each stretch of it takes, and
where round the lap that stretch begins.

Divided by the CLI and decoded in `Data.Wec`.

Read for every car of every frame, which is what decides the shape here: the
shares are held per sector and per mini-sector, and a mini-sector's is read by
name off a list as long as the lap is split fine.

@docs TrackConfig, Share
@docs MiniSectorShares
@docs progressOf, boundaries
@docs Stretch, stretchOf

-}

import Motorsport.Duration exposing (Duration)
import Motorsport.MiniSector as MiniSector exposing (MiniSectors)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Sector as Sector exposing (BySector)


{-| The whole lap, divided. Both grains cover the same lap, so a car can be
placed by either.
-}
type alias TrackConfig =
    { sectors : BySector Share
    , miniSectors : MiniSectorShares
    }


{-| One stretch of the lap: where it begins and how much of the lap it takes,
both as fractions of the whole. Which stretch it is belongs to the position in
a `BySector`, or to the name in a `MiniSector.MiniSectors`.
-}
type alias Share =
    { start : Float
    , share : Float
    }


{-| The mini-sectors' shares, on the rounds whose feed splits the lap that far.
-}
type MiniSectorShares
    = NoMiniSectors
    | MiniSectorShares (MiniSectors Share)


{-| How far round the lap a car is, as a fraction of it.

Read at the finest grain the circuit and the car's own lap both have, so that a
car sits between the same two boundaries the drawn track puts it between.

-}
progressOf : TrackConfig -> CarAt -> Float
progressOf config car =
    case stretchOf config car of
        Just stretch ->
            along stretch.share stretch.progress

        Nothing ->
            car.currentLap.progress


{-| The stretch of the lap a car is in: its share of the lap, how far through it the car is, and how long the car's lap takes over it.
-}
type alias Stretch =
    { share : Share
    , progress : Float
    , time : Duration
    }


{-| `Nothing` for a lap with no sector time to place the car by, which is placed by its own lap progress instead -- measured against that lap's total time, so it takes no account of where the boundaries between the stretches fall.
-}
stretchOf : TrackConfig -> CarAt -> Maybe Stretch
stretchOf config car =
    case ( config.miniSectors, car.currentLap.miniSectors ) of
        ( MiniSectorShares shares, Snapshot.Recorded { current } ) ->
            case current of
                Just mini ->
                    case MiniSector.get mini.miniSector shares of
                        Just share ->
                            Just { share = share, progress = mini.progress, time = mini.time }

                        -- Nowhere to place the car at the finer grain.
                        Nothing ->
                            bySector config car

                -- Nowhere to place the car at the finer grain.
                Nothing ->
                    bySector config car

        _ ->
            bySector config car


{-| Not a `let` in [`stretchOf`](#stretchOf): Elm would work it out even when the finer grain answers, once per car per frame.
-}
bySector : TrackConfig -> CarAt -> Maybe Stretch
bySector config car =
    Maybe.map
        (\{ sector, progress, time } ->
            { share = Sector.get sector config.sectors, progress = progress, time = time }
        )
        car.currentLap.sector


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
boundaries : TrackConfig -> List Float
boundaries config =
    let
        stretches =
            case config.miniSectors of
                MiniSectorShares shares ->
                    MiniSector.values shares

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
