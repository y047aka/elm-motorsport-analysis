module Page.Wec.Columns exposing
    ( Model, init, update, Msg(..)
    , StripKey(..), keyName
    , keysOf, resolve, carsIn
    , placements, isCarried, placementAttributes
    , gripId, stripId, scrollId, width, gap, px
    )

{-| The strip of columns: what order they stand in, which one a pointer is
carrying, and where each is drawn while that goes on.

A column belongs either to a car or to the tracker; `StripKey` is that
choice, and the order -- `Columns` -- is a list of them. `Model` holds one
order, the one carried column, and how far down each panel was scrolled.
Every edit is total: nothing fails, and stand-ins that have settled stay
settled.

-}

import Browser.Dom
import Dict exposing (Dict)
import Html
import Html.Attributes as Attributes
import List.Extra
import Motorsport.Race.Car exposing (CarNumber)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Task
import UI.DragHandle exposing (Pointer)


{-| A column of the strip: a car's, or the tracker's.

The tracker's place in the order means where it stood when the stand-ins
settled: while the stand-ins are live the tracker stands behind them,
whatever their running order becomes.

-}
type StripKey
    = Car CarNumber
    | Tracker


keyName : StripKey -> String
keyName key =
    case key of
        Car carNumber ->
            carNumber

        Tracker ->
            "tracker"


carOfKey : StripKey -> Maybe CarNumber
carOfKey key =
    case key of
        Car carNumber ->
            Just carNumber

        Tracker ->
            Nothing


{-| `ClassLeaders` is the car at the front of each class, re-read from the
snapshot as the race runs. `Picked` is fixed, in the order the reader left
them in, and any open, close or move settles the stand-ins into one -- the
tracker's column, once asked for, holds its place among the cars in that
order too.
-}
type Columns
    = ClassLeaders
    | Picked StripKey (List StripKey)


{-| The order the strip stands in: the cars' own, and the tracker behind the
stand-ins until a settle fixes it among them.
-}
keysOf : Bool -> Snapshot -> Columns -> List StripKey
keysOf tracker snapshot columns =
    case columns of
        ClassLeaders ->
            List.map (.metadata >> .carNumber >> Car) (leaderOfEachClass snapshot)
                ++ (if tracker then
                        [ Tracker ]

                    else
                        []
                   )

        Picked first rest ->
            first :: rest


{-| The standings mark cars from a snapshot that can be a frame older than
the one being drawn; a car that is gone by then is dropped here, before any
box is drawn for it, so a gap cannot open in the placements.
-}
resolve : Snapshot -> List StripKey -> List StripKey
resolve snapshot =
    List.filter
        (\key ->
            case key of
                Car carNumber ->
                    Snapshot.get carNumber snapshot /= Nothing

                Tracker ->
                    True
        )


carsIn : Snapshot -> List StripKey -> List CarAt
carsIn snapshot keys =
    List.filterMap carOfKey keys
        |> List.filterMap (\carNumber -> Snapshot.get carNumber snapshot)


{-| The classes come in the order their leaders run in.
-}
leaderOfEachClass : Snapshot -> List CarAt
leaderOfEachClass snapshot =
    Snapshot.toClassList snapshot
        |> List.filterMap (Tuple.second >> List.head)


{-| There is no ceiling on how many, and each column draws its own charts on
every frame of playback. Opening and closing name the car, and join the cars
at the back of them -- before the tracker when its column stands among them.
-}
open : Bool -> CarNumber -> Snapshot -> Columns -> Columns
open tracker carNumber snapshot columns =
    let
        current =
            keysOf tracker snapshot columns

        car =
            Car carNumber

        at =
            List.Extra.elemIndex Tracker current
                |> Maybe.withDefault (List.length current)
    in
    if List.member car current then
        columns

    else
        pickedOr columns (List.take at current ++ [ car ] ++ List.drop at current)


close : Bool -> CarNumber -> Snapshot -> Columns -> Columns
close tracker carNumber snapshot columns =
    keysOf tracker snapshot columns
        |> List.filter ((/=) (Car carNumber))
        |> pickedOr columns


