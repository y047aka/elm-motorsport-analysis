module Motorsport.Chart.Tracker.LapScale exposing
    ( LapScale, lapScale, distanceAt
    , distanceOf, Evenness, evenness, ease
    )

{-| How far round a circuit a car is drawn: the summary's proportions pinned to the lines the circuit is timed at, run between them at the pace the circuit's bends allow, and eased towards an even pace where a car is running far slower than usual.

@docs LapScale, lapScale, distanceAt
@docs distanceOf, Evenness, evenness, ease

-}

import Duration exposing (Seconds)
import Length exposing (Length)
import Motorsport.Chart.Tracker.Config as Config exposing (MiniSectorShares(..), Share, TrackConfig)
import Motorsport.Duration exposing (Duration)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Sector as Sector
import Motorsport.Simulation.ReferenceLap as ReferenceLap exposing (ReferenceLap)
import Motorsport.Wec.Circuit.Layout exposing (MiniSectorLines(..), TimingLines)
import Motorsport.Wec.Circuit.LeMans as LeMans
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
The scale is pinned to the lines whose distance is known, and between two of them a car is where the [`ReferenceLap`](Motorsport-Simulation-ReferenceLap) puts it once it has run the same share of the time between them; so is a line with no distance given.
[`ReferenceLap.steady`](Motorsport-Simulation-ReferenceLap#steady) runs the scale straight between the lines.

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
            { progress = progress, distance = Length.meters metres, time = ReferenceLap.timeTo referenceLap (Length.meters metres) }

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

A car under a full course yellow, behind the safety car or through a slow zone is held to a speed rather than driving the corners, so the reference lap's quick straights and slow bends would misplace it.
How much slower than usual is the stretch's time against its share of the car's own best lap.

-}
distanceOf : LapScale -> CarAt -> Length
distanceOf ((LapScale { config }) as scale) car =
    case Config.stretchOf config car of
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
            distanceAt scale car.currentLap.progress


{-| How far a car is drawn from where the reference lap's pace puts it towards where an even pace through its stretch does: from none of the way to all of it.
-}
type Evenness
    = Evenness Float


atPace : Evenness
atPace =
    Evenness 0


{-| How many times as long as usual a stretch has to take before it is drawn at all evenly, and before it is drawn at an even pace through and through.

Chosen against Le Mans 2025, where 95% of its mini-sectors run under green took at most 1.11 times their share of the car's best lap, those run under a full course yellow 2.9 at the slowest tenth, and those behind the safety car 1.43 at the median.

-}
slowness : { from : Float, to : Float }
slowness =
    { from = 1.2, to = 2 }


{-| How evenly a stretch that `took` what it `usually` takes is drawn: not at all up to `slowness.from` times as long, all the way from `slowness.to` times, and in proportion between.
-}
evenness : { took : Duration, usually : Duration } -> Evenness
evenness { took, usually } =
    if usually > 0 then
        Evenness (clamp 0 1 ((toFloat took / toFloat usually - slowness.from) / (slowness.to - slowness.from)))

    else
        atPace


{-| How far round the lap a car part way through a stretch is drawn.
The reference lap's pace and an even pace agree at the stretch's ends, so a car that changes how evenly it is drawn as it crosses into the next stretch does not jump.
-}
ease : LapScale -> Evenness -> { a | share : Share, progress : Float } -> Length
ease scale (Evenness towardsEven) { share, progress } =
    let
        paced =
            distanceAt scale (share.start + progress * share.share)
    in
    if towardsEven <= 0 then
        paced

    else
        let
            atEvenPace =
                Quantity.interpolateFrom
                    (distanceAt scale share.start)
                    (distanceAt scale (share.start + share.share))
                    progress
        in
        Quantity.interpolateFrom paced atEvenPace towardsEven
