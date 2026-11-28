module Motorsport.Chart.Tracker.LapScale exposing
    ( LapScale, lapScale, distanceAt
    , distanceOf, ease
    )

{-| How far round a circuit a car is drawn: the summary's proportions pinned to the lines the circuit is timed at, run between them at the pace the circuit's bends allow, and eased towards an even pace where a car is running far slower than usual.

@docs LapScale, lapScale, distanceAt
@docs distanceOf, ease

-}

import Duration exposing (Seconds)
import Length exposing (Length)
import Motorsport.Chart.Tracker.Config as Config exposing (MiniSectorShares(..), Share, TrackConfig)
import Motorsport.Circuit.Layout exposing (MiniSectorLines(..), TimingLines)
import Motorsport.MiniSector as MiniSector
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Sector as Sector
import Motorsport.Simulation.Pace.Neutralisation as Neutralisation exposing (Neutralisation)
import Motorsport.Simulation.Pace.ReferenceLap as ReferenceLap exposing (ReferenceLap)
import Quantity exposing (Quantity)


{-| How far round the lap a track progress puts a car. See
[`lapScale`](#lapScale).
-}
type LapScale
    = LapScale
        { referenceLap : ReferenceLap
        , config : TrackConfig
        , lines : List Knot
        }


{-| A line the scale is pinned to: the progress it stands at, how far round the lap it stands, and when the reference car reaches it.
-}
type alias Knot =
    { progress : Float
    , distance : Length
    , time : Quantity Float Seconds
    }


{-| Where every lap starts, at every pace.
-}
finishLine : Knot
finishLine =
    { progress = 0, distance = Quantity.zero, time = Quantity.zero }


{-| A progress is a share of the time a lap takes, and the stretches of a lap
are not driven at one speed, so the two only agree at the lines the lap is
timed at.
The scale is pinned to the lines whose distance is known, and between two of them a car is where the [`ReferenceLap`](Motorsport-Simulation-Pace-ReferenceLap) puts it once it has run the same share of the time between them; so is a line with no distance given.
[`ReferenceLap.steady`](Motorsport-Simulation-Pace-ReferenceLap#steady) runs the scale straight between the lines.

A stretch no lap has set a time for is not a place to pin the scale to.

-}
lapScale : ReferenceLap -> TimingLines -> TrackConfig -> LapScale
lapScale referenceLap lines config =
    let
        knot { start, share } metres =
            if share > 0 then
                Maybe.map (pinned (start + share)) metres

            else
                Nothing

        pinned progress metres =
            { progress = progress, distance = metres, time = ReferenceLap.timeTo referenceLap metres }

        ends =
            case ( config.miniSectors, lines.miniSectors ) of
                ( MiniSectorShares shares, MiniSectors published ) ->
                    MiniSector.values (MiniSector.map2 knot shares published)

                -- Either the round was never timed at the finer grain or the
                -- circuit places no lines finer than its three sectors; the
                -- sector grain is the answer either way.
                _ ->
                    Sector.values (Sector.map2 (\share metres -> knot share (Just metres)) config.sectors lines.sectors)
    in
    LapScale { referenceLap = referenceLap, config = config, lines = List.filterMap identity ends }


{-| Past the last line the scale is pinned to, it runs on as it ran into it.
-}
distanceAt : LapScale -> Float -> Length
distanceAt (LapScale { referenceLap, lines }) progress =
    interpolate referenceLap finishLine lines progress


{-| From the line `a` on, round the `lines` after it.
-}
interpolate : ReferenceLap -> Knot -> List Knot -> Float -> Length
interpolate referenceLap a lines progress =
    case lines of
        b :: rest ->
            if progress <= b.progress || List.isEmpty rest then
                if b.progress > a.progress then
                    ReferenceLap.distanceAfter referenceLap (Quantity.interpolateFrom a.time b.time ((progress - a.progress) / (b.progress - a.progress)))

                else
                    a.distance

            else
                interpolate referenceLap b rest progress

        [] ->
            a.distance


{-| How far round the lap to draw a car on a circuit: where [`progressOf`](Motorsport-Chart-Tracker-Config#progressOf) puts it, eased towards an even pace through a stretch the car is running far slower than usual.

How much slower than usual is the stretch's time against its share of the car's own best lap, or of its class's best while it has set none: see [`Neutralisation`](Motorsport-Simulation-Pace-Neutralisation).

-}
distanceOf : LapScale -> Snapshot -> CarAt -> Length
distanceOf ((LapScale { config }) as scale) standings car =
    let
        usualLap =
            case car.bestLap of
                Just best ->
                    Just best.time

                Nothing ->
                    Snapshot.classBestLap car.metadata.class standings
    in
    case Config.stretchOf config car of
        Just stretch ->
            ease scale
                (case usualLap of
                    Just lapTime ->
                        Neutralisation.fromTimes { took = stretch.time, usually = round (stretch.share.share * toFloat lapTime) }

                    Nothing ->
                        Neutralisation.none
                )
                stretch

        Nothing ->
            distanceAt scale car.currentLap.progress


{-| How far round the lap a car part way through a stretch is drawn.
The reference lap's pace and an even pace agree at the stretch's ends, so a car read as more or less neutralised as it crosses into the next stretch does not jump.
-}
ease : LapScale -> Neutralisation -> { a | share : Share, progress : Float } -> Length
ease scale neutralisation { share, progress } =
    Neutralisation.between
        (distanceAt scale (share.start + progress * share.share))
        (Quantity.interpolateFrom (distanceAt scale share.start) (distanceAt scale (share.start + share.share)) progress)
        neutralisation
