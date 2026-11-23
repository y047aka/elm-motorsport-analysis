/// A circuit's surveyed places sampled for their height: the samples kept beside the
/// Overpass answer they were asked for, and the heights a geometry carries point for
/// point beside its degrees.
///
/// What is sampled is every place the kept answer holds, and every place the survey walks
/// that no node stands at: the zero a turned lap opens at, and the places it walks every
/// `Survey.spacing` metres between two nodes further apart, on the straight line joining
/// them. A height is a source's reading at one of those places, never one interpolated
/// here between two of them.
///
/// The samples are keyed by the degrees they were asked at, spelled as the geometry file
/// spells them. An answer re-fetched with a node moved leaves that node unsampled, and the
/// survey refuses the circuit by name rather than drawing the old height at the new place.
///
///     nix run .#geometry -- elevation <circuit> [--fetch]
pub mod Elevation {

    use Circuit.Circuit
    use Cli.Args.ArgsError
    use Cli.Args.Outcome
    use Geodesy.Place
    use Overpass.Answer.Answer
    use Sys.Console
    use Time.Clock
    use Util.GetOpt.ArgDescr
    use Util.GetOpt.OptionDescr
    use Util.Json.Json

    /// The sources a circuit's places can be sampled from: each a terrain model of the
    /// bare earth, and each covering one country or one region of it.
    pub enum Source with Eq {
        case Usgs3dep
        case IgnLidarHd
        case IgnEspanaMdt05
        case LombardiaDtm5
        case GsiDem
    }

    /// What a source says of itself, in the kept file and, less the service, in the
    /// geometry.
    pub type alias Dataset = {
        name    = String,
        license = String,
        datum   = String,
        service = String
    }

    pub def datasetOf(source: Source): Dataset = match source {
        case Source.Usgs3dep => {
            name    = "USGS 3D Elevation Program (3DEP), best available",
            license = "public domain",
            datum   = "NAVD88",
            service = "https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer"
        }
        case Source.IgnLidarHd => {
            name    = "IGN LiDAR HD, MNT (© IGN)",
            license = "Licence Ouverte 2.0",
            datum   = "NGF-IGN69",
            service = Elevation.Geopf.service()
        }
        case Source.IgnEspanaMdt05 => {
            name    = "MDT05 (© Instituto Geográfico Nacional)",
            license = "CC BY 4.0",
            datum   = "mean sea level at Alicante",
            service = Elevation.Idee.service()
        }
        case Source.LombardiaDtm5 => {
            name    = "DTM 5x5 (© Regione Lombardia)",
            license = "CC BY 4.0",
            datum   = "Genova 1942",
            service = "https://www.cartografia.servizirl.it/arcgis2/rest/services/BaseMap/DTM5_RL_img/ImageServer"
        }
        case Source.GsiDem => {
            name    = "GSI digital elevation model (© 国土地理院)",
            license = "GSI content terms of use (CC BY 4.0 compatible)",
            datum   = "Tokyo Bay mean sea level",
            service = Elevation.Gsi.service()
        }
    }

    /// One place's height above the datum, and the resolution of the model it was read
    /// off, in metres.
    pub type alias Sample = {
        place      = Place,
        metres     = Float64,
        resolution = Float64
    }

    /// The kept samples, read: the heights by the degrees they were asked at.
    pub type alias Kept = {
        dataset = Dataset,
        heights = Map[String, Float64]
    }

    /// The heights a geometry carries, one per point of each line: the ones the thinning
    /// kept, since a height is a reason the thinning keeps a point.
    pub type alias Profile = {
        dataset = Dataset,
        outline = List[Float64],
        pitLane = List[Float64]
    }

    // ---------------------------------------------------------------- the places

