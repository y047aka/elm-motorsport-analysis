module Path.Styled exposing (element)

import Path exposing (Path, toString)
import Svg.Styled as Svg
import Svg.Styled.Attributes as Attributes


element : Path -> List (Svg.Attribute msg) -> Svg.Svg msg
element path attributes =
    Svg.path (Attributes.d (toString path) :: attributes) []
