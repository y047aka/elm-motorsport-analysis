module ReviewConfig exposing (config)

{-| Do not rename the ReviewConfig module or the config function, because
`elm-review` will look for these.

To add packages that contain rules, add them to this review project using

    `elm install author/packagename`

when inside the directory containing this file.

-}

import NoExposingEverything
import NoMissingSubscriptionsCall
import NoMissingTypeAnnotation
import NoPrematureLetComputation
import NoRecursiveUpdate
import NoUnused.Exports
import NoUselessSubscriptions
import Review.Rule exposing (Rule)


config : List Rule
config =
    [ -- jfmengels/elm-review-common
      NoExposingEverything.rule
    , NoMissingTypeAnnotation.rule
    , NoPrematureLetComputation.rule

    -- jfmengels/elm-review-the-elm-architecture
    , NoMissingSubscriptionsCall.rule
    , NoRecursiveUpdate.rule
    , NoUselessSubscriptions.rule

    -- jfmengels/elm-review-unused
    -- , NoUnused.Exports.rule
    ]