{-| Moving takes a key -- a car's or the tracker's -- and steps it along.
-}
move : Bool -> StripKey -> Int -> Snapshot -> Columns -> Columns
move tracker key steps snapshot columns =
    let
        current =
            keysOf tracker snapshot columns

        others =
            List.filter ((/=) key) current
    in
    case List.Extra.elemIndex key current of
        Just index ->
            let
                to =
                    clamp 0 (List.length others) (index + steps)
            in
            if to == index then
                columns

            else
                pickedOr columns (List.take to others ++ key :: List.drop to others)

        Nothing ->
            columns


{-| Adding and taking away the tracker's column. Nothing settles: while the
stand-ins are live the tracker follows them as the flag says, and its place
is only fixed by a settle of the cars' own.
-}
showTracker : Snapshot -> Columns -> Columns
showTracker snapshot columns =
    case columns of
        ClassLeaders ->
            columns

        Picked first rest ->
            if List.member Tracker (first :: rest) then
                columns

            else
                Picked first (rest ++ [ Tracker ])


hideTracker : Snapshot -> Columns -> Columns
hideTracker snapshot columns =
    case columns of
        ClassLeaders ->
            columns

        Picked first rest ->
            List.filter ((/=) Tracker) (first :: rest)
                |> pickedOr ClassLeaders


{-| The stand-ins are re-read every frame, so a column being carried among
them could change places under the pointer.
-}
settle : Bool -> Snapshot -> Columns -> Columns
settle tracker snapshot columns =
    pickedOr columns (keysOf tracker snapshot columns)


pickedOr : Columns -> List StripKey -> Columns
pickedOr fallback keys =
    case keys of
        [] ->
            fallback

        first :: rest ->
            Picked first rest


{-| What the reader is told when a column moves.
-}
announcement : StripKey -> List StripKey -> String
announcement key order =
    let
        name =
            case key of
                Car carNumber ->
                    "Car #" ++ carNumber

                Tracker ->
                    "Tracker"
    in
    case List.Extra.elemIndex key order of
        Just index ->
            name ++ " moved to column " ++ String.fromInt (index + 1) ++ " of " ++ String.fromInt (List.length order)

        Nothing ->
            ""


{-| A column being carried along the strip by one pointer. How far it has gone
is the pointer's travel and the strip's together, since the strip can be
scrolled under a pointer that holds still.

`before` is the columns as they stood when it was picked up, and `settled` what
picking it up made of them. A carry that lands where it began puts `before`
back, unless something else has changed the columns since.

-}
type alias Carry =
    { key : StripKey
    , pointerId : Int
    , before : Columns
    , settled : Columns
    , from : Float
    , at : Float
    , scrolledFrom : Float
    , scrolledTo : Float
    }


heldBy : Int -> Maybe Carry -> Maybe Carry
heldBy pointerId =
    Maybe.andThen
        (\carry ->
            if carry.pointerId == pointerId then
                Just carry

            else
                Nothing
        )


putBack : Carry -> Columns -> Columns
putBack carry columns =
    if columns == carry.settled then
        carry.before

    else
        columns


travel : Carry -> Float
travel carry =
    carry.at - carry.from + carry.scrolledTo - carry.scrolledFrom


columnsCarried : Carry -> Int
columnsCarried carry =
    round (travel carry / pitch)


{-| Where a column is drawn, and whether it is the one being carried.
-}
type Placement
    = Resting
    | Carried Float
    | Shifted Float


{-| While one is carried: that one under the pointer, held to the strip, and
each it has passed a column back the other way.

Nothing moves in the DOM until it is let go of. The grip holds the pointer only
while it stays in the document, and the keyed strip moves a column by taking
it out.

-}
placements : Maybe Carry -> List StripKey -> List Placement
placements carried keys =
    case carried |> Maybe.andThen (\carry -> List.Extra.elemIndex carry.key keys |> Maybe.map (Tuple.pair carry)) of
        Just ( carry, from ) ->
            let
                last =
                    List.length keys - 1

                to =
                    from + clamp -from (last - from) (columnsCarried carry)
            in
            List.indexedMap
                (\index _ ->
                    if index == from then
                        Carried (clamp (toFloat -from * pitch) (toFloat (last - from) * pitch) (travel carry))

                    else if from < index && index <= to then
                        Shifted -pitch

                    else if to <= index && index < from then
                        Shifted pitch

                    else
                        Shifted 0
                )
                keys

        Nothing ->
            List.map (always Resting) keys


