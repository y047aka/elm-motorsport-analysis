(** The slice of Flix's [Util.GetOpt] -- itself a port of Haskell's
    [System.Console.GetOpt] -- that this CLI reaches for. Flix gets the module
    from its standard library; OCaml's [Arg] answers a different shape, so the
    part [Cli_args] is written against is spelled out here.

    Only [Permute] is implemented, because that is the order the CLI parses in.*)

type 'a arg_descr =
  | No_arg of 'a
  | Req_arg of (string -> 'a) * string

type 'a option_descr = {
  option_ids : char list;
  option_names : string list;
  arg_descriptor : 'a arg_descr;
  explanation : string;
}

type arg_order = Permute

let starts_with prefix s = String.length s >= String.length prefix && String.sub s 0 (String.length prefix) = prefix

let drop n s = String.sub s n (String.length s - n)

type 'a step =
  | Opt of 'a
  | Non_opt of string
  | Err of string

let long_option descrs token rest =
  let name, inline =
    match String.index_opt token '=' with
    | Some i -> (String.sub token 0 i, Some (drop (i + 1) token))
    | None -> (token, None)
  in
  match List.find_opt (fun d -> List.mem name d.option_names) descrs with
  | None -> ([ Err (Printf.sprintf "unrecognized option `--%s'\n" name) ], rest)
  | Some d -> (
    match (d.arg_descriptor, inline, rest) with
    | No_arg value, None, _ -> ([ Opt value ], rest)
    | No_arg _, Some _, _ -> ([ Err (Printf.sprintf "option `--%s' doesn't allow an argument\n" name) ], rest)
    | Req_arg (f, _), Some argument, _ -> ([ Opt (f argument) ], rest)
    | Req_arg (f, _), None, argument :: tail -> ([ Opt (f argument) ], tail)
    | Req_arg (_, kind), None, [] ->
      ([ Err (Printf.sprintf "option `--%s' requires an argument %s\n" name kind) ], []))

let rec short_options descrs cluster rest =
  match cluster with
  | [] -> ([], rest)
  | id :: tail -> (
    match List.find_opt (fun d -> List.mem id d.option_ids) descrs with
    | None -> ([ Err (Printf.sprintf "unrecognized option `-%c'\n" id) ], rest)
    | Some d -> (
      match d.arg_descriptor with
      | No_arg value ->
        let steps, remaining = short_options descrs tail rest in
        (Opt value :: steps, remaining)
      | Req_arg (f, kind) -> (
        match (tail, rest) with
        | _ :: _, _ -> ([ Opt (f (String.of_seq (List.to_seq tail))) ], rest)
        | [], argument :: remaining -> ([ Opt (f argument) ], remaining)
        | [], [] -> ([ Err (Printf.sprintf "option `-%c' requires an argument %s\n" id kind) ], []))))

let get_opt Permute descrs args =
  let rec go args acc =
    match args with
    | [] -> List.rev acc
    | "--" :: rest -> List.rev_append acc (List.map (fun a -> Non_opt a) rest)
    | token :: rest when starts_with "--" token ->
      let steps, remaining = long_option descrs (drop 2 token) rest in
      go remaining (List.rev_append steps acc)
    | token :: rest when starts_with "-" token && String.length token > 1 ->
      let steps, remaining = short_options descrs (List.of_seq (String.to_seq (drop 1 token))) rest in
      go remaining (List.rev_append steps acc)
    | token :: rest -> go rest (Non_opt token :: acc)
  in
  let steps = go args [] in
  let errors = List.filter_map (function Err e -> Some e | _ -> None) steps in
  if errors <> [] then Error errors
  else
    Ok
      ( List.filter_map (function Opt o -> Some o | _ -> None) steps,
        List.filter_map (function Non_opt n -> Some n | _ -> None) steps )

let usage_info header descrs =
  let line d =
    let ids = List.map (fun c -> Printf.sprintf "-%c" c) d.option_ids in
    let names = List.map (fun n -> Printf.sprintf "--%s" n) d.option_names in
    let kind = match d.arg_descriptor with No_arg _ -> "" | Req_arg (_, kind) -> " " ^ kind in
    Printf.sprintf "  %s%s  %s" (String.concat ", " (ids @ names)) kind d.explanation
  in
  String.concat "\n" ((header ^ "\n") :: List.map line descrs)
