module View.ClassMark exposing (name, view)

{-| The class drawn in its own colour: the bar a row is marked with, and the
name a section of the page is headed with.

Both are the same bar -- `0.2em x 1.2em` of the class colour at the 10px the class
name is written in, which is 2px x 12px -- so a class is the same colour in a
row's mark, a section's heading and a column's head.

@docs name, view

-}

import Html exposing (Html, div, text)
import Html.Attributes as Attributes exposing (attribute)
import Motorsport.Race.Car exposing (Metadata)
import Motorsport.Wec.Class as Class exposing (Class)


{-| The bar on its own, for a row that is named by its car number beside it.
-}
view : Metadata -> Html msg
view metadata =
    div
        [ Attributes.class "w-[2px] h-[12px] rounded-[2px]"
        , attribute "style" ("background-color: " ++ Class.toColor metadata.class ++ ";")
        ]
        []


{-| The class's name standing on the bar, which is how a section of the page says
which class it is.
-}
name : Class -> Html msg
name class_ =
    div
        [ Attributes.class "flex items-center gap-x-[0.5em] text-[10px] font-bold before:block before:content-[''] before:w-[0.2em] before:h-[1.2em] before:rounded-[2px] before:[background-color:var(--class-color)]"
        , attribute "style" ("--class-color: " ++ Class.toColor class_ ++ ";")
        ]
        [ text (Class.toString class_) ]
