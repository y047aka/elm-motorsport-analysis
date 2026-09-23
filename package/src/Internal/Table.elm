module Internal.Table exposing
    ( table
    , thead, tr, td, th
    )

{-|

@docs table
@docs thead, tr, td, th

-}

import Html exposing (Attribute, Html)
import Html.Attributes exposing (class)


table : List (Attribute msg) -> List (Html msg) -> Html msg
table attrs children =
    Html.table (class "w-full border-collapse text-left text-sm" :: attrs) children


thead : List (Attribute msg) -> List (Html msg) -> Html msg
thead =
    Html.thead


tr : List (Attribute msg) -> List (Html msg) -> Html msg
tr =
    Html.tr


td : List (Attribute msg) -> List (Html msg) -> Html msg
td =
    Html.td


th : List (Attribute msg) -> List (Html msg) -> Html msg
th =
    Html.th
