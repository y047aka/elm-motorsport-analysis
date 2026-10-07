module Page.Wec.Resize exposing (Model, Msg(..), Fence, init, update, grip)

{-| The width of the standings column, and the grip along their edge that
moves it. The page holds one `Model` and forwards every `Msg` through it, the
way it forwards the strip's through `Columns`.

@docs Model, Msg, Fence, init, update, grip

-}

import Drag
import Drag.Handle as Handle exposing (Pointer)
import Html exposing (Html)


{-| The width as it stands, and the carry that moves it. `Drag` keeps the
width it was picked up at; the width follows the pointer's travel from there.
-}
type alias Model =
    { width : Float
    , carried : Drag.State Float
    }


{-| What the grip cannot pass: the widths it is clamped between, and how far
the arrow keys take one press.
-}
type alias Fence =
    { min : Float
    , max : Float
    , step : Float
    }


{-| The width the column arrives at, with no carry in progress.
-}
init : Float -> Model
init width =
    { width = width
    , carried = Drag.init
    }


type Msg
    = Grab Pointer
    | Carrying Pointer
    | Release Pointer
    | Cancel Int
    | Step Int


{-| The width follows `Drag`, and a `Cancel` leaves it where the last move
left it -- unlike a carried column, a resize has nothing to put back.
-}
update : Fence -> Msg -> Model -> Model
update fence msg m =
    case msg of
        Grab pointer ->
            { m | carried = Tuple.first (Drag.update (Drag.Pick m.width pointer) m.carried) }

        Carrying pointer ->
            let
                ( carried, _ ) =
                    Drag.update (Drag.Move pointer) m.carried
            in
            case Drag.carrying carried of
                Just carry ->
                    { m | carried = carried, width = clampTo fence (carry.location + Drag.travel carry) }

                Nothing ->
                    { m | carried = carried }

        Release pointer ->
            { m | carried = Tuple.first (Drag.update (Drag.Drop pointer) m.carried) }

        Cancel pointerId ->
            { m | carried = Tuple.first (Drag.update (Drag.Cancel pointerId) m.carried) }

        Step steps ->
            { m | width = clampTo fence (m.width + toFloat steps * fence.step) }


clampTo : Fence -> Float -> Float
clampTo fence =
    clamp fence.min fence.max


{-| The grip along the column's edge, speaking this module's `Msg`.
-}
grip : Model -> Html Msg
grip m =
    Handle.resize
        { id = gripId
        , label = "Resize the standings column"
        , held = Drag.isCarrying m.carried
        , onGrab = Grab
        , onMove = Carrying
        , onDrop = Release
        , onCancel = Cancel
        , onStep = Step
        }


gripId : String
gripId =
    "standings-resize-grip"
