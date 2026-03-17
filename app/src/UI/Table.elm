module UI.Table exposing
    ( table
    , thead, tr, td, th
    )

{-|

@docs table
@docs thead, tr, td, th

-}

import Html.Styled as Html exposing (Attribute, Html)
import Html.Styled.Attributes exposing (class)


{-| Basic table using daisyUI table class
-}
table : List (Attribute msg) -> List (Html msg) -> Html msg
table attrs children =
    Html.table (class "table" :: attrs) children


{-| Table header
-}
thead : List (Attribute msg) -> List (Html msg) -> Html msg
thead =
    Html.thead


{-| Table row
-}
tr : List (Attribute msg) -> List (Html msg) -> Html msg
tr =
    Html.tr


{-| Table data cell
-}
td : List (Attribute msg) -> List (Html msg) -> Html msg
td =
    Html.td


{-| Table header cell
-}
th : List (Attribute msg) -> List (Html msg) -> Html msg
th =
    Html.th
