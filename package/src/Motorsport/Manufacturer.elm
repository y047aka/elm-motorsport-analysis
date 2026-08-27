module Motorsport.Manufacturer exposing (Manufacturer, unknown)

{-| A car's manufacturer, and how it is drawn: filled in where the car is read.

@docs Manufacturer, unknown

-}


{-| The colours are CSS values.

`chartColor` distinguishes the cars of a manufacturer that has no colour of its
own, which `color` leaves all the same neutral.

-}
type alias Manufacturer =
    { name : String
    , color : String
    , chartColor : String
    , logoUrl : Maybe String
    }


unknown : Manufacturer
unknown =
    { name = ""
    , color = "oklch(0.5 0 0)"
    , chartColor = "oklch(0.5 0 0)"
    , logoUrl = Nothing
    }
