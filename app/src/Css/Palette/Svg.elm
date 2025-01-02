module Css.Palette.Svg exposing (SvgPalette, empty, strokeAxis, textOptional)

import Css.Color exposing (Color(..), gray, transparent)


type alias SvgPalette =
    { fill : Color
    , stroke : Color
    }


empty : SvgPalette
empty =
    { fill = transparent
    , stroke = transparent
    }


textOptional : SvgPalette
textOptional =
    { empty | fill = gray }


strokeAxis : SvgPalette
strokeAxis =
    { empty | stroke = gray }
