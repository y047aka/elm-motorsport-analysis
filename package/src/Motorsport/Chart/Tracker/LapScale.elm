module Motorsport.Chart.Tracker.LapScale exposing
    ( LapScale, lapScale, toMetres
    , metresOn, Evenness, evenness, ease
    )

{-| How far round a circuit, in metres, a car is drawn: the summary's proportions pinned to the lines the circuit is timed at, run between them at the pace the circuit's bends allow, and eased towards an even pace where a car is running far slower than usual.

@docs LapScale, lapScale, toMetres
@docs metresOn, Evenness, evenness, ease

-}

import Motorsport.Chart.Tracker.Config as Config exposing (MiniSectorShares(..), Share, TrackConfig)
import Motorsport.Circuit.Pace as Pace exposing (Pace)
import Motorsport.Duration exposing (Duration)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.Layout exposing (MiniSectorLines(..), TimingLines)
import Motorsport.Wec.Circuit.LeMans as LeMans


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


{-| How far round the lap, in metres, to draw a car on a circuit: where [`computeProgress`](Motorsport-Chart-Tracker-Config#computeProgress) puts it, eased towards an even pace through a stretch the car is running far slower than usual.

A car under a full course yellow, behind the safety car or through a slow zone is held to a speed rather than driving the corners, so the reference lap's quick straights and slow bends would misplace it.
How much slower than usual is the stretch's time against its share of the car's own best lap.

-}
metresOn : LapScale -> TrackConfig -> CarAt -> Float
metresOn scale config car =
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
            toMetres scale (share.start + progress * share.share)
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
