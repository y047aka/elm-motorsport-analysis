module View.Feed exposing (Model, Msg(..), Post, ago, init, posts, shown, step, update, view)

{-| A timeline of posts, newest first, the way a social feed shows them, with older
posts asked for a page at a time.

Nothing here is the sport's: the module imports no `Motorsport` module, and the
times it prints are milliseconds the caller hands it.

The frame and the posts are two functions rather than one because they are rebuilt
at different rates.

-}

import Html exposing (Html, button, div, span, text)
import Html.Attributes as Attributes
import Html.Events exposing (onClick)
import Html.Keyed
import UI.Shadcn.Card as Card


{-| How far the reader has pulled the feed back: which page of the older posts they
have asked for, and how many one page holds.
-}
type alias Model =
    { page : Int
    , perPage : Int
    }


{-| The one thing a reader does to a feed: ask for the posts behind the ones shown.
-}
type Msg
    = ShowEarlierEvents


update : Msg -> Model -> Model
update _ model =
    { model | page = model.page + 1 }


{-| The feed opens on one page of `perPage` posts.
-}
init : { perPage : Int } -> Model
init { perPage } =
    { page = 1
    , perPage = perPage
    }


{-| A post: an avatar, the line that leads and the time beside it, the name the
post stands under, what happened, and the stamp under it.
-}
type alias Post msg =
    { key : String
    , avatar : Html msg
    , headline : Html msg
    , time : String
    , author : String
    , body : String
    , stamp : String
    }


{-| The frame: the card, the head above the scroller, the corner over it.

The head stands above the scroller and not inside it: Card's own ground is
translucent, so a head within the scroller lets the posts show through it.

-}
view :
    { attributes : List (Html.Attribute msg)
    , corner : List (Html msg)
    , head : Html msg
    , body : Html msg
    }
    -> Html msg
view feed =
    Card.card feed.attributes
        [ div [ Attributes.class "relative flex-1 min-h-0 grid grid-rows-[auto_minmax(0,1fr)]" ]
            [ div [ Attributes.class "px-4 pb-1 pr-14" ] [ feed.head ]
            , div [ Attributes.class "min-h-0 overflow-y-auto" ]
                [ Card.content [] [ feed.body ] ]
            , div [ Attributes.class "absolute top-0 right-0 flex items-start gap-x-1" ] feed.corner
            ]
        ]


{-| The posts, and the foot that asks for the ones behind them.
-}
posts : { earlier : msg, empty : String, end : String } -> Model -> List (Post msg) -> Html msg
posts feed model thePosts =
    let
        visible =
            shown model thePosts

        remaining =
            List.length thePosts - List.length visible
    in
    if List.isEmpty visible then
        div [ Attributes.class "p-5 text-center italic text-muted-foreground" ]
            [ text feed.empty ]

    else
        div []
            [ Html.Keyed.node "div" [] (List.map (\post_ -> ( post_.key, row post_ )) visible)
            , foot feed.earlier feed.end model.perPage remaining
            ]


{-| The posts shown: every one up to the page the reader has reached, not that page
alone -- a reader who pulled the feed back expects what they passed to stay.
-}
shown : Model -> List post -> List post
shown model =
    List.take (model.page * model.perPage)


row : Post msg -> Html msg
row post_ =
    div
        [ Attributes.class "grid border-t border-border/70 first:border-t-0"
        , Attributes.attribute "data-event-row" ""
        ]
        [ div [ Attributes.class "grid grid-cols-[auto_1fr] gap-x-2.5 py-2" ]
            [ post_.avatar
            , postText post_
            ]
        ]


postText : Post msg -> Html msg
postText post_ =
    div [ Attributes.class "min-w-0" ]
        [ div [ Attributes.class "flex items-baseline gap-x-1.5" ]
            [ post_.headline
            , span [ Attributes.class "ms-auto shrink-0 text-[11px] tabular-nums text-muted-foreground" ]
                [ text post_.time ]
            ]
        , div [ Attributes.class "truncate text-xs font-semibold" ]
            [ text post_.author ]
        , div [ Attributes.class "pt-1 text-sm leading-snug" ]
            [ text post_.body ]
        , div [ Attributes.class "pt-1 text-[11px] tabular-nums text-muted-foreground" ]
            [ text post_.stamp ]
        ]


foot : msg -> String -> Int -> Int -> Html msg
foot earlier end pageSize_ remaining =
    div [ Attributes.class "grid pt-3" ]
        [ if remaining > 0 then
            button
                [ onClick earlier
                , Attributes.class "cursor-pointer rounded-lg border border-border py-1.5 text-xs font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground"
                ]
                [ text ("Show " ++ String.fromInt (min remaining pageSize_) ++ " earlier events") ]

          else
            div [ Attributes.class "py-1 text-center text-[11px] italic text-muted-foreground" ]
                [ text end ]
        ]


{-| The stamp's finest step, in milliseconds: fifteen seconds. `ago` prints nothing
finer, and the clock a caller rebuilds the posts on is bucketed to it -- a bucket
coarser than this is what makes a post read `now` when it is not new.
-}
step : Int
step =
    15000


{-| How far behind one moment another stands, in the compact spelling a timeline
stamps its posts with: `now`, `45s`, `12m`, `3h`. The count is floored to `step`.

    ago { now = 0, at = 0 }
    --> "now"

    ago { now = 20000, at = 0 }
    --> "15s"

    ago { now = 45000, at = 0 }
    --> "45s"

    ago { now = 75000, at = 0 }
    --> "1m"

    ago { now = 750000, at = 0 }
    --> "12m"

    ago { now = 10800000, at = 0 }
    --> "3h"

-}
ago : { now : Int, at : Int } -> String
ago { now, at } =
    let
        steps =
            (now - at) // step

        stepsPerMinute =
            60000 // step

        stepsPerHour =
            3600000 // step
    in
    if steps < 1 then
        "now"

    else if steps < stepsPerMinute then
        String.fromInt (steps * (step // 1000)) ++ "s"

    else if steps < stepsPerHour then
        String.fromInt (steps // stepsPerMinute) ++ "m"

    else
        String.fromInt (steps // stepsPerHour) ++ "h"
