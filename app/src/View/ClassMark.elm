module View.ClassMark exposing (view)

{-| The same bar the LiveStandings class headers stand their names on --
`0.2em x 1.2em` of the class colour at their 10px, which is 2px x 12px.

@docs view

-}

import Html exposing (Html, div)
import Html.Attributes as Attributes exposing (attribute)
import Motorsport.Race.Car exposing (Metadata)
import Motorsport.Wec.Class as Class


view : Metadata -> Html msg
view metadata =
    div
        [ Attributes.class "w-[2px] h-[12px] rounded-[2px]"
        , attribute "style" ("background-color: " ++ Class.toColor metadata.class ++ ";")
        ]
        []
