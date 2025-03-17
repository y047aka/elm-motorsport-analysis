module DemoCss exposing (tableDefaultCss)

import Css exposing (..)
import Css.Global exposing (..)


tableDefaultCss =
    global
        [ selector "table.autotable"
            [ borderSpacing zero
            , borderCollapse collapse
            , borderRadius (px 5)
            , boxShadow5 zero zero (px 20) (px 2) <| rgba 190 190 190 0.25
            , marginTop (rem 2.0)
            , width (pct 100)
            , descendants
                [ thead
                    [ descendants
                        [ tr
                            [ color <| rgb 50 50 50
                            , backgroundColor <| rgba 0 0 0 0.035
                            , lastChild [ borderBottom3 (px 1) solid <| rgba 190 190 190 0.25 ]
                            ]
                        , th
                            [ width (pct 15)
                            , padding (rem 0.5)
                            , textAlign left
                            ]
                        , selector "th.autotable__checkbox-header" []
                        , selector "th.autotable__column"
                            [ descendants
                                [ selector "span.autotable__sort-indicator"
                                    [ marginLeft (px 10)
                                    , fontSize (pt 10)
                                    ]
                                ]
                            ]
                        , selector "th.autotable__column-filter"
                            [ descendants
                                [ input
                                    [ borderRadius (px 3)
                                    , border3 (px 1) solid <| rgba 0 0 0 0.25
                                    , padding (rem 0.25)
                                    , fontSize (pt 12)
                                    , width (pct 100)
                                    , focus [ boxShadow5 zero zero (px 2) (px 1) <| hex "63B3ED" ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                , tbody
                    [ descendants
                        [ tr
                            [ nthChild "even" [ backgroundColor <| rgba 0 0 0 0.035 ]
                            , borderBottom3 (px 1) solid <| rgba 190 190 190 0.25
                            , lastChild [ borderBottom zero ]
                            ]
                        , td
                            [ padding (rem 0.5)
                            , descendants
                                [ input
                                    [ borderRadius (px 3)
                                    , border3 (px 1) solid <| rgba 0 0 0 0.25
                                    , padding (rem 0.25)
                                    , fontSize (pt 12)
                                    , width (pct 100)
                                    , focus [ boxShadow5 zero zero (px 2) (px 1) <| hex "63B3ED" ]
                                    ]
                                ]
                            ]
                        , selector "td.autotable__checkbox" []
                        , selector "td.autotable__actions" []
                        , selector "td:not(.editing)"
                            [ padding (rem 0.8) ]

                        -- Probably handy to keep.
                        ]
                    ]
                ]
            ]
        , selector "div.autotable__pagination"
            [ displayFlex
            , justifyContent flexEnd
            , paddingTop (rem 0.5)
            ]
        , selector "button.autotable__pagination-page"
            [ border3 (px 1) solid <| hex "63B3ED"
            , backgroundColor <| rgb 255 255 255
            , color <| rgb 0 0 0
            , borderRadius (px 2)
            , display inline
            , margin (rem 0.1)
            , padding2 (rem 0.25) (rem 0.5)
            , hover [ cursor pointer ]
            ]
        , selector "button.autotable__pagination-active"
            [ backgroundColor <| hex "63B3ED"
            , color <| hex "FFFFFF"
            ]
        , selector "td.autotable__cell-empty" [ padding (rem 2) ]
        ]
