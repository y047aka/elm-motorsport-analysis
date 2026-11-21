module Page.Wec.Shift exposing (Model, Msg(..), init, update)

{-| Where a box stood before anything moved it, and the pointer that carries it across
the page in both directions at once.

The box cannot be carried out of the window. The travel it may take is measured off
the box itself when a pointer takes it up, and every move is clamped to what that
leaves: the box's own edges stop at the window's.

@docs Model, Msg, init, update

-}

import Browser.Dom
import Drag
import Drag.Handle as Handle exposing (Place, Point)
import Task


{-| How far the box has been taken from where it is stood, and which pointer carries it.
`bounds` is what the last pick measured; `unmeasured` is what it holds before any pick
has happened, and after one whose read failed. `boxId` is what the travel is measured
against, and changes never.
-}
type alias Model =
    { x : Float
    , y : Float
    , carried : Drag.State Point
    , bounds : Bounds
    , boxId : String
    }


{-| How far the box may go along each axis from where it is stood, the four of them
measured so its own edges land on the window's.
-}
type alias Bounds =
    { minX : Float
    , maxX : Float
    , minY : Float
    , maxY : Float
    }


unmeasured : Bounds
unmeasured =
    { minX = -4000, maxX = 4000, minY = -4000, maxY = 4000 }


init : String -> Model
init boxId =
    { x = 0
    , y = 0
    , carried = Drag.init
    , bounds = unmeasured
    , boxId = boxId
    }


type Msg
    = Grab Place
    | Move Place
    | Drop Place
    | Cancel Int
    | Travel Bounds
    | Step Handle.Steps


{-| The box's own place when the pointer took it up is what the travel is added to, so a
carry that starts where the box stands ends where the box stands.

A box that has gone missing leaves the bounds wide, since a grip on it cannot be held
anyway.

-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    case msg of
        Grab place ->
            ( { m | carried = Tuple.first (Drag.update (Drag.Grab { x = m.x, y = m.y } place) m.carried) }
            , Browser.Dom.getElement m.boxId
                |> Task.map (boundsFrom { x = m.x, y = m.y })
                |> Task.onError (\_ -> Task.succeed unmeasured)
                |> Task.perform Travel
            )

        Move place ->
            case Drag.update (Drag.Move place) m.carried of
                ( carried, Drag.Stepped hold ) ->
                    ( { m
                        | carried = carried
                        , x = clamp m.bounds.minX m.bounds.maxX (hold.location.x + place.x - hold.from.x)
                        , y = clamp m.bounds.minY m.bounds.maxY (hold.location.y + place.y - hold.from.y)
                      }
                    , Cmd.none
                    )

                ( carried, _ ) ->
                    ( { m | carried = carried }, Cmd.none )

        Drop place ->
            ( { m | carried = Tuple.first (Drag.update (Drag.Drop place) m.carried) }, Cmd.none )

        Cancel pointerId ->
            ( { m | carried = Tuple.first (Drag.update (Drag.Cancel pointerId) m.carried) }, Cmd.none )

        Travel bounds ->
            ( { m
                | bounds = bounds
                , x = clamp bounds.minX bounds.maxX m.x
                , y = clamp bounds.minY bounds.maxY m.y
              }
            , Cmd.none
            )

        Step steps ->
            ( { m
                | x = clamp m.bounds.minX m.bounds.maxX (m.x + toFloat steps.x * step)
                , y = clamp m.bounds.minY m.bounds.maxY (m.y + toFloat steps.y * step)
              }
            , Cmd.none
            )


{-| The four shifts the window leaves a box, said in the shift's own units rather
than as travel from wherever the pointer happened to be picked up: the corner the box
is stood at is recovered from the measurement by taking back the shift it was read
under, so the bounds say the same thing at every pick and between picks too.

`Browser.Dom.getElement` puts `viewport.x` and `viewport.y` at how far the page has
been scrolled, so `element.x` without them is where the box stands within the window.

-}
boundsFrom : { x : Float, y : Float } -> Browser.Dom.Element -> Bounds
boundsFrom { x, y } { element, viewport } =
    let
        anchorX =
            element.x - viewport.x - x

        anchorY =
            element.y - viewport.y - y
    in
    { minX = negate anchorX
    , maxX = viewport.width - element.width - anchorX
    , minY = negate anchorY
    , maxY = viewport.height - element.height - anchorY
    }


step : Float
step =
    20
