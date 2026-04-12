module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

To add packages that contain rules, add them to this review project using

    `elm install author/packagename`

when inside the directory containing this file.

-}

import NoSimpleLetBody

import CognitiveComplexity

import NoConfusingPrefixOperator
import NoExposingEverything
import NoImportingEverything
import NoMissingTypeAnnotation

import NoDebug.Log
import NoDebug.TodoOrToString

import NoUnapprovedLicense

import NoUnoptimizedRecursion

import NoConfusingPrefixOperator
import NoRecursiveUpdate
import NoUselessSubscriptions

import NoUnused.CustomTypeConstructorArgs
import NoUnused.CustomTypeConstructors
import NoUnused.Dependencies
import NoUnused.Exports
import NoUnused.Parameters
import NoUnused.Patterns
import NoUnused.Variables
import Review.Rule exposing (Rule)


config : List Rule
config =
    [
      -- jfmengels/elm-review-code-style
      NoSimpleLetBody.rule

    -- jfmengels/elm-review-cognitive-complexity
    , CognitiveComplexity.rule 15

    -- jfmengels/elm-review-common
    , NoConfusingPrefixOperator.rule
    , NoExposingEverything.rule
    , NoImportingEverything.rule [ "Css" ]
    , NoMissingTypeAnnotation.rule

    -- jfmengels/elm-review-debug
    , NoDebug.Log.rule
    , NoDebug.TodoOrToString.rule

    -- jfmengels/elm-review-license
    , NoUnapprovedLicense.rule
        { allowed = [ "BSD-3-Clause", "MIT", "MPL-2.0" ]
        , forbidden = [ "GPL-3.0-only", "GPL-3.0-or-later" ]
        }

    -- jfmengels/elm-review-performance
    , NoUnoptimizedRecursion.rule (NoUnoptimizedRecursion.optOutWithComment "IGNORE TCO")

    -- jfmengels/elm-review-the-elm-architecture
    , NoConfusingPrefixOperator.rule
    , NoRecursiveUpdate.rule
    , NoUselessSubscriptions.rule

    -- jfmengels/elm-review-unused
    , NoUnused.CustomTypeConstructorArgs.rule
    -- , NoUnused.CustomTypeConstructors.rule []
    -- , NoUnused.Dependencies.rule
    -- , NoUnused.Exports.rule
    , NoUnused.Parameters.rule
    , NoUnused.Patterns.rule
    , NoUnused.Variables.rule
    ]
