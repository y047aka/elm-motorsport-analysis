module Motorsport.PitStop exposing (PitStop)

{-| One pit stop, as the pit lane times it.

Nothing times a stop as one thing: the feed writes its two ends on two
different laps, and the stop is a fact only once the car is back on the road
and the lane's time is known. [`Lap.pitStopOf`](Motorsport-Lap#pitStopOf)
reads one off the lap that timed it, and a stint's runs, the lane a
[`CarAt`](Motorsport-Race-Snapshot#CarAt) stands in, and a car's Log line are
all readings of it.

@docs PitStop

-}

import Motorsport.Duration exposing (Duration)
import Motorsport.Instant exposing (Instant)


{-| A car's time through the lane.

`enteredAt` is the crossing of the finish line in the pit lane, on the way in;
`exitedAt` the crossing back onto the road, which sits exactly `laneTime`
after it.

`laneTime` is the feed's `pit_time`. The span the car stood still in its box
sits inside it and cannot be read out of it -- nothing times the box.

-}
type alias PitStop =
    { enteredAt : Instant
    , exitedAt : Instant
    , laneTime : Duration
    }
