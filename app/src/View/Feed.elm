module View.Feed exposing (Model, Post, ago, init, posts, view)

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
import Internal.DataView as DataView
import Internal.DataView.Options exposing (FilteringOption(..), Options, PaginationOption(..), SelectingOption(..), SortingOption(..))
import UI.Shadcn.Card as Card


{-| How far the reader has pulled the feed back.
-}
type alias Model =
    DataView.Model


{-| The feed has no head to sort by and no field to filter in; it is paginated,
and the page it is on is the only thing a reader sets in it.
-}
init : { key : String, page : Int } -> Model
init { key, page } =
    DataView.init key
        { sorting = NoSorting
        , filtering = NoFiltering
        , selecting = NoSelecting
        , pagination = Pagination page
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
posts feed table thePosts =
    if List.isEmpty thePosts then
        div [ Attributes.class "p-5 text-center italic text-muted-foreground" ]
            [ text feed.empty ]

    else
        DataView.feedView
            { key = .key
            , row = row
            , foot = foot feed.earlier feed.end (pageSize table)
            }
            table
            thePosts


{-| How many posts one pull back asks for. A feed that is not paginated shows every
post at once, so no pull back is ever asked for.
-}
pageSize : Model -> Int
pageSize table =
    case table.options.pagination of
        Pagination page ->
            page

        NoPagination ->
            0


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


{-| How far behind one moment another stands, in the compact spelling a timeline
stamps its posts with: `now`, `12m`, `3h`.
-}
ago : { now : Int, at : Int } -> String
ago { now, at } =
    let
        minutes =
            (now - at) // 60000
    in
    if minutes < 1 then
        "now"

    else if minutes < 60 then
        String.fromInt minutes ++ "m"

    else
        String.fromInt (minutes // 60) ++ "h"
