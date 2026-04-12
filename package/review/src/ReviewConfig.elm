module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

To add packages that contain rules, add them to this review project using

    `elm install author/packagename`

when inside the directory containing this file.

-}

import NoRedundantlyQualifiedType

import NoConfusingPrefixOperator
import NoExposingEverything
import NoImportingEverything
import NoMissingTypeAnnotation

import NoUnused.Dependencies
import NoUnused.Parameters
import NoUnused.Patterns
import NoUnused.Variables
import Review.Rule exposing (Rule)


config : List Rule
config =
    [
      -- jfmengels/elm-review-code-style
      NoRedundantlyQualifiedType.rule

    -- jfmengels/elm-review-common
    ,  NoConfusingPrefixOperator.rule
    , NoExposingEverything.rule
    , NoImportingEverything.rule [ "Css", "Css.Palette.Svg" ]
    , NoMissingTypeAnnotation.rule

    -- jfmengels/elm-review-unused
    -- , NoUnused.Dependencies.rule
    -- , NoUnused.Parameters.rule
    -- , NoUnused.Patterns.rule
    , NoUnused.Variables.rule
    ]
