module Css.Palette.Extra exposing
    ( red, redOnHover, redOnFocus, redOnActive
    , orange, orangeOnHover, orangeOnFocus, orangeOnActive
    , yellow, yellowOnHover, yellowOnFocus, yellowOnActive
    , olive, oliveOnHover, oliveOnFocus, oliveOnActive
    , green, greenOnHover, greenOnFocus, greenOnActive
    , teal, tealOnHover, tealOnFocus, tealOnActive
    , blue, blueOnHover, blueOnFocus, blueOnActive
    , violet, violetOnHover, violetOnFocus, violetOnActive
    , purple, purpleOnHover, purpleOnFocus, purpleOnActive
    , pink, pinkOnHover, pinkOnFocus, pinkOnActive
    , brown, brownOnHover, brownOnFocus, brownOnActive
    , grey, greyOnHover, greyOnFocus, greyOnActive
    , black, blackOnHover, blackOnFocus, blackOnActive
    , transparent_, textColor, hoverColor
    )

{-|

@docs red, redOnHover, redOnFocus, redOnActive
@docs orange, orangeOnHover, orangeOnFocus, orangeOnActive
@docs yellow, yellowOnHover, yellowOnFocus, yellowOnActive
@docs olive, oliveOnHover, oliveOnFocus, oliveOnActive
@docs green, greenOnHover, greenOnFocus, greenOnActive
@docs teal, tealOnHover, tealOnFocus, tealOnActive
@docs blue, blueOnHover, blueOnFocus, blueOnActive
@docs violet, violetOnHover, violetOnFocus, violetOnActive
@docs purple, purpleOnHover, purpleOnFocus, purpleOnActive
@docs pink, pinkOnHover, pinkOnFocus, pinkOnActive
@docs brown, brownOnHover, brownOnFocus, brownOnActive
@docs grey, greyOnHover, greyOnFocus, greyOnActive
@docs black, blackOnHover, blackOnFocus, blackOnActive
@docs transparent_, textColor, hoverColor

-}

import Css exposing (..)
import Css.Palette exposing (Palette, init)



-- COLORED


colored : Palette Color
colored =
    { init | color = Just (hex "#FFFFFF") }


red : Palette Color
red =
    { colored
        | background = Just (hex "#DB2828")
        , border = Just (hex "#DB2828")
    }


redOnHover : Palette Color
redOnHover =
    { red | background = Just (hex "#d01919") }


redOnFocus : Palette Color
redOnFocus =
    { red | background = Just (hex "#ca1010") }


redOnActive : Palette Color
redOnActive =
    { red | background = Just (hex "#b21e1e") }


orange : Palette Color
orange =
    { colored
        | background = Just (hex "#F2711C")
        , border = Just (hex "#F2711C")
    }


orangeOnHover : Palette Color
orangeOnHover =
    { orange | background = Just (hex "#f26202") }


orangeOnFocus : Palette Color
orangeOnFocus =
    { orange | background = Just (hex "#e55b00") }


orangeOnActive : Palette Color
orangeOnActive =
    { orange | background = Just (hex "#cf590c") }


yellow : Palette Color
yellow =
    { colored
        | background = Just (hex "#FBBD08")
        , border = Just (hex "#FBBD08")
    }


yellowOnHover : Palette Color
yellowOnHover =
    { yellow | background = Just (hex "#eaae00") }


yellowOnFocus : Palette Color
yellowOnFocus =
    { yellow | background = Just (hex "#daa300") }


yellowOnActive : Palette Color
yellowOnActive =
    { yellow | background = Just (hex "#cd9903") }


olive : Palette Color
olive =
    { colored
        | background = Just (hex "#B5CC18")
        , border = Just (hex "#B5CC18")
    }


oliveOnHover : Palette Color
oliveOnHover =
    { olive | background = Just (hex "#a7bd0d") }


oliveOnFocus : Palette Color
oliveOnFocus =
    { olive | background = Just (hex "#a0b605") }


oliveOnActive : Palette Color
oliveOnActive =
    { olive | background = Just (hex "#8d9e13") }


green : Palette Color
green =
    { colored
        | background = Just (hex "#21BA45")
        , border = Just (hex "#21BA45")
    }


