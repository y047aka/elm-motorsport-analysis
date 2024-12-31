module Args exposing (Args, fromString)


type alias Args =
    { eventId : String
    , repoName : String
    }


fromString : String -> Maybe Args
fromString str =
    case String.split "/" str of
        fst :: scd :: [] ->
            Just
                { eventId = fst
                , repoName = scd
                }

        _ ->
            Nothing
