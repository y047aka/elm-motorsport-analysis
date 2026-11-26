module Motorsport.Simulation.Neutralised exposing (Neutralised, none, fromTimes, between)

{-| How a car runs while the race is neutralised -- under a full course yellow, behind the safety car or through a slow zone.

A neutralised car is held to a speed rather than driving the corners, so it runs at an even pace and not at the [`ReferenceLap`](Motorsport-Simulation-ReferenceLap)'s quick straights and slow bends.
The timing does not say where round the lap a car was neutralised; how much longer than usual it takes over a stretch is what is read as how neutralised it is.

@docs Neutralised, none, fromTimes, between

-}

import Motorsport.Duration exposing (Duration)
import Quantity exposing (Quantity)


{-| How neutralised a car is: how far it runs from the reference lap's pace towards an even pace, from none of the way to all of it.
-}
type Neutralised
    = Neutralised Float


{-| Not neutralised at all: at the reference lap's pace.
-}
none : Neutralised
none =
    Neutralised 0


{-| How many times as long as usual a stretch has to take before the car running it is read as neutralised at all, and before it is read as neutralised through and through.

Chosen against Le Mans 2025, where 95% of its mini-sectors run under green took at most 1.11 times their share of the car's best lap, those run under a full course yellow 2.9 at the slowest tenth, and those behind the safety car 1.43 at the median.

-}
slowness : { from : Float, to : Float }
slowness =
    { from = 1.2, to = 2 }


{-| How neutralised a car whose stretch `took` what it `usually` takes is: not at all up to `slowness.from` times as long, through and through from `slowness.to` times, and in proportion between.

    import Length

    fromTimes { took = 1000, usually = 1000 }
        |> between (Length.meters 0) (Length.meters 10)
    --> Length.meters 0

    fromTimes { took = 2400, usually = 1000 }
        |> between (Length.meters 0) (Length.meters 10)
    --> Length.meters 10

-}
fromTimes : { took : Duration, usually : Duration } -> Neutralised
fromTimes { took, usually } =
    if usually > 0 then
        Neutralised (clamp 0 1 ((toFloat took / toFloat usually - slowness.from) / (slowness.to - slowness.from)))

    else
        none


{-| Where between what the reference lap's pace gives and what an even pace gives a car this neutralised stands.
-}
between : Quantity Float units -> Quantity Float units -> Neutralised -> Quantity Float units
between atPace atEvenPace (Neutralised towardsEven) =
    Quantity.interpolateFrom atPace atEvenPace towardsEven
