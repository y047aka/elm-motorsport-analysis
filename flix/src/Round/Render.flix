mod Round.Render {

    use Util.Json.Encode.Extra
    use Motorsport.Metadata
    use Motorsport.Wec
    use Motorsport.Wec.RawLap

    pub def renderMetadata(metadata: Metadata.Metadata): String =
        Extra.render(Metadata.toJson(metadata))

    pub def renderJsonl(rawLaps: List[RawLap]): String =
        rawLaps
            |> List.map(rawLap -> "${Extra.renderOnOneLine(Wec.toJson(rawLap))}\n")
            |> List.join("")

}
