module Motorsport.Chart.Tracker.Config exposing
    ( TrackConfig, Share
    , MiniSectorShares(..)
    , buildConfig
    , computeProgress, calcSectorBoundaries
    )

{-| The track's proportions: how much of the lap each stretch of it takes, and
where round the lap that stretch begins.

Worked out once when the race loads -- see
[`Tracker.trackOf`](Motorsport-Chart-Tracker#trackOf) -- and read back for every
car of every frame after, which is what decides the shape here: the shares are
held per sector and per mini-sector, so reading one is
[`Sector.get`](Motorsport-Sector#get) rather than a scan.

@docs TrackConfig, Share
@docs MiniSectorShares
@docs buildConfig
@docs computeProgress, calcSectorBoundaries

-}

import List.Extra
import Motorsport.BestTimes as BestTimes exposing (Holder)
import Motorsport.Circuit as Circuit exposing (Layout, Segmentation(..))
import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector, LeMans2025MiniSector)
import Motorsport.Duration exposing (Duration)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Sector as Sector exposing (BySector)


{-| The whole lap, divided.

`sectors` is always the three; `miniSectors` is the finer division as well,
where the circuit is timed to one. Both cover the same lap, so a car can be
placed by either.

-}
type alias TrackConfig =
    { sectors : BySector Share
    , miniSectors : MiniSectorShares
    }


{-| One stretch of the lap: where it begins and how much of the lap it takes,
both as fractions of the whole.

Which stretch it is belongs to the position in a
[`BySector`](Motorsport-Sector#BySector) or a
[`ByMiniSector`](Motorsport-Circuit-LeMans#ByMiniSector), not to the value --
which is what lets the two grains share one type.

-}
type alias Share =
    { start : Float
    , share : Float
    }


{-| The mini-sectors' shares, where the circuit has mini-sectors.

Reads as [`Circuit.Segmentation`](Motorsport-Circuit#Segmentation) does, one
step further on: that says how the lap is divided, this says what the divisions
came to.

-}
type MiniSectorShares
    = NoMiniSectors
    | MiniSectorShares (ByMiniSector Share)


{-| Work out the proportions from the circuit and the times set on it.

A stretch takes the share of the lap that its record does of the lap record --
so the track is drawn to how quick each part of it is. Before any record has
been set there is nothing to draw it from, and the default ratios stand in.

-}
buildConfig :
    Layout LeMans2025MiniSector
    ->
        { a
            | fastestSectors : BySector (Maybe Holder)
            , fastestMiniSectors : ByMiniSector (Maybe Holder)
        }
    -> TrackConfig
buildConfig layout bestTimes =
    case layout.segmentation of
        SectorsOnly ->
            let
                ratio =
                    ratioAgainst
                        { total = totalOf (Sector.values bestTimes.fastestSectors)
                        , timeOf = \sector -> BestTimes.timeOf (Sector.get sector bestTimes.fastestSectors)
                        , default = \_ -> Circuit.sectorDefaultRatio
                        }
            in
            { sectors = Sector.initialize (shareOf ratio Sector.all)
            , miniSectors = NoMiniSectors
            }

        MiniSectors grouping ->
            let
                miniRatio =
                    ratioAgainst
                        { total = totalOf (LeMans.values bestTimes.fastestMiniSectors)
                        , timeOf = \mini -> BestTimes.timeOf (LeMans.get mini bestTimes.fastestMiniSectors)
                        , default = LeMans.defaultRatio
                        }

                -- A sector is its mini-sectors, so it takes what they take
                -- between them. Reading it off the sector's own record instead
                -- would let the two divisions of the lap disagree about where
                -- the sector ends.
                sectorRatio sector =
                    Sector.get sector grouping |> List.map miniRatio |> List.sum
            in
            { sectors = Sector.initialize (shareOf sectorRatio Sector.all)
            , miniSectors = MiniSectorShares (LeMans.initialize (shareOf miniRatio LeMans.all))
            }


{-| What share of the lap one stretch's record is of every record put together.

A stretch no lap has set a time for counts as nothing, and until some lap has
set one there is no total to divide by -- so before the race has run, every
stretch falls back on the proportions it is known to have.

-}
ratioAgainst :
    { total : Float
    , timeOf : id -> Maybe Duration
    , default : id -> Float
    }
    -> id
    -> Float
ratioAgainst { total, timeOf, default } id =
    if total == 0 then
        default id

    else
        toFloat (Maybe.withDefault 0 (timeOf id)) / total


totalOf : List (Maybe Holder) -> Float
totalOf records =
    records |> List.filterMap BestTimes.timeOf |> List.sum |> toFloat


{-| Lay the stretches out end to end from the line, each taking the share its
ratio gives it.

Quadratic in the number of stretches, which is fifteen at most and paid once
when the race loads. What it buys is that a stretch's share is written as a
function of the stretch rather than threaded through a fold, so it can be built
straight into a `BySector` or a `ByMiniSector` -- and read back in constant time
on every frame after, which is where the cost that matters is.

-}
shareOf : (id -> Float) -> List id -> id -> Share
shareOf ratio order id =
    { start =
        order
            |> List.Extra.takeWhile (\other -> other /= id)
            |> List.map ratio
            |> List.sum
    , share = ratio id
    }


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
        case ( config.miniSectors, car.currentLap.miniSector ) of
            ( MiniSectorShares shares, Just current ) ->
                along (LeMans.get current.miniSector shares) current.progress

            _ ->
                along (Sector.get car.currentLap.sector.sector config.sectors) car.currentLap.sector.progress


{-| How far round the lap a car part way through one stretch of it is.
-}
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
