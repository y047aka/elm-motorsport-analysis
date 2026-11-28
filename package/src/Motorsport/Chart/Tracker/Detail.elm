module Motorsport.Chart.Tracker.Detail exposing (Detail(..), Labels(..))

{-| How much of a tracker is drawn.

@docs Detail, Labels

-}

import Motorsport.Circuit.Layout exposing (LabelLengths)


{-| How much of the chart is drawn. The chart is scaled to whatever box it is
given, so every length below is divided by that box: at `Compact`'s size the
labels would stand a few pixels tall, so it carries none, and spends the room
they would need on the circle instead.
-}
type Detail
    = Compact
    | Full


{-| The names a detail draws beside the track, and the lengths they are set at: none at `Compact`.
-}
type Labels
    = NoLabels
    | Labels LabelLengths