greenOnHover : Palette Color
greenOnHover =
    { green | background = Just (hex "#16ab39") }


greenOnFocus : Palette Color
greenOnFocus =
    { green | background = Just (hex "#0ea432") }


greenOnActive : Palette Color
greenOnActive =
    { green | background = Just (hex "#198f35") }


teal : Palette Color
teal =
    { colored
        | background = Just (hex "#00B5AD")
        , border = Just (hex "#00B5AD")
    }


tealOnHover : Palette Color
tealOnHover =
    { teal | background = Just (hex "#009c95") }


tealOnFocus : Palette Color
tealOnFocus =
    { teal | background = Just (hex "#008c86") }


tealOnActive : Palette Color
tealOnActive =
    { teal | background = Just (hex "#00827c") }


blue : Palette Color
blue =
    { colored
        | background = Just (hex "#2185D0")
        , border = Just (hex "#2185D0")
    }


blueOnHover : Palette Color
blueOnHover =
    { blue | background = Just (hex "#1678c2") }


blueOnFocus : Palette Color
blueOnFocus =
    { blue | background = Just (hex "#0d71bb") }


blueOnActive : Palette Color
blueOnActive =
    { blue | background = Just (hex "#1a69a4") }


violet : Palette Color
violet =
    { colored
        | background = Just (hex "#6435C9")
        , border = Just (hex "#6435C9")
    }


violetOnHover : Palette Color
violetOnHover =
    { violet | background = Just (hex "#5829bb") }


violetOnFocus : Palette Color
violetOnFocus =
    { violet | background = Just (hex "#4f20b5") }


violetOnActive : Palette Color
violetOnActive =
    { violet | background = Just (hex "#502aa1") }


purple : Palette Color
purple =
    { colored
        | background = Just (hex "#A333C8")
        , border = Just (hex "#A333C8")
    }


purpleOnHover : Palette Color
purpleOnHover =
    { purple | background = Just (hex "#9627ba") }


purpleOnFocus : Palette Color
purpleOnFocus =
    { purple | background = Just (hex "#8f1eb4") }


purpleOnActive : Palette Color
purpleOnActive =
    { purple | background = Just (hex "#82299f") }


pink : Palette Color
pink =
    { colored
        | background = Just (hex "#E03997")
        , border = Just (hex "#E03997")
    }


pinkOnHover : Palette Color
pinkOnHover =
    { pink | background = Just (hex "#e61a8d") }


pinkOnFocus : Palette Color
pinkOnFocus =
    { pink | background = Just (hex "#e10f85") }


pinkOnActive : Palette Color
pinkOnActive =
    { pink | background = Just (hex "#c71f7e") }


brown : Palette Color
brown =
    { colored
        | background = Just (hex "#A5673F")
        , border = Just (hex "#A5673F")
    }


brownOnHover : Palette Color
brownOnHover =
    { brown | background = Just (hex "#975b33") }


brownOnFocus : Palette Color
brownOnFocus =
    { brown | background = Just (hex "#90532b") }


brownOnActive : Palette Color
brownOnActive =
    { brown | background = Just (hex "#805031") }


grey : Palette Color
grey =
    { colored
        | background = Just (hex "#767676")
        , border = Just (hex "#767676")
    }


greyOnHover : Palette Color
greyOnHover =
    { grey | background = Just (hex "#838383") }


greyOnFocus : Palette Color
greyOnFocus =
    { grey | background = Just (hex "#8a8a8a") }


greyOnActive : Palette Color
greyOnActive =
    { grey | background = Just (hex "#909090") }


black : Palette Color
black =
    { colored
        | background = Just (hex "#1B1C1D")
        , border = Just (hex "#1B1C1D")
    }


blackOnHover : Palette Color
blackOnHover =
    { black | background = Just (hex "#27292a") }


blackOnFocus : Palette Color
blackOnFocus =
    { black | background = Just (hex "#2f3032") }


blackOnActive : Palette Color
blackOnActive =
    { black | background = Just (hex "#343637") }



-- COLOR


transparent_ : Color
transparent_ =
    Css.rgba 0 0 0 0


textColor : Color
textColor =
    rgba 0 0 0 0.6


hoverColor : Color
hoverColor =
    rgba 0 0 0 0.8
