module Page.Wec.Float exposing (Model, Msg(..), init, update, view, trigger)

{-| The track map floated over the columns: hidden until the tracker column's `◱`
asks for it, sized by a grip along each of its two inner edges, carried by a third, and taking part in none of the strip's grid.

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
    | WidthMsg Resize.Msg
    | HeightMsg Resize.Msg
    | ShiftMsg Shift.Msg
    | CameraMsg Track3d.Msg


{-| The box the floating map opens at.
480 by 180 is `Tracker3d.box`'s own three to one once the card's 32px of padding is gone, and a box of that shape is the one the drawing fills exactly; letterboxing is what a box of another proportion costs.
The map is stood at the bottom right of the page and grows up and left, so both grips are `AgainstPointer`: a travel away from the corner it is anchored to is what makes it bigger.
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
    , step = 20
    }


heightFence : Resize.Fence
heightFence =
    { min = 120
    , max = 480
    , step = 20
    }


widthEdge : Resize.Edge
widthEdge =
    { axis = Handle.Across
    , grows = Resize.AgainstPointer
    , fence = widthFence
    , id = "tracker-float-width-grip"
    , label = "Resize the floating track map's width"
    }


heightEdge : Resize.Edge
heightEdge =
    { axis = Handle.Down
    , grows = Resize.AgainstPointer
    , fence = heightFence
    , id = "tracker-float-height-grip"
    , label = "Resize the floating track map's height"
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

        WidthMsg sub ->
            ( { m | width = Resize.update widthEdge sub m.width }, Cmd.none )

        HeightMsg sub ->
            ( { m | height = Resize.update heightEdge sub m.height }, Cmd.none )

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

Three of the UA's popover sheet reach this box and each is answered: `inset: 0` by `top-auto left-auto`, `overflow: auto` by `overflow-visible` because the two size grips stand outside the box, and `display: none` by `hidden [&:popover-open]:grid` -- the box needs `grid` to lay its card out, and an author `display` silently wins over the UA's hiding of a closed popover.

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
            [ Html.map WidthMsg (Resize.grip widthEdge m.width) ]
        , div [ Attributes.class "absolute -top-2.5 left-0 z-10 grid h-2.5 w-full place-content-center" ]
            [ Html.map HeightMsg (Resize.grip heightEdge m.height) ]
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
