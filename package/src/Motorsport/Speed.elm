module Motorsport.Speed exposing
    ( Speed
    , zero, ofTenths, toTenths, ofKmh, toKmh
    , toString, toSignedString, difference, magnitude
    )

{-| How fast a car was going, kept in tenths of a kilometre an hour.

That is the resolution the timing feed writes speeds at, and it divides the
hour's kilometre exactly, so a speed is an integer and two of them compare by
value the way two `Duration`s do. It is kept as one integer rather than as a
kilometres-per-hour `Float` for the same reason a duration is held in
milliseconds: a reading of the field subtracts one speed from another, and a
subtraction that goes through `Float` comes back as `3.9999999999999437` and
needs a tolerance to be read.

A speed may be negative, which makes it a speed measured _against_ another one.
`toString` writes the magnitude and the tenth it carries;
[`toSignedString`](#toSignedString) writes the difference with its sign.

@docs Speed
@docs zero, ofTenths, toTenths, ofKmh, toKmh
@docs toString, toSignedString, difference, magnitude

-}


{-| A speed in tenths of a kilometre an hour. Negative where it is a difference.
-}
type Speed
    = Speed Int


{-| No speed at all: the middle a difference is measured from.
-}
zero : Speed
zero =
    Speed 0


{-| Build from the unit the type is kept in.
-}
ofTenths : Int -> Speed
ofTenths tenths =
    Speed tenths


{-| The value in the unit the type is kept in, for sorting and for counting.

    toTenths (ofKmh 328.8)
    --> 3288

-}
toTenths : Speed -> Int
toTenths (Speed tenths) =
    tenths


{-| Build from kilometres an hour, rounding to the tenth the feed is written in.

    ofKmh 88.54 |> toTenths
    --> 885

    ofKmh 88.56 |> toTenths
    --> 886

-}
ofKmh : Float -> Speed
ofKmh kmh =
    Speed (round (kmh * 10))


{-| Kilometres an hour, for arithmetic that is not exact -- a mean, a
deviation -- which is where a `Float` costs nothing.

    toKmh (ofTenths 3288)
    --> 328.8

-}
toKmh : Speed -> Float
toKmh (Speed tenths) =
    toFloat tenths / 10


{-| How fast, as the sport writes it.

    toString (ofTenths 3288)
    --> "328.8"

    toString (ofKmh 88.56)
    --> "88.6"

The magnitude, so a difference written this way carries one sign at most:

    toString (ofTenths -18)
    --> "-1.8"

-}
toString : Speed -> String
toString speed =
    let
        tenths =
            toTenths speed

        sign =
            if tenths < 0 then
                "-"

            else
                ""
    in
    sign
        ++ String.fromInt (abs tenths // 10)
        ++ "."
        ++ String.fromInt (modBy 10 (abs tenths))


{-| A difference, with the sign that says which way it fell.

    toSignedString (ofTenths 24)
    --> "+2.4"

    toSignedString (ofTenths -18)
    --> "-1.8"

    toSignedString zero
    --> "0.0"

-}
toSignedString : Speed -> String
toSignedString speed =
    if toTenths speed > 0 then
        "+" ++ toString speed

    else
        toString speed


{-| How far one speed stands from another, signed: positive when the first is
the faster of the two.

    toSignedString (difference (ofTenths 3312) (ofTenths 3288))
    --> "+2.4"

    toSignedString (difference (ofTenths 3288) (ofTenths 3312))
    --> "-2.4"

-}
difference : Speed -> Speed -> Speed
difference (Speed a) (Speed b) =
    Speed (a - b)


{-| How far from nothing, whichever way it fell: the size a bar is drawn at, so
a value that came out negative can never be drawn as one.

    toTenths (magnitude (ofTenths -18))
    --> 18

-}
magnitude : Speed -> Speed
magnitude (Speed tenths) =
    Speed (abs tenths)
