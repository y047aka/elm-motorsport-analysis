module Motorsport.Chart.Tracker.Config exposing
    ( TrackConfig, Share
    , MiniSectorShares(..)
    , computeProgress, calcSectorBoundaries
    , LapScale, lapScale, toMetres
    , metresOn, Evenness, evenness, ease
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
@docs metresOn, Evenness, evenness, ease

-}

import Motorsport.Circuit.Pace as Pace exposing (Pace)
import Motorsport.Duration exposing (Duration)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Wec.Circuit.Layout exposing (MiniSectorLines(..), TimingLines)
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
                Just miniSector ->
                    Just
                        { share = LeMans.get miniSector.miniSector shares
                        , progress = miniSector.progress
                        , time = miniSector.time
                        }

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


{-| How far round the lap, in metres, to draw a car on a circuit: where [`computeProgress`](#computeProgress) puts it, eased towards an even pace through a stretch the car is running far slower than usual.

A car under a full course yellow, behind the safety car or through a slow zone is held to a speed rather than driving the corners, so the reference lap's quick straights and slow bends would misplace it.
How much slower than usual is the stretch's time against its share of the car's own best lap.

-}
metresOn : LapScale -> TrackConfig -> CarAt -> Float
metresOn scale config car =
    case stretchOf config car of
        Just stretch ->
            ease scale
                (case car.bestLap of
                    Just best ->
                        evenness { took = stretch.time, usually = round (stretch.share.share * toFloat best.time) }

                    Nothing ->
                        atPace
                )
                stretch

        Nothing ->
            toMetres scale car.currentLap.progress


{-| How far a car is drawn from where the reference lap's pace puts it towards where an even pace through its stretch does: from none of the way to all of it.
-}
type Evenness
    = Evenness Float


atPace : Evenness
atPace =
    Evenness 0


{-| How evenly a stretch that `took` what it `usually` takes is drawn: not at all up to 1.2 times as long, all the way from 2 times, and in proportion between.

Chosen against Le Mans 2025, where 95% of its mini-sectors run under green took at most 1.11 times their share of the car's best lap, those run under a full course yellow 2.9 at the slowest tenth, and those behind the safety car 1.43 at the median.

-}
evenness : { took : Duration, usually : Duration } -> Evenness
evenness { took, usually } =
    if usually > 0 then
        Evenness (clamp 0 1 ((toFloat took / toFloat usually - 1.2) / 0.8))

    else
        atPace


{-| How far round the lap, in metres, a car part way through a stretch is drawn.
The reference lap's pace and an even pace agree at the stretch's ends, so a car that changes how evenly it is drawn as it crosses into the next stretch does not jump.
-}
ease : LapScale -> Evenness -> { a | share : Share, progress : Float } -> Float
ease scale (Evenness towardsEven) { share, progress } =
    let
        atPaceMetres =
            toMetres scale (along share progress)
    in
    if towardsEven <= 0 then
        atPaceMetres

    else
        let
            from =
                toMetres scale share.start

            to =
                toMetres scale (share.start + share.share)
        in
        atPaceMetres + towardsEven * (from + progress * (to - from) - atPaceMetres)


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
    = LapScale Pace (List Knot)


type alias Knot =
    { progress : Float
    , metres : Float
    , seconds : Float
    }


{-| A progress is a share of the time a lap takes, and the stretches of a lap
are not driven at one speed, so the two only agree at the lines the lap is
timed at.
The scale is pinned to the lines whose distance is known, and between two of them a car is where the [`Pace`](Motorsport-Circuit-Pace) puts it once it has run the same share of the time between them; so is a line with no distance given.
[`Pace.even`](Motorsport-Circuit-Pace#even) runs the scale straight between the lines.

A stretch no lap has set a time for is not a place to pin the scale to.

-}
lapScale : Pace -> TimingLines -> TrackConfig -> LapScale
lapScale pace lines config =
    let
        knot { start, share } metres =
            if share > 0 then
                Maybe.map (pinned (start + share)) metres

            else
                Nothing

        pinned progress metres =
            { progress = progress, metres = metres, seconds = Pace.secondsAt pace metres }

        ends =
            case ( config.miniSectors, lines.miniSectors ) of
                ( MiniSectorShares shares, LeMansMiniSectors published ) ->
                    LeMans.values (LeMans.map2 knot shares published)

                -- Either the round was never timed at the finer grain or the
                -- circuit places no lines finer than its three sectors; the
                -- sector grain is the answer either way.
                _ ->
                    Sector.values (Sector.map2 (\share metres -> knot share (Just metres)) config.sectors lines.sectors)
    in
    LapScale pace (pinned 0 0 :: List.filterMap identity ends)


{-| Past the last line the scale is pinned to, it runs on as it ran into it.
-}
toMetres : LapScale -> Float -> Float
toMetres (LapScale pace knots) progress =
    interpolate pace knots progress


interpolate : Pace -> List Knot -> Float -> Float
interpolate pace knots progress =
    case knots of
        a :: b :: rest ->
            if progress <= b.progress || List.isEmpty rest then
                if b.progress > a.progress then
                    Pace.metresAt pace (a.seconds + (progress - a.progress) / (b.progress - a.progress) * (b.seconds - a.seconds))

                else
                    a.metres

            else
                interpolate pace (b :: rest) progress

        [ a ] ->
            a.metres

        [] ->
            progress
