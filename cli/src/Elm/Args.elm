module Args exposing (Args, fromString)


type alias Args =
    { eventId : String
    , mode : String
    }


fromString : String -> Maybe Args
fromString str =
    case String.split "/" str of
        mode :: eventId :: [] ->
            Just
                { eventId = eventId
                , mode = mode
                }

        _ ->
            Nothing