    /// The places a circuit is sampled at: the answer's nodes in the order it holds them,
    /// then every place the survey walks that no node stands at — the zero a turned lap
    /// opens at, and the places it walks between two nodes `Survey.spacing` apart — each
    /// once.
    pub def placesOf(reading: Answer, geometry: Survey.Geometry): List[Place] =
        let nodes = reading#elements |> List.filter(each -> each#kind == "node") |> List.filterMap(each -> each#at);
        distinct(List.append(nodes, geometry#walked), Set.empty(), Nil)

    def distinct(places: List[Place], seen: Set[String], kept: List[Place]): List[Place] =
        match places {
            case Nil => List.reverse(kept)
            case one :: more =>
                let key = keyOf(one);
                if (Set.memberOf(key, seen)) distinct(more, seen, kept)
                else distinct(more, Set.insert(key, seen), one :: kept)
        }

    def keyOf(place: Place): String =
        Geometry.Write.coordinate(place#lon, place#lat)

    // ---------------------------------------------------------------- the heights

    /// The height of every place a line runs through, out of the kept samples.
    pub def heightsOf(circuit: Circuit, kept: Kept, places: List[Place]): Result[String, List[Float64]] =
        match List.filter(at -> not Map.memberOf(keyOf(at), kept#heights), places) {
            case Nil => Ok(List.filterMap(at -> Map.get(keyOf(at), kept#heights), places))
            case wanting =>
                let first = List.head(wanting) |> Option.map(keyOf) |> Option.getWithDefault("");
                Err(
                    "the kept elevation holds no height for ${List.length(wanting)} of the places the survey walks, the first at ${first}: the answer has moved since it was sampled, and `elevation ${circuit#word} --fetch` samples it again"
                )
        }

    // ---------------------------------------------------------------- the kept file

    /// The kept samples' text, or nothing where the circuit keeps none: a circuit with no
    /// samples is drawn without heights, which is not a failure.
    pub def keptText(circuit: Circuit): Result[String, Option[String]] \ IO =
        let path = Circuit.keptElevation(circuit);
        match Util.Files.exists(path) {
            case Err(problem) => Err("${path}: ${problem}")
            case Ok(false)    => Ok(None)
            case Ok(true)     => Cli.Errors.readFile(path) |> Result.mapErr(problem -> "${problem}") |> Result.map(text -> Some(text))
        }

    /// The kept file as it is written: what the source says of itself, then one sample
    /// per line, in the order the places were asked in.
    pub def written(dataset: Dataset, samples: List[Sample]): String =
        let head = "{\"source\": ${Geometry.Write.text(dataset#name)}, \"license\": ${Geometry.Write.text(dataset#license)}, \"datum\": ${Geometry.Write.text(dataset#datum)}, \"service\": ${Geometry.Write.text(dataset#service)}, \"samples\": [\n";
        let lines = List.map(sampleLine, samples) |> String.intercalate(",\n");
        "${head}${lines}\n]}\n"

    def sampleLine(sample: Sample): String =
        let n = Geometry.Write.number;
        "{\"lon\":${n(sample#place#lon)},\"lat\":${n(sample#place#lat)},\"metres\":${n(sample#metres)},\"resolution_m\":${n(sample#resolution)}}"

    /// The kept file, read. Every sample needs its degrees and its height; a sample
    /// missing either is a file edited by hand, and is refused rather than skipped.
    pub def read(text: String): Result[String, Kept] =
        match Util.Json.parse(text) {
            case Err(problem) => Err("the kept elevation is no JSON: ${problem}")
            case Ok(Json.JObject(root)) =>
                forM(
                    name    <- wordAt("source", root);
                    license <- wordAt("license", root);
                    datum   <- wordAt("datum", root);
                    service <- wordAt("service", root);
                    samples <- samplesAt(root)
                ) yield {
                    dataset = {name = name, license = license, datum = datum, service = service},
                    heights = List.toMap(samples)
                }
            case Ok(_) => Err("the kept elevation is no JSON object")
        }

    def wordAt(key: String, root: Map[String, Json]): Result[String, String] =
        Option.toOk("the kept elevation names no ${key}", Geometry.word(key, root))

    def samplesAt(root: Map[String, Json]): Result[String, List[(String, Float64)]] =
        match Map.get("samples", root) {
            case Some(Json.JArray(items)) =>
                List.zip(List.range(1, Vector.length(items) + 1), Vector.toList(items))
                    |> Result.traverse(pair -> match pair { case (at, json) => keptSample(at, json) })
            case _ => Err("the kept elevation holds no samples")
        }

    def keptSample(at: Int32, json: Json): Result[String, (String, Float64)] =
        match json {
            case Json.JObject(members) =>
                let number = key -> Map.get(key, members) |> Option.flatMap(Geometry.number);
                match (number("lon"), number("lat"), number("metres")) {
                    case (Some(lon), Some(lat), Some(metres)) => Ok((keyOf({lon = lon, lat = lat}), metres))
                    case _ => Err("the kept elevation's sample ${at} is not a place and a height")
                }
            case _ => Err("the kept elevation's sample ${at} is not a place and a height")
        }

    // ---------------------------------------------------------------- the asking

    /// Every place asked of the circuit's source.
    def ask(source: Source, places: List[Place]): Result[String, List[Sample]] \ { IO, Clock } =
        Service.paced(() -> match source {
            case Source.Usgs3dep       => Elevation.ArcGis.sample(datasetOf(source)#service, "USGS 3DEP", places)
            case Source.LombardiaDtm5  => Elevation.ArcGis.sample(datasetOf(source)#service, "Lombardia DTM 5x5", places)
            case Source.IgnLidarHd     => Elevation.Geopf.sample(places)
            case Source.IgnEspanaMdt05 => Elevation.Idee.sample(places)
            case Source.GsiDem         => Elevation.Gsi.sample(places)
        })

    /// How many times a request is asked before the run gives up: a source answers 504
    /// for minutes at a time.
    pub def tries(): Int32 = 3

    /// One request, asked again after a failure, left longer each time.
    pub def sent(request: Net.HttpRequest.HttpRequest, who: String): Result[String, String] \ { IO, Net.Https.Https } =
        retried(() -> Service.send(request, who), 1)

    /// The same, of a service answering in text that holds `holding`.
    pub def sentHolding(request: Net.HttpRequest.HttpRequest, who: String, holding: String): Result[String, String] \ { IO, Net.Https.Https } =
        retried(() -> Service.sendHolding(request, who, holding), 1)

    def retried(asking: Unit -> Result[String, String] \ Net.Https.Https, attempt: Int32): Result[String, String] \ { IO, Net.Https.Https } =
        match asking() {
            case Ok(text) => Ok(text)
            case Err(problem) =>
                if (attempt >= tries())
                    Err(problem)
                else {
                    Net.HttpLayer.sleep(Time.Duration.toMillis(Overpass.backoff(attempt)));
                    retried(asking, attempt + 1)
                }
        }

    /// The places in batches of `size`, in order.
    pub def batches(size: Int32, places: List[a]): List[List[a]] =
        if (List.isEmpty(places))
            Nil
        else
            List.take(size, places) :: batches(size, List.drop(size, places))

    // ---------------------------------------------------------------- the word

    pub type alias Request = {
        circuit = Circuit,
        fetch   = Bool
    }

    enum Setting with Eq {
        case Fetch
        case Help
    }

    def optionDescrs(): List[OptionDescr[Setting]] =
        Cli.Args.helpDescr(Setting.Help) ::
        {
            optionIds     = Nil,
            optionNames   = "fetch" :: Nil,
            argDescriptor = ArgDescr.NoArg(Setting.Fetch),
            explanation   = "ask the circuit's elevation source now and keep the samples\nbeside its answer instead of reading the kept ones"
        } :: Nil

    def isHelp(setting: Setting): Bool =
        setting == Setting.Help

    def completed(scanned: Cli.Args.Scanned[Setting]): Result[ArgsError, Request] =
        match scanned#words {
            case Nil => Err(ArgsError.ParseErrors("elevation reads one circuit." :: Nil))
            case one :: _ =>
                match Circuit.byWord(one) {
                    case None          => Err(ArgsError.ParseErrors(Circuit.unknown(one) :: Nil))
                    case Some(circuit) => Ok({circuit = circuit, fetch = List.memberOf(Setting.Fetch, scanned#options)})
                }
        }

    pub def usage(): String =
        Util.GetOpt.usageInfo(
            "usage: nix run .#geometry -- elevation <circuit> [--fetch]",
            optionDescrs()
        )

    pub def exitCode(args: List[String]): Int32 \ { IO, Clock, Console } =
        Cli.Args.comeTo(arguments(args), asking)

    pub def arguments(args: List[String]): Cli.Args.Parsed[Request] =
        Cli.Args.prepare(optionDescrs(), usage(), isHelp, completed, args)

    /// The kept answer surveyed, then its places asked of the source and kept, or the
    /// kept samples laid against the survey. Samples that no longer cover the survey are
    /// the answer a run without `--fetch` is asked for, said at 1.
    def asking(asked: Request): Outcome \ { IO, Clock } =
        let circuit = asked#circuit;
        match keptInputs(circuit) {
            case Err(problem) => Outcome.Failed("${circuit#word}: ${problem}")
            case Ok((text, figures)) =>
                if (asked#fetch)
                    match fetched(circuit, text, figures) {
                        case Err(problem) => Outcome.Failed("${circuit#word}: ${problem}")
                        case Ok(lines)    => Outcome.Done(lines)
                    }
                else
                    match keptText(circuit) {
                        case Err(problem) => Outcome.Failed(problem)
                        case Ok(None)     => Outcome.Done("${circuit#word}: no kept elevation yet — asking a source is `--fetch`'s" :: Nil)
                        case Ok(Some(heights)) =>
                            match Survey.geometry(text, Some(heights), circuit, figures) {
                                case Err(problem)    => Outcome.Verdict("${circuit#word}: ${problem}" :: Nil)
                                case Ok(surveyed)    => Outcome.Done(described(circuit, surveyed#geometry))
                            }
                    }
        }

    /// The kept answer and the map's figures, which every survey of the circuit is laid
    /// from.
    def keptInputs(circuit: Circuit): Result[String, (String, Circuit.Figures)] \ IO =
        forM(
            figures <- MapRecord.read(circuit);
            text    <- Cli.Errors.readFile(Circuit.keptAnswer(circuit)) |> Result.mapErr(problem -> "${problem}")
        ) yield (text, figures)

    /// The places the answer surveyed with no heights keeps are what is sampled; then the
    /// answer is surveyed again with them, as the survey and the fence will survey it.
    def fetched(circuit: Circuit, text: String, figures: Circuit.Figures): Result[String, List[String]] \ { IO, Clock } =
        match circuit#elevation {
            case None => Err("no elevation source is authored for this circuit")
            case Some(source) =>
                let dataset = datasetOf(source);
                forM(
                    plain    <- Survey.geometry(text, None, circuit, figures);
                    samples  <- ask(source, placesOf(plain#answer, plain#geometry));
                    _        <- Cli.Errors.writeFile(Circuit.keptElevation(circuit), written(dataset, samples)) |> Result.mapErr(problem -> "${problem}");
                    surveyed <- Survey.geometry(text, Some(written(dataset, samples)), circuit, figures)
                ) yield
                    "${circuit#word}: kept ${List.length(samples)} heights from ${dataset#name} at ${Circuit.keptElevation(circuit)}"
                        :: described(circuit, surveyed#geometry)
        }

    /// What the heights say of the lap: its lowest and highest points, and where round
    /// the lap each stands.
    def described(circuit: Circuit, geometry: Survey.Geometry): List[String] =
        match geometry#elevation {
            case None          => "${circuit#word}: the survey carries no heights" :: Nil
            case Some(profile) => describedBy(circuit, geometry, profile)
        }

    def describedBy(circuit: Circuit, geometry: Survey.Geometry, profile: Profile): List[String] =
        let metres = List.map(each -> each#metre, geometry#centreline);
        let along = List.zip(profile#outline, metres);
        let lowest = List.foldLeft((best, each) -> if (fst(each) < fst(best)) each else best, (1.0e12, 0.0), along);
        let highest = List.foldLeft((best, each) -> if (fst(each) > fst(best)) each else best, (-1.0e12, 0.0), along);
        "  lowest ${Util.Format.fixed(1, fst(lowest))} m at ${Util.Format.whole(snd(lowest))} m round the lap, highest ${Util.Format.fixed(1, fst(highest))} m at ${Util.Format.whole(snd(highest))} m: ${Util.Format.fixed(1, fst(highest) - fst(lowest))} m apart (${profile#dataset#datum})"
            :: "  ${circuit#word}: ${List.length(profile#outline)} outline and ${List.length(profile#pitLane)} pit lane points carry a height"
            :: Nil
}
