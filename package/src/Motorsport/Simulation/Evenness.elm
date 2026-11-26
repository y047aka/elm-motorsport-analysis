module Motorsport.Simulation.Evenness exposing (Evenness, none, fromTimes, between)

{-| How evenly a car runs through a stretch it is taking far longer than usual.

A car under a full course yellow, behind the safety car or through a slow zone is held to a speed rather than driving the corners, so it runs such a stretch at an even pace and not at the [`ReferenceLap`](Motorsport-Simulation-ReferenceLap)'s quick straights and slow bends.

@docs Evenness, none, fromTimes, between

-}

import Motorsport.Duration exposing (Duration)
import Quantity exposing (Quantity)


{-| How far a car is from the reference lap's pace towards an even pace: from none of the way to all of it.
-}
type Evenness
    = Evenness Float


{-| At the reference lap's pace.
-}
none : Evenness
none =
    Evenness 0


{-| How many times as long as usual a stretch has to take before it is run at all evenly, and before it is run at an even pace through and through.

Chosen against Le Mans 2025, where 95% of its mini-sectors run under green took at most 1.11 times their share of the car's best lap, those run under a full course yellow 2.9 at the slowest tenth, and those behind the safety car 1.43 at the median.

-}
slowness : { from : Float, to : Float }
slowness =
    { from = 1.2, to = 2 }


{-| How evenly a stretch that `took` what it `usually` takes is run: not at all up to `slowness.from` times as long, all the way from `slowness.to` times, and in proportion between.

    import Length

    fromTimes { took = 1000, usually = 1000 }
        |> between (Length.meters 0) (Length.meters 10)
    --> Length.meters 0

    fromTimes { took = 2400, usually = 1000 }
        |> between (Length.meters 0) (Length.meters 10)
    --> Length.meters 10

-}
fromTimes : { took : Duration, usually : Duration } -> Evenness
fromTimes { took, usually } =
    if usually > 0 then
        Evenness (clamp 0 1 ((toFloat took / toFloat usually - slowness.from) / (slowness.to - slowness.from)))

    else
        none


{-| Where between what the reference lap's pace gives and what an even pace gives a car of this evenness stands.
-}
between : Quantity Float units -> Quantity Float units -> Evenness -> Quantity Float units
between atPace atEvenPace (Evenness towardsEven) =
    Quantity.interpolateFrom atPace atEvenPace towardsEven
