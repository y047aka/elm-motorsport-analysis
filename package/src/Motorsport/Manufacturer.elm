module Motorsport.Manufacturer exposing
    ( Manufacturer
    , registered, unregistered, unknown
    , name, color, logoUrl
    )

{-| A car's manufacturer, and how it is drawn: filled in where the car is read.

@docs Manufacturer
@docs registered, unregistered, unknown
@docs name, color, logoUrl

-}

import Internal.Color as Color exposing (Color)


{-| Whether the hand-written table names this manufacturer, which is where a
logo comes from and nowhere else does.
-}
type Manufacturer
    = Registered { name : String, color : Color, logoUrl : Maybe String }
    | Unregistered { name : String, color : Color }


registered : { name : String, color : Color, logoUrl : Maybe String } -> Manufacturer
registered =
    Registered


unregistered : { name : String, color : Color } -> Manufacturer
unregistered =
    Unregistered


{-| Stands in for a manufacturer nothing has named.

    name unknown
    --> ""

-}
unknown : Manufacturer
unknown =
    Unregistered { name = "", color = Color.oklch 0.5 0 0 }


name : Manufacturer -> String
name manufacturer =
    case manufacturer of
        Registered m ->
            m.name

        Unregistered m ->
            m.name


color : Manufacturer -> Color
color manufacturer =
    case manufacturer of
        Registered m ->
            m.color

        Unregistered m ->
            m.color


logoUrl : Manufacturer -> Maybe String
logoUrl manufacturer =
    case manufacturer of
        Registered m ->
            m.logoUrl

        Unregistered _ ->
            Nothing