isCarried : Placement -> Bool
isCarried placement =
    case placement of
        Carried _ ->
            True

        _ ->
            False


placementAttributes : Placement -> List (Html.Attribute msg)
placementAttributes placement =
    case placement of
        Resting ->
            []

        Carried dx ->
            [ Attributes.class "relative z-10 rounded-xl bg-background shadow-2xl"
            , Attributes.style "transform" ("translateX(" ++ px dx ++ ")")
            ]

        Shifted dx ->
            [ Attributes.class "transition-transform"
            , Attributes.style "transform" ("translateX(" ++ px dx ++ ")")
            ]


gripId : StripKey -> String
gripId key =
    "column-grip-" ++ keyName key


stripId : String
stripId =
    "column-strip"


{-| The box a car's panel scrolls in. The tracker's column scrolls nothing.
-}
scrollId : CarNumber -> String
scrollId carNumber =
    "column-scroll-" ++ carNumber


{-| The strip's state: the order, the tracker's column flag, the one pointer
carrying, how far down each car's panel was scrolled, and what to say when a
column moved.
-}
type alias Model =
    { order : Columns
    , tracker : Bool
    , carried : Maybe Carry
    , scrolls : Dict CarNumber Float
    , announcement : String
    }


init : Model
init =
    { order = ClassLeaders
    , tracker = False
    , carried = Nothing
    , scrolls = Dict.empty
    , announcement = ""
    }


type Msg
    = Open CarNumber
    | Close CarNumber
    | ShowTracker Bool
    | Grab StripKey Pointer
    | Carrying Pointer
    | Release Pointer
    | Cancel Int
    | StripScrolledFrom Float
    | StripScrolled Float
    | Step StripKey Int
    | PanelScrolled CarNumber Float
    | Settled


