module Motorsport.Utils exposing (compareBy)

{-| Utility functions for the Motorsport package.

@docs compareBy

-}


{-| Helper function to create a comparison function from a getter function.
-}
compareBy : (a -> comparable) -> a -> a -> Order
compareBy getter a b =
    compare (getter a) (getter b)
