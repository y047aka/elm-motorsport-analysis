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


{-| Whether the hand-written table names this manufacturer, which is where a
logo comes from and nowhere else does.

`color` is a CSS value.

-}
type Manufacturer
    = Registered { name : String, color : String, logoUrl : Maybe String }
    | Unregistered { name : String, color : String }


registered : { name : String, color : String, logoUrl : Maybe String } -> Manufacturer
registered =
    Registered


unregistered : { name : String, color : String } -> Manufacturer
unregistered =
    Unregistered


{-| Stands in for a manufacturer nothing has named.

    name unknown
    --> ""

-}
unknown : Manufacturer
unknown =
    Unregistered { name = "", color = "oklch(0.5 0 0)" }


name : Manufacturer -> String
name manufacturer =
    case manufacturer of
        Registered m ->
            m.name

        Unregistered m ->
            m.name


color : Manufacturer -> String
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
