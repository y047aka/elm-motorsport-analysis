module Internal.Color exposing
    ( Color
    , oklch, css, variable, inherit, transparent
    , withAlpha, muted
    , toCss
    )

{-| A colour on its way into a CSS declaration.

A colour stays one of these while it is being chosen and handed on, and becomes
a string where it is written into an attribute. That is what puts the two things
this application does to a colour -- laying it down at an alpha, and dropping
most of its chroma -- in one place rather than in the several that draw.

@docs Color
@docs oklch, css, variable, inherit, transparent
@docs withAlpha, muted
@docs toCss

-}


{-| `Css` is a colour written where no type of this application's reaches -- the
hand-written manufacturer table -- and is carried through as it was spelled.
-}
type Color
    = Oklch { lightness : Float, chroma : Float, hue : Float, alpha : Float }
    | Css String
    | Var String
    | Inherit
    | Muted Color
    | Faded Float Color


{-| The arguments the CSS function takes, in the order it takes them: lightness
from 0 to 1, chroma, and hue in degrees.

    toCss (oklch 0.5 0.25 29)
    --> "oklch(0.5 0.25 29)"

-}
oklch : Float -> Float -> Float -> Color
oklch lightness chroma hue =
    Oklch { lightness = lightness, chroma = chroma, hue = hue, alpha = 1 }


css : String -> Color
css =
    Css


{-| A custom property, named with the dashes it is declared under.

    toCss (variable "--performance-fastest")
    --> "var(--performance-fastest)"

-}
variable : String -> Color
variable =
    Var


inherit : Color
inherit =
    Inherit


transparent : Color
transparent =
    Oklch { lightness = 0, chroma = 0, hue = 0, alpha = 0 }


{-| The same colour laid down at an alpha, in place of the one it had.

    toCss (withAlpha 0.2 (oklch 1 0 0))
    --> "oklch(1 0 0 / 0.2)"

-}
withAlpha : Float -> Color -> Color
withAlpha alpha color =
    case color of
        Oklch c ->
            Oklch { c | alpha = alpha }

        Faded _ base ->
            Faded alpha base

        Css _ ->
            Faded alpha color

        Var _ ->
            Faded alpha color

        Inherit ->
            Faded alpha color

        Muted _ ->
            Faded alpha color


{-| Most of the colour's chroma dropped rather than all of it: a fully
achromatic line would recede into the background but stop telling the cars
apart.
-}
muted : Color -> Color
muted =
    Muted


toCss : Color -> String
toCss color =
    case color of
        Oklch c ->
            "oklch("
                ++ String.fromFloat c.lightness
                ++ " "
                ++ String.fromFloat c.chroma
                ++ " "
                ++ String.fromFloat c.hue
                ++ (if c.alpha == 1 then
                        ""

                    else
                        " / " ++ String.fromFloat c.alpha
                   )
                ++ ")"

        Css value ->
            value

        Var property ->
            "var(" ++ property ++ ")"

        Inherit ->
            "inherit"

        Muted base ->
            "oklch(from " ++ toCss base ++ " 0.5 calc(c * 0.2) h)"

        Faded alpha base ->
            "oklch(from " ++ toCss base ++ " l c h / " ++ String.fromFloat alpha ++ ")"
