module Page.Wec.Float exposing (Model, Msg(..), init, update, view, trigger)

{-| The track map floated over the columns: hidden until the tracker column's `◱`
asks for it, sized by a grip along each of its four edges, carried by a fifth, and taking part in none of the strip's grid.

The box is a `popover`, and a `manual` one: the browser keeps whether it is open, the two presses only name it, and nothing here can be closed by a press outside it -- the columns are worked while the map is up.

The camera belongs here: this is the one drawing raised off the ground it was surveyed on.

@docs Model, Msg, init, update, view, trigger

-}

import Drag.Handle as Handle
import Html exposing (Html, div, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Events exposing (on)
import Json.Decode as Decode
import Motorsport.Chart.Tracker exposing (Track)
import Motorsport.Chart.Tracker3d as Track3d
import Motorsport.Race.Snapshot exposing (Snapshot)
import Page.Wec.Columns as Columns
import Page.Wec.Resize as Resize
import Page.Wec.Shift as Shift
import View.CarDetail.Header as Header
import View.TrackMap3d as TrackMap3d


type alias Model =
    { shown : Bool
    , width : Resize.Model
    , height : Resize.Model
    , shift : Shift.Model
    , camera : Track3d.Model
    }


init : Model
init =
    { shown = False
    , width = Resize.init defaultWidth
    , height = Resize.init defaultHeight
    , shift = Shift.init
    , camera = Track3d.init
    }


{-| `Shown` mirrors what the popover said of itself; the presses themselves are the
browser's, and reach no message at all.
-}
type Msg
    = Shown Bool
    | LeftMsg Resize.Msg
    | RightMsg Resize.Msg
    | TopMsg Resize.Msg
    | BottomMsg Resize.Msg
    | ShiftMsg Shift.Msg
    | CameraMsg Track3d.Msg


{-| The box the floating map opens at.
480 by 180 is `Tracker3d.box`'s own three to one once the card's 32px of padding is gone, and a box of that shape is the one the drawing fills exactly; letterboxing is what a box of another proportion costs.
The map is stood at the bottom right of the page, and every one of its four edges is a grip: the two away from the corner it is stood at grow `AgainstPointer`, and the two at it are `WithPointer` and take the box along with the size, so the edge opposite the one held stays where it was.
-}
defaultWidth : Float
defaultWidth =
    480


defaultHeight : Float
defaultHeight =
    180


widthFence : Resize.Fence
widthFence =
    { min = 280
    , max = 960
    }


heightFence : Resize.Fence
heightFence =
    { min = 120
    , max = 480
    }


{-| The room between the corner the box is stood at and the window's: the box's own
`bottom-2.5 right-2.5`, since a popover in the top layer is inset from the *viewport*
and not from `mainGrid` -- the same reason `inset: 0` is answered with `top-auto
left-auto`. The two grips at the anchored edges grow the box along it, and stop there:
the box's own edges stop at the window's, as they do under a carry.
-}
cornerRoom : Float
cornerRoom =
    10


leftEdge : Resize.Edge
leftEdge =
    { axis = Handle.Across
    , grows = Resize.AgainstPointer
    , fence = widthFence
    , id = "tracker-float-left-grip"
    , label = "Resize the floating track map from the left"
    , glyph = ""
    }


rightEdge : Resize.Edge
rightEdge =
    { axis = Handle.Across
    , grows = Resize.WithPointer
    , fence = widthFence
    , id = "tracker-float-right-grip"
    , label = "Resize the floating track map from the right"
    , glyph = ""
    }


topEdge : Resize.Edge
topEdge =
    { axis = Handle.Down
    , grows = Resize.AgainstPointer
    , fence = heightFence
    , id = "tracker-float-top-grip"
    , label = "Resize the floating track map from the top"
    , glyph = ""
    }


bottomEdge : Resize.Edge
bottomEdge =
    { axis = Handle.Down
    , grows = Resize.WithPointer
    , fence = heightFence
    , id = "tracker-float-bottom-grip"
    , label = "Resize the floating track map from the bottom"
    , glyph = ""
    }


{-| `boxId` is what the travel is measured against at every pick, and what both
presses point their `popovertarget` at.
-}
box : Shift.Box
box =
    { boxId = "tracker-float-box"
    , gripId = "tracker-float-move-grip"
    , label = "Move the floating track map"
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    case msg of
        Shown shown ->
            ( { m | shown = shown }, Cmd.none )

        LeftMsg sub ->
            ( { m | width = Resize.update leftEdge sub m.width }, Cmd.none )

        RightMsg sub ->
            -- The edge the box is anchored at moved, so the edge opposite stays, and the
            -- box goes with the size. The ceiling is the same at every move of one drag:
            -- the size and the shift both grow by the travel.
            let
                width =
                    Resize.update (Resize.cappedTo (m.width.size + cornerRoom - m.shift.x) rightEdge) sub m.width

                travel =
                    width.size - m.width.size

                shift =
                    m.shift
            in
            ( { m | width = width, shift = { shift | x = shift.x + travel } }, Cmd.none )

        TopMsg sub ->
            ( { m | height = Resize.update topEdge sub m.height }, Cmd.none )

        BottomMsg sub ->
            let
                height =
                    Resize.update (Resize.cappedTo (m.height.size + cornerRoom - m.shift.y) bottomEdge) sub m.height

                travel =
                    height.size - m.height.size

                shift =
                    m.shift
            in
            ( { m | height = height, shift = { shift | y = shift.y + travel } }, Cmd.none )

        ShiftMsg sub ->
            let
                ( shift, cmd ) =
                    Shift.update box sub m.shift
            in
            ( { m | shift = shift }, Cmd.map ShiftMsg cmd )

        CameraMsg sub ->
            ( { m | camera = Track3d.update sub m.camera }, Cmd.none )


{-| The map floated over the columns, drawn into the card the page hands it.

The box stands on the page whether or not it is open -- a `popovertarget` resolves by id, so the element has to be there to be shown -- and the UA keeps a closed popover out of layout. What is not built while it is closed is the drawing itself, which is recomputed every frame of the race.

It is a child of `mainGrid` and not of the strip, whose offsets are read against `mainGrid`'s padding box, so `bottom-2.5 right-2.5` is what stands it on the same edge the columns end at. `card-elements.ts` owns every class the card itself has, which leaves the wrapper the one thing here that can carry a surface.

Three of the UA's popover sheet reach this box and each is answered: `inset: 0` by `top-auto left-auto`, `overflow: auto` by `overflow-visible` because the four size grips stand outside the box, and `display: none` by `hidden [&:popover-open]:grid` -- the box needs `grid` to lay its card out, and an author `display` silently wins over the UA's hiding of a closed popover.

-}
view : Model -> (Html Msg -> List (Html Msg) -> Html Msg) -> Track -> Snapshot -> Html Msg
view m frame track snapshot =
    div
        [ Attributes.id box.boxId
        , attribute "popover" "manual"
        , Attributes.class "absolute top-auto left-auto bottom-2.5 right-2.5 overflow-visible hidden [&:popover-open]:grid rounded-xl bg-background/80 text-popover-foreground backdrop-blur-lg border border-border shadow-glass"
        , Attributes.style "width" (Columns.px m.width.size)
        , Attributes.style "height" (Columns.px m.height.size)
        , Attributes.style "transform" ("translate(" ++ Columns.px m.shift.x ++ ", " ++ Columns.px m.shift.y ++ ")")
        , on "toggle" toggled
        , attribute "data-tracker-float" ""
        ]
        [ frame
            (if m.shown then
                surface m track snapshot

             else
                text ""
            )
            [ Html.map ShiftMsg (Shift.handle box m.shift), closer ]
        , div [ Attributes.class "absolute -left-2.5 top-0 z-10 grid h-full w-2.5 place-items-center" ]
            [ Html.map LeftMsg (Resize.grip leftEdge m.width) ]
        , div [ Attributes.class "absolute -right-2.5 top-0 z-10 grid h-full w-2.5 place-items-center" ]
            [ Html.map RightMsg (Resize.grip rightEdge m.width) ]
        , div [ Attributes.class "absolute -top-2.5 left-0 z-10 grid h-2.5 w-full content-center" ]
            [ Html.map TopMsg (Resize.grip topEdge m.height) ]
        , div [ Attributes.class "absolute -bottom-2.5 left-0 z-10 grid h-2.5 w-full content-center" ]
            [ Html.map BottomMsg (Resize.grip bottomEdge m.height) ]
        ]


toggled : Decode.Decoder Msg
toggled =
    Decode.field "newState" Decode.string
        |> Decode.map (\state -> Shown (state == "open"))


surface : Model -> Track -> Snapshot -> Html Msg
surface m track snapshot =
    TrackMap3d.surface { model = m.camera, toMsg = CameraMsg, track = track, snapshot = snapshot }


{-| The press that floats the map over the columns, standing in the tracker
column's corner and staying `◱` however many times it is pressed.
-}
trigger : Html Msg
trigger =
    Header.cornerPopover
        { popover = box.boxId
        , action = "show"
        , label = "Float the track map over the columns"
        , glyph = "◱"
        }


{-| The ✕ in the map's own corner. It is the only way back, which is why the
popover is `manual`: nothing outside it closes it.
-}
closer : Html Msg
closer =
    Header.cornerPopover
        { popover = box.boxId
        , action = "hide"
        , label = "Close the floating track map"
        , glyph = "✕"
        }
