module Motorsport.Instant exposing
    ( Instant
    , raceStart, fromDuration
    , decoder
    , add, subtract, since
    , compare, earlier, later
    , toDuration, toString
    )

{-| A moment of the race, measured from the instant it started.

[`Duration`](Motorsport-Duration) is how long something took; an `Instant` is
when it happened. Both are milliseconds underneath, and keeping this one opaque
is what stops a lap time being compared against a lap's completion time.

The algebra is the one the names imply: a moment shifted by a length is another
moment ([`add`](#add), [`subtract`](#subtract)), and the distance between two
moments is a length ([`since`](#since)). Nothing else is offered.

@docs Instant


## Naming a moment

@docs raceStart, fromDuration
@docs decoder


## Moving between moments

@docs add, subtract, since


## Ordering moments

@docs compare, earlier, later


## Reading a moment

@docs toDuration, toString

-}

import Json.Decode exposing (Decoder)
import Motorsport.Duration as Duration exposing (Duration)


{-| Milliseconds since the race started. Never negative -- see
[`subtract`](#subtract).
-}
type Instant
    = Instant Duration


{-| The moment the race started, which every other moment is measured from.

    toDuration raceStart
    --> 0

-}
raceStart : Instant
raceStart =
    Instant 0


{-| The moment reached after `duration` of racing. Moments before the start do
not exist, so a negative duration lands on [`raceStart`](#raceStart):

    toDuration (fromDuration 4321)
    --> 4321

    fromDuration (-4321)
    --> raceStart

-}
fromDuration : Duration -> Instant
fromDuration duration =
    if duration < 0 then
        raceStart

    else
        Instant duration


{-| Read a moment off the wire, where it is spelled the way
[`Duration.fromString`](Motorsport-Duration#fromString) reads it.
-}
decoder : Decoder Instant
decoder =
    Json.Decode.string
        |> Json.Decode.andThen
            (\str ->
                case Duration.fromString str of
                    Just duration ->
                        Json.Decode.succeed (fromDuration duration)

                    Nothing ->
                        Json.Decode.fail ("Invalid duration format: " ++ str)
            )



-- MOVING BETWEEN MOMENTS


{-| The moment `duration` later.

    fromDuration 1000 |> add 500
    --> fromDuration 1500

-}
add : Duration -> Instant -> Instant
add duration (Instant ms) =
    fromDuration (ms + duration)


{-| The moment `duration` earlier, clamped at the start of the race -- there is
no racing before there is a race:

    fromDuration 1000 |> subtract 500
    --> fromDuration 500

    fromDuration 1000 |> subtract 5000
    --> raceStart

-}
subtract : Duration -> Instant -> Instant
subtract duration (Instant ms) =
    fromDuration (ms - duration)


{-| How long it took to get from one moment to another.

Signed, and deliberately not clamped the way [`subtract`](#subtract) is: `to`
being the earlier of the two is a meaningful answer rather than an impossible
moment, and callers read it. [`Gap.seconds`](Motorsport-Gap#seconds) takes a
negative here to mean the two cars were handed over the wrong way round.

    since { from = fromDuration 1000, to = fromDuration 1500 }
    --> 500

    since { from = fromDuration 1500, to = fromDuration 1000 }
    --> -500

-}
since : { from : Instant, to : Instant } -> Duration
since { from, to } =
    toDuration to - toDuration from



-- ORDERING MOMENTS


{-| Which of two moments came first.

    Motorsport.Instant.compare (fromDuration 1000) (fromDuration 1500)
    --> LT

-}
compare : Instant -> Instant -> Order
compare (Instant a) (Instant b) =
    Basics.compare a b


{-| Whichever of two moments came first.

    earlier (fromDuration 1500) (fromDuration 1000)
    --> fromDuration 1000

-}
earlier : Instant -> Instant -> Instant
earlier a b =
    if compare a b == GT then
        b

    else
        a


{-| Whichever of two moments came last.

Folding a list with it needs no fallback for the empty case: nothing happens
before the race starts, so [`raceStart`](#raceStart) is the identity.

    later (fromDuration 1500) (fromDuration 1000)
    --> fromDuration 1500

    List.foldl later raceStart []
    --> raceStart

-}
later : Instant -> Instant -> Instant
later a b =
    if compare a b == LT then
        b

    else
        a



-- READING A MOMENT


{-| How long into the race this moment is -- the way out of the type, for the
arithmetic the algebra above has no name for.

    fromDuration 90000 |> toDuration
    --> 90000

-}
toDuration : Instant -> Duration
toDuration (Instant ms) =
    ms


{-| Render a moment the way a race clock does. For display only.

    toString (fromDuration 25614321)
    --> "7:06:54.321"

-}
toString : Instant -> String
toString =
    toDuration >> Duration.toString
