module Motorsport.Manufacturer exposing (Manufacturer, unknown)

{-| A car's manufacturer, and how it is drawn: filled in where the car is read.

@docs Manufacturer, unknown

-}


{-| `color` is a CSS value.
-}
type alias Manufacturer =
    { name : String
    , color : String
    , logoUrl : Maybe String
    }


unknown : Manufacturer
unknown =
    { name = ""
    , color = "oklch(0.5 0 0)"
    , logoUrl = Nothing
    }
