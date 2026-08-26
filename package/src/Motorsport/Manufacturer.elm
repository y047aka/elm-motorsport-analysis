module Motorsport.Manufacturer exposing (Manufacturer, unknown)

{-| A car's manufacturer, and how it is drawn: filled in where the car is read.

@docs Manufacturer, unknown

-}

import Css exposing (Color)
import Css.Color exposing (oklch)


{-| `chartColor` distinguishes the cars of a manufacturer that has no colour of
its own, which `color` leaves all the same neutral.
-}
type alias Manufacturer =
    { name : String
    , color : Color
    , chartColor : Color
    , logoUrl : Maybe String
    }


{-| The manufacturer of a car whose manufacturer is not known.
-}
unknown : Manufacturer
unknown =
    { name = ""
    , color = oklch 0.5 0 0
    , chartColor = oklch 0.5 0 0
    , logoUrl = Nothing
    }
