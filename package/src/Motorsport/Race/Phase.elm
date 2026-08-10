module Motorsport.Race.Phase exposing
    ( Phase(..)
    , at
    )

{-| Which part of the race a moment falls in.

Two moments divide it, and they are different things: the flag falls at the
time limit, and the last car crosses the line at the finish.

@docs Phase
@docs at

-}

import Motorsport.Instant as Instant exposing (Instant)


{-| `Finishing` is the stretch between the flag and the last crossing. It exists
because the flag falls on a lap already under way, so the race goes on being run
after the clock says it is over -- which is the whole reason a race carries both
moments rather than one.

The two are not ordered. A race stopped early finishes before its time limit is
reached, and then `Finishing` simply never happens: there were no closing laps
under the flag to have.

-}
type Phase
    = Running
    | Finishing
    | Over


{-| The finish is tested first, and the order matters. That nothing more will
happen is settled by the last crossing alone, whatever the time limit says --
which is what lets this hold for a race that never reached its limit, without
either moment having to be vouched for against the other.
-}
at : { elapsed : Instant } -> { a | timeLimit : Instant, finishedAt : Instant } -> Phase
at { elapsed } race =
    if Instant.compare elapsed race.finishedAt /= LT then
        Over

    else if Instant.compare elapsed race.timeLimit /= LT then
        Finishing

    else
        Running