{-| The field is given per call and held by nobody: the stand-ins are read
off it the moment an edit needs them, and the panels' scroll positions are
put back once the moved column has been drawn in its new place -- the grip's
focus first, since focusing scrolls the grip into view and that scrolls the
panel too.

A frame with no round leaves the order where it was; the pointer is still
answered to, and settles nothing that cannot be settled.

-}
update : Maybe Snapshot -> Msg -> Model -> ( Model, Cmd Msg )
update maybeSnapshot msg m =
    case msg of
        Open carNumber ->
            edit maybeSnapshot m (open m.tracker carNumber)

        Close carNumber ->
            edit maybeSnapshot m (close m.tracker carNumber)
                |> Tuple.mapFirst (\after -> { after | scrolls = Dict.remove carNumber m.scrolls })

        ShowTracker shown ->
            case maybeSnapshot of
                Just round ->
                    ( { m
                        | tracker = shown
                        , order =
                            if shown then
                                showTracker round m.order

                            else
                                hideTracker round m.order
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( m, Cmd.none )

        Grab key pointer ->
            case m.carried of
                Just _ ->
                    ( m, Cmd.none )

                Nothing ->
                    let
                        settled =
                            case maybeSnapshot of
                                Just round ->
                                    settle m.tracker round m.order

                                Nothing ->
                                    m.order
                    in
                    ( { m
                        | order = settled
                        , carried =
                            Just
                                { key = key
                                , pointerId = pointer.id
                                , before = m.order
                                , settled = settled
                                , from = pointer.x
                                , at = pointer.x
                                , scrolledFrom = 0
                                , scrolledTo = 0
                                }
                      }
                    , Browser.Dom.getViewportOf stripId
                        |> Task.attempt (Result.map (.viewport >> .x >> StripScrolledFrom) >> Result.withDefault Settled)
                    )

        Carrying pointer ->
            case heldBy pointer.id m.carried of
                Just carry ->
                    ( { m | carried = Just { carry | at = pointer.x } }, Cmd.none )

                Nothing ->
                    ( m, Cmd.none )

        Release pointer ->
            case heldBy pointer.id m.carried of
                Just carry ->
                    case maybeSnapshot of
                        Just round ->
                            let
                                moved =
                                    move m.tracker carry.key (columnsCarried { carry | at = pointer.x }) round m.order
                            in
                            if moved == m.order then
                                ( { m | order = putBack carry m.order, carried = Nothing }, Cmd.none )

                            else
                                reorder round { moved = carry.key, refocus = False } { m | carried = Nothing } moved

                        Nothing ->
                            ( { m | order = putBack carry m.order, carried = Nothing }, Cmd.none )

                Nothing ->
                    ( m, Cmd.none )

        Cancel pointerId ->
            case heldBy pointerId m.carried of
                Just carry ->
                    ( { m | order = putBack carry m.order, carried = Nothing }, Cmd.none )

                Nothing ->
                    ( m, Cmd.none )

        StripScrolledFrom left ->
            ( { m | carried = Maybe.map (\carry -> { carry | scrolledFrom = left, scrolledTo = left }) m.carried }, Cmd.none )

        StripScrolled left ->
            ( { m | carried = Maybe.map (\carry -> { carry | scrolledTo = left }) m.carried }, Cmd.none )

        Step key steps ->
            if m.carried /= Nothing then
                -- A step would move the strip under the carried column, and
                -- could take the grip holding the pointer out of the document.
                ( m, Cmd.none )

            else
                case maybeSnapshot of
                    Just round ->
                        let
                            moved =
                                move m.tracker key steps round m.order
                        in
                        if moved == m.order then
                            ( m, Cmd.none )

                        else
                            reorder round { moved = key, refocus = True } m moved

                    Nothing ->
                        ( m, Cmd.none )

        PanelScrolled carNumber top ->
            ( { m | scrolls = Dict.insert carNumber top m.scrolls }, Cmd.none )

        Settled ->
            ( m, Cmd.none )


edit : Maybe Snapshot -> Model -> (Snapshot -> Columns -> Columns) -> ( Model, Cmd Msg )
edit maybeSnapshot m f =
    case maybeSnapshot of
        Just round ->
            ( { m | order = f round m.order }, Cmd.none )

        Nothing ->
            ( m, Cmd.none )


{-| The keyed strip moves a column by taking it out of the document, which
loses how far down it was scrolled and the focus of anything in it. Both are
put back once it has been drawn in its new place, the focus first: focusing
scrolls the grip, at the top of its column, into view.
-}
reorder : Snapshot -> { moved : StripKey, refocus : Bool } -> Model -> Columns -> ( Model, Cmd Msg )
reorder round { moved, refocus } m order =
    let
        focus : Task.Task Never ()
        focus =
            if refocus then
                Browser.Dom.focus (gripId moved) |> Task.onError (\_ -> Task.succeed ())

            else
                Task.succeed ()
    in
    ( { m | order = order, announcement = announcement moved (keysOf m.tracker round order) }
    , focus
        |> Task.andThen (\_ -> restoreScrolls m.scrolls)
        |> Task.perform (\_ -> Settled)
    )


restoreScrolls : Dict CarNumber Float -> Task.Task Never ()
restoreScrolls scrolls =
    Dict.toList scrolls
        |> List.map
            (\( carNumber, top ) ->
                Browser.Dom.setViewportOf (scrollId carNumber) 0 top
                    |> Task.onError (\_ -> Task.succeed ())
            )
        |> Task.sequence
        |> Task.map (\_ -> ())


{-| A column is 360px, not a share of the cell. The widest thing in the panel is
the comparison's tab row, which wants 302px of the 328 a column of this width
hands it. The floor is 335, so the 26px over is what is left for a font that is
not the one this was measured in.
-}
width : Float
width =
    360


gap : Float
gap =
    10


pitch : Float
pitch =
    width + gap


px : Float -> String
px n =
    String.fromFloat n ++ "px"
